import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

typedef IncomingCallCallback = void Function(String fromId, Map signal);
typedef RemoteStreamCallback = void Function(MediaStream stream);
typedef LocalStreamCallback = void Function(MediaStream stream);

class CallManager {
  late IO.Socket socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;

  final String serverUrl;
  final String currentUserId;

  IncomingCallCallback? onIncomingCall;
  RemoteStreamCallback? onRemoteStream;
  LocalStreamCallback? onLocalStream;
  VoidCallback? onCallEnded;

  String? _currentTarget;
  String? currentRoomId;

  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _isAnswering = false;

  // 🔴 NEW: Prevent concurrent modification
  bool _processingCandidates = false;

  Timer? _connectionCheckTimer;
  int _retryAttempts = 0;
  final int _maxRetryAttempts = 3;

  CallManager({required this.serverUrl, required this.currentUserId});

  Future<void> init() async {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'forceNew': true,
    });

    socket.onConnect((_) {
      socket.emit('join', currentUserId);
      debugPrint('✅ Connected to socket as $currentUserId');
    });

    socket.on('incoming-call', (data) {
      try {
        final from = data['from'] as String;
        final signal = Map<String, dynamic>.from(data['signal'] ?? {});
        onIncomingCall?.call(from, signal);
      } catch (e) {
        debugPrint('⚠ incoming-call parse error: $e');
      }
    });

    socket.on('call-accepted-by-receiver', (data) async {
      try {
        debugPrint('✅ Call accepted by ${data['from']}');
        final isVideo = data['isVideo'] == true;

        if (_currentTarget != null) {
          await _startMediaAndCreateOffer(
            targetId: _currentTarget!,
            isVideo: isVideo,
          );
        }
      } catch (e) {
        debugPrint('⚠ Error after call accepted: $e');
      }
    });

    socket.on('offer', (data) async {
      try {
        debugPrint('📥 Received offer from ${data['from']}');
        _isAnswering = true;
        _pendingCandidates.clear();

        final from = data['from'] as String;
        final offerMap = Map<String, dynamic>.from(data['offer'] ?? {});
        final roomId = data['roomId'] as String?;

        if (roomId != null) currentRoomId = roomId;
        _currentTarget = from;

        final sdp = offerMap['sdp'] as String?;
        final type = offerMap['type'] as String?;
        final isVideo = offerMap['isVideo'] == true;

        if (sdp != null && type != null) {
          await _setupReceiverPeerConnection(from, isVideo);
          await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
          debugPrint('✅ Remote description set (offer)');

          // 🔴 FIX 1: Concurrent Modification - Create copy before iterating
          // WHY: While processing queue, new candidates arrive and cause error
          // SOLUTION: Copy list first, clear original, then process copy
          if (_pendingCandidates.isNotEmpty) {
            _processingCandidates = true; // Lock to prevent new additions

            debugPrint(
              '📦 Adding ${_pendingCandidates.length} pending candidates',
            );

            // Create immutable copy
            final candidatesToAdd = List<RTCIceCandidate>.from(
              _pendingCandidates,
            );
            _pendingCandidates.clear(); // Clear BEFORE processing

            for (var candidate in candidatesToAdd) {
              try {
                await _pc!.addCandidate(candidate);
              } catch (e) {
                debugPrint('⚠ Error adding pending candidate: $e');
              }
            }

            _processingCandidates = false; // Release lock
          }

          final answer = await _pc!.createAnswer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': isVideo,
          });
          await _pc!.setLocalDescription(answer);

          socket.emit('answer', {
            'to': from,
            'from': currentUserId,
            'answer': {'sdp': answer.sdp, 'type': answer.type},
            'roomId': roomId,
          });
          debugPrint('📤 Answer sent to $from');

          _isAnswering = false;
        }
      } catch (e) {
        debugPrint('⚠ offer handler error: $e');
        _isAnswering = false;
        _processingCandidates = false; // Release lock on error
      }
    });

    socket.on('answer', (data) async {
      try {
        debugPrint('📥 Received answer from ${data['from']}');
        final answerMap = Map<String, dynamic>.from(data['answer'] ?? {});
        final sdp = answerMap['sdp'] as String?;
        final type = answerMap['type'] as String?;

        if (sdp != null && type != null && _pc != null) {
          if (_pc!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
            await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
            debugPrint('✅ Remote description set (answer)');

            // 🔴 FIX 1: Same concurrent modification fix for answer handler
            if (_pendingCandidates.isNotEmpty) {
              _processingCandidates = true;

              debugPrint(
                '📦 Adding ${_pendingCandidates.length} pending candidates',
              );

              final candidatesToAdd = List<RTCIceCandidate>.from(
                _pendingCandidates,
              );
              _pendingCandidates.clear();

              for (var candidate in candidatesToAdd) {
                try {
                  await _pc!.addCandidate(candidate);
                } catch (e) {
                  debugPrint('⚠ Error adding pending candidate: $e');
                }
              }

              _processingCandidates = false;
            }
          } else {
            debugPrint(
              '⚠ Cannot set remote description, wrong state: ${_pc!.signalingState}',
            );
          }
        }
      } catch (e) {
        debugPrint('⚠ answer handler error: $e');
        _processingCandidates = false;
      }
    });

    socket.on('call-accepted', (data) async {
      try {
        final signal = Map<String, dynamic>.from(data as Map);
        final sdp = signal['sdp'] as String?;
        final type = signal['type'] as String?;
        if (sdp != null && type != null && _pc != null) {
          if (_pc!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
            await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
          }
        }
      } catch (e) {
        debugPrint('⚠ call-accepted error: $e');
      }
    });

    socket.on('call-rejected', (data) {
      debugPrint('ℹ Received call-rejected: $data');
      onCallEnded?.call();
      _cleanupPeer();
    });

    socket.on('call-ended', (data) {
      debugPrint('ℹ Received call-ended: $data');
      onCallEnded?.call();
      _cleanupPeer();
    });

    // 🔴 FIX 2: Add processing lock check
    // WHY: Prevent adding candidates while we're processing the queue
    socket.on('ice-candidate', (data) async {
      try {
        debugPrint('📥 Received ice-candidate');
        final candMap = data['candidate'];

        if (candMap == null) {
          debugPrint('⚠ Candidate null, skipping');
          return;
        }

        final candidateStr = candMap['candidate'] as String?;
        final sdpMid = candMap['sdpMid'] as String?;
        final sdpMLineIndex = candMap['sdpMLineIndex'];
        final sdpIndex = sdpMLineIndex is int
            ? sdpMLineIndex
            : int.tryParse('$sdpMLineIndex');

        if (candidateStr == null || candidateStr.isEmpty) {
          debugPrint('⚠ Empty candidate string');
          return;
        }

        final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpIndex);

        // Queue if PC not ready OR currently processing queue
        if (_pc == null || _isAnswering || _processingCandidates) {
          debugPrint('📦 Queueing candidate (PC not ready yet)');
          _pendingCandidates.add(candidate);
        } else {
          try {
            await _pc!.addCandidate(candidate);
            debugPrint('✅ ICE candidate added immediately');
          } catch (e) {
            debugPrint('⚠ Error adding candidate: $e');
          }
        }
      } catch (e) {
        debugPrint('⚠ ice-candidate error: $e');
      }
    });

    socket.onDisconnect((_) {
      debugPrint('⚠ Socket disconnected');
    });
  }

  Future<void> _setupReceiverPeerConnection(String fromId, bool isVideo) async {
    _currentTarget = fromId;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('⚠ Speaker setup error: $e');
      }
    }

    debugPrint(
      '🔈 Local audio tracks: ${_localStream?.getAudioTracks().length}',
    );
    if (isVideo) {
      debugPrint(
        '🎥 Local video tracks: ${_localStream?.getVideoTracks().length}',
      );
    }

    onLocalStream?.call(_localStream!);

    _pc = await _createPeerConnection(isVideo, fromId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
        debugPrint(
          '➕ Added local ${track.kind} track, enabled=${track.enabled}',
        );
      }
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(
    bool isVideo,
    String targetId,
  ) async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        },
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(configuration);

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('🔄 ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('❌ ICE connection failed');
        _retryConnection(isVideo);
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        debugPrint('✅ ICE connection established');
        _retryAttempts = 0;
        _connectionCheckTimer?.cancel();
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('🔗 PeerConnection state: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('❌ Connection failed, will retry...');
        _retryConnection(isVideo);
      }
    };

    pc.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('📡 ICE gathering state: $state');
    };

    pc.onIceCandidate = (RTCIceCandidate? c) {
      if (c != null && c.candidate != null && c.candidate!.isNotEmpty) {
        debugPrint('🧊 Sending ICE candidate to $targetId');
        socket.emit('ice-candidate', {
          'to': targetId,
          'candidate': {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        });
      }
    };

    // 🔴 FIX 3: Force unmute remote tracks
    // WHY: WebRTC sets remote tracks as muted by default (security)
    // SYMPTOM: Connected but no audio/video visible
    // SOLUTION: Explicitly unmute and enable all tracks
    pc.onTrack = (RTCTrackEvent event) {
      debugPrint(
        '📹 onTrack: kind=${event.track.kind}, streams=${event.streams.length}, enabled=${event.track.enabled}',
      );

      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        final audioTracks = stream.getAudioTracks().length;
        final videoTracks = stream.getVideoTracks().length;
        debugPrint('✅ Remote stream: audio=$audioTracks, video=$videoTracks');

        // 🔴 CRITICAL: Force unmute and enable all tracks
        for (var track in stream.getTracks()) {
          debugPrint(
            '   ${track.kind}: enabled=${track.enabled}, muted=${track.muted}',
          );

          // Force enable track
          if (!track.enabled) {
            track.enabled = true;
            debugPrint('🔊 Enabled ${track.kind} track');
          }

          // Note: track.muted is READ-ONLY, browser controls it
          // But enabled=true should make it work
        }

        onRemoteStream?.call(stream);
      } else {
        debugPrint('⚠ onTrack but no streams');
      }
    };

    return pc;
  }

  void createRoom(String targetId) {
    currentRoomId = "room_${DateTime.now().millisecondsSinceEpoch}";
    socket.emit("create-room", {
      'roomId': currentRoomId,
      'creator': currentUserId,
      'target': targetId,
      'isVideo': true,
    });
    debugPrint("🏠 Room created: $currentRoomId by $currentUserId");
  }

  void inviteParticipant({
    required String targetId,
    required String? roomId,
    required bool isVideo,
  }) {
    if (roomId == null) {
      debugPrint("⚠ No active room to invite into");
      return;
    }

    socket.emit("add-participant", {
      'roomId': roomId,
      'from': currentUserId,
      'target': targetId,
      'isVideo': isVideo,
    });
    debugPrint("👥 Invited $targetId to room $roomId");
  }

  Future<void> startCall({
    required String targetId,
    required bool isVideo,
  }) async {
    _currentTarget = targetId;
    _pendingCandidates.clear();

    currentRoomId = "room_${DateTime.now().millisecondsSinceEpoch}";

    debugPrint('📞 Initiating call to $targetId (waiting for accept)');

    socket.emit('call-user', {
      'target': targetId,
      'from': currentUserId,
      'signal': {'isVideo': isVideo, 'roomId': currentRoomId},
    });

    debugPrint('✅ Call initiation sent (no media yet)');
  }

  Future<void> _startMediaAndCreateOffer({
    required String targetId,
    required bool isVideo,
  }) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('⚠ Speaker setup error: $e');
      }
    }

    debugPrint(
      '🔈 Local audio tracks: ${_localStream?.getAudioTracks().length}',
    );
    if (isVideo) {
      debugPrint(
        '🎥 Local video tracks: ${_localStream?.getVideoTracks().length}',
      );
    }

    onLocalStream?.call(_localStream!);

    _pc = await _createPeerConnection(isVideo, targetId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
        debugPrint(
          '➕ Added local ${track.kind} track, enabled=${track.enabled}',
        );
      }
    }

    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _pc!.setLocalDescription(offer);

    debugPrint('📤 Sending offer to $targetId');

    socket.emit('offer', {
      'to': targetId,
      'from': currentUserId,
      'offer': {'sdp': offer.sdp, 'type': offer.type, 'isVideo': isVideo},
      'roomId': currentRoomId,
    });

    debugPrint('✅ Offer sent with media');
  }

  Future<void> answerCall({required String fromId, required Map signal}) async {
    _currentTarget = fromId;
    _pendingCandidates.clear();
    final isVideo = signal['isVideo'] == true;

    debugPrint('📞 Answering call from $fromId, video=$isVideo');

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('⚠ Speaker setup error: $e');
      }
    }

    debugPrint(
      '🔈 Local audio tracks: ${_localStream?.getAudioTracks().length}',
    );
    if (isVideo) {
      debugPrint(
        '🎥 Local video tracks: ${_localStream?.getVideoTracks().length}',
      );
    }

    onLocalStream?.call(_localStream!);

    _pc = await _createPeerConnection(isVideo, fromId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
        debugPrint(
          '➕ Added local ${track.kind} track, enabled=${track.enabled}',
        );
      }
    }

    if (signal['roomId'] != null) {
      currentRoomId = signal['roomId'];
      debugPrint("📦 Joined existing room: $currentRoomId");
    }

    final remoteSdp = signal['sdp'] as String?;
    final remoteType = signal['type'] as String?;

    if (remoteSdp != null && remoteType != null) {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(remoteSdp, remoteType),
      );
      debugPrint('✅ Remote description set from signal');

      final answer = await _pc!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      });
      await _pc!.setLocalDescription(answer);

      debugPrint('📤 Sending answer to $fromId');

      socket.emit('answer', {
        'to': fromId,
        'from': currentUserId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'roomId': currentRoomId,
      });

      socket.emit('answer-call', {
        'to': fromId,
        'signal': {'sdp': answer.sdp, 'type': answer.type},
      });

      debugPrint(
        '✅ Answer sent with ${isVideo ? "video+audio" : "audio only"}',
      );
    } else {
      debugPrint('📢 Notifying caller that call is accepted');
      socket.emit('call-accepted-by-receiver', {
        'to': fromId,
        'from': currentUserId,
        'isVideo': isVideo,
      });
    }
  }

  Future<void> _retryConnection(bool isVideo) async {
    if (_retryAttempts >= _maxRetryAttempts) {
      debugPrint('❌ Max retry attempts reached, giving up');
      return;
    }

    if (_currentTarget == null || _pc == null) {
      debugPrint('⚠ Cannot retry: missing target or peer connection');
      return;
    }

    _retryAttempts++;
    debugPrint(
      '🔄 Connection retry attempt $_retryAttempts/$_maxRetryAttempts',
    );

    await Future.delayed(Duration(seconds: 2 * _retryAttempts));

    try {
      debugPrint('🔄 Attempting ICE restart...');

      final offer = await _pc!.createOffer({
        'iceRestart': true,
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      });

      await _pc!.setLocalDescription(offer);

      socket.emit('offer', {
        'to': _currentTarget,
        'from': currentUserId,
        'offer': {'sdp': offer.sdp, 'type': offer.type, 'isVideo': isVideo},
        'roomId': currentRoomId,
      });

      debugPrint('✅ ICE restart offer sent');
    } catch (e) {
      debugPrint('⚠ ICE restart failed: $e');
    }
  }

  void endCall({String? forceTargetId}) {
    try {
      final to = forceTargetId ?? _currentTarget;
      if (to != null && socket.connected) {
        socket.emit('end-call', {'to': to, 'from': currentUserId});
        debugPrint('📞 Emitted end-call to $to');
      } else {
        debugPrint('⚠ No target for end-call');
      }
    } catch (e) {
      debugPrint('⚠ endCall error: $e');
    }
    onCallEnded?.call();
    _cleanupPeer();
  }

  void rejectCall(String toId) {
    try {
      socket.emit('reject-call', {'to': toId, 'from': currentUserId});
    } catch (e) {
      debugPrint('⚠ rejectCall emit error: $e');
    }
    onCallEnded?.call();
    _cleanupPeer();
  }

  void _cleanupPeer() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _retryAttempts = 0;
    _processingCandidates = false; // 🔴 Reset processing flag

    try {
      _pc?.close();
    } catch (_) {}
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      _localStream?.dispose();
    } catch (_) {}
    _pc = null;
    _localStream = null;
    _currentTarget = null;
    _pendingCandidates.clear();
    _isAnswering = false;
    debugPrint('🧹 Peer cleaned up');
  }

  void dispose() {
    _connectionCheckTimer?.cancel();
    _cleanupPeer();
    try {
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
  }
}

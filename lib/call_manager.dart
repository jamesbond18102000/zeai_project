import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:io';
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

  CallManager({required this.serverUrl, required this.currentUserId});

  // ✅ Initialize socket connection
  Future<void> init() async {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'], // 🔴 ADDED: polling fallback
      'autoConnect': true,
      'forceNew': true,
    });

    socket.onConnect((_) {
      socket.emit('join', currentUserId);
      debugPrint('✅ Connected to socket as $currentUserId');
    });

    // ✅ Incoming call
    socket.on('incoming-call', (data) {
      try {
        final from = data['from'] as String;
        final signal = Map<String, dynamic>.from(data['signal'] ?? {});
        onIncomingCall?.call(from, signal);
      } catch (e) {
        debugPrint('⚠ incoming-call parse error: $e');
      }
    });

    // 🔴 NEW: Listen for WebRTC offer from backend
    socket.on('offer', (data) async {
      try {
        debugPrint('📥 Received offer from ${data['from']}');
        final from = data['from'] as String;
        final offerMap = Map<String, dynamic>.from(data['offer'] ?? {});
        final roomId = data['roomId'] as String?;

        if (roomId != null) currentRoomId = roomId;

        final sdp = offerMap['sdp'] as String?;
        final type = offerMap['type'] as String?;

        if (sdp != null && type != null) {
          // Create peer connection if not exists
          if (_pc == null) {
            final isVideo = offerMap['isVideo'] == true;
            await _setupReceiverPeerConnection(from, isVideo);
          }

          await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
          debugPrint('✅ Remote description set (offer)');

          // Create and send answer
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);

          socket.emit('answer', {
            'to': from,
            'from': currentUserId,
            'answer': {'sdp': answer.sdp, 'type': answer.type},
            'roomId': roomId,
          });
          debugPrint('📤 Answer sent to $from');
        }
      } catch (e) {
        debugPrint('⚠ offer handler error: $e');
      }
    });

    // 🔴 NEW: Listen for WebRTC answer from backend
    socket.on('answer', (data) async {
      try {
        debugPrint('📥 Received answer from ${data['from']}');
        final answerMap = Map<String, dynamic>.from(data['answer'] ?? {});
        final sdp = answerMap['sdp'] as String?;
        final type = answerMap['type'] as String?;

        if (sdp != null && type != null && _pc != null) {
          await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
          debugPrint('✅ Remote description set (answer)');
        }
      } catch (e) {
        debugPrint('⚠ answer handler error: $e');
      }
    });

    // ✅ Call accepted (OLD - kept for compatibility)
    socket.on('call-accepted', (data) async {
      try {
        final signal = Map<String, dynamic>.from(data as Map);
        final sdp = signal['sdp'] as String?;
        final type = signal['type'] as String?;
        if (sdp != null && type != null && _pc != null) {
          await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
        }
      } catch (e) {
        debugPrint('⚠ call-accepted error: $e');
      }
    });

    // ✅ Call rejected
    socket.on('call-rejected', (data) {
      debugPrint('ℹ Received call-rejected: $data');
      onCallEnded?.call();
      _cleanupPeer();
    });

    // ✅ Call ended remotely
    socket.on('call-ended', (data) {
      debugPrint('ℹ Received call-ended: $data');
      onCallEnded?.call();
      _cleanupPeer();
    });

    // 🔴 FIXED: ICE candidates handler
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

        if (_pc != null) {
          await _pc!.addCandidate(candidate);
          debugPrint('✅ ICE candidate added');
        } else {
          debugPrint('⚠ PeerConnection null when adding candidate');
        }
      } catch (e) {
        debugPrint('⚠ ice-candidate error: $e');
      }
    });

    socket.onDisconnect((_) {
      debugPrint('⚠ Socket disconnected');
    });
  }

  // 🔴 NEW: Setup peer connection for receiver (when offer arrives)
  Future<void> _setupReceiverPeerConnection(String fromId, bool isVideo) async {
    _currentTarget = fromId;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo ? {'facingMode': 'user'} : false,
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Helper.setSpeakerphoneOn(true);
    }

    debugPrint(
      '🔈 Local audio tracks: ${_localStream?.getAudioTracks().length}',
    );
    onLocalStream?.call(_localStream!);

    _pc = await _createPeerConnection(isVideo, fromId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }
  }

  /// 🔴 ENHANCED: Create Peer Connection with TURN servers
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
        // 🔴 ADDED: TURN servers for laptop-to-laptop
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
      'sdpSemantics': 'unified-plan', // 🔴 ADDED
    };

    final pc = await createPeerConnection(configuration);

    // 🔴 ENHANCED: ICE connection state logging
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('🔄 ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('❌ ICE connection failed');
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('🔗 PeerConnection state: $state');
    };

    pc.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('📡 ICE gathering state: $state');
    };

    // 🔴 FIXED: ICE candidate emission
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

    // 🔴 ENHANCED: Track handling with better logging
    pc.onTrack = (RTCTrackEvent event) {
      debugPrint(
        '📹 onTrack: kind=${event.track.kind}, streams=${event.streams.length}',
      );

      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        debugPrint(
          '✅ Remote stream received with ${stream.getTracks().length} tracks',
        );
        onRemoteStream?.call(stream);
      } else {
        debugPrint('⚠ onTrack event but no streams');
      }
    };

    return pc;
  }

  /// ✅ Create room (for group call)
  void createRoom(String targetId) {
    currentRoomId = "room_${DateTime.now().millisecondsSinceEpoch}";
    socket.emit("create-room", {
      'roomId': currentRoomId,
      'creator': currentUserId,
      'target': targetId,
      'isVideo': true, // 🔴 ADDED: isVideo flag
    });
    debugPrint("🏠 Room created: $currentRoomId by $currentUserId");
  }

  /// ✅ Invite another participant into an existing room
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

  /// 🔴 ENHANCED: Start a call (caller) - NOW SENDS OFFER EVENT
  Future<void> startCall({
    required String targetId,
    required bool isVideo,
  }) async {
    _currentTarget = targetId;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo ? {'facingMode': 'user'} : false,
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Helper.setSpeakerphoneOn(true);
    }

    debugPrint(
      '🔈 Local audio tracks: ${_localStream?.getAudioTracks().length}',
    );
    onLocalStream?.call(_localStream!);

    _pc = await _createPeerConnection(isVideo, targetId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }

    // ✅ Create room for group call
    currentRoomId = "room_${DateTime.now().millisecondsSinceEpoch}";

    // 🔴 CRITICAL FIX: Create offer with proper options
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _pc!.setLocalDescription(offer);

    debugPrint('📤 Sending offer to $targetId');

    // 🔴 NEW: Send offer event (BACKEND EXPECTS THIS)
    socket.emit('offer', {
      'to': targetId,
      'from': currentUserId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'roomId': currentRoomId,
    });

    // 🔴 ALSO: Keep old call-user for compatibility
    socket.emit('call-user', {
      'target': targetId,
      'from': currentUserId,
      'signal': {
        'sdp': offer.sdp,
        'type': offer.type,
        'isVideo': isVideo,
        'roomId': currentRoomId,
      },
    });

    debugPrint('✅ Offer and call-user sent');
  }

  /// 🔴 ENHANCED: Answer a call (receiver)
  Future<void> answerCall({required String fromId, required Map signal}) async {
    _currentTarget = fromId;
    final isVideo = signal['isVideo'] == true;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo ? {'facingMode': 'user'} : false,
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Helper.setSpeakerphoneOn(true);
    }

    debugPrint(
      '🔈 Local audio tracks: ${_localStream?.getAudioTracks().length}',
    );
    onLocalStream?.call(_localStream!);

    _pc = await _createPeerConnection(isVideo, fromId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }

    // ✅ Save room ID if provided
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
    }

    // 🔴 CRITICAL FIX: Create answer with proper options
    final answer = await _pc!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _pc!.setLocalDescription(answer);

    debugPrint('📤 Sending answer to $fromId');

    // 🔴 NEW: Send answer event (BACKEND EXPECTS THIS)
    socket.emit('answer', {
      'to': fromId,
      'from': currentUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'roomId': currentRoomId,
    });

    // 🔴 ALSO: Keep old answer-call for compatibility
    socket.emit('answer-call', {
      'to': fromId,
      'signal': {'sdp': answer.sdp, 'type': answer.type},
    });

    debugPrint('✅ Answer sent');
  }

  /// ✅ End call
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

  /// ✅ Reject incoming call
  void rejectCall(String toId) {
    try {
      socket.emit('reject-call', {'to': toId, 'from': currentUserId});
    } catch (e) {
      debugPrint('⚠ rejectCall emit error: $e');
    }
    onCallEnded?.call();
    _cleanupPeer();
  }

  /// ✅ Cleanup peer connection and streams
  void _cleanupPeer() {
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
    debugPrint('🧹 Peer cleaned up');
  }

  /// ✅ Dispose
  void dispose() {
    _cleanupPeer();
    try {
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
  }
}

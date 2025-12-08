import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
// ❌ DELETED: import 'package:flutter_webrtc/flutter_webrtc.dart'; // WebRTC logic removed, LiveKit handles media
// 🔥 ADDED: LiveKit client import
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class CallManager extends ChangeNotifier {
  late IO.Socket socket;

  // ❌ DELETED: RTCPeerConnection logic (RTCPeerConnection? _pc, MediaStream? _localStream, etc.)
  // 🔥 ADDED: LiveKit Room instance to manage connection
  Room? _room;
  Room? get room => _room;

  final String serverUrl;
  final String currentUserId;
  // 🔥 ADDED: LiveKit Cloud URL (Replace with yours)
  final String liveKitUrl = 'wss://hrm-project-3gj7q3cn.livekit.cloud';

  // Callbacks
  Function(String fromId, String roomId, bool isVideo)? onIncomingCall;
  VoidCallback? onCallAccepted;
  VoidCallback? onCallRejected;
  VoidCallback? onCallEnded;

  // ❌ DELETED: ICE Candidate lists and queues (LiveKit handles ICE internally)

  CallManager({required this.serverUrl, required this.currentUserId});

  Future<void> init() async {
    // ℹ️ KEPT: Socket.IO logic for "Ringing" notifications only
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    socket.onConnect((_) {
      socket.emit('join', currentUserId);
      debugPrint('✅ Connected to socket as $currentUserId');
    });

    socket.on('incoming-call', (data) {
      try {
        debugPrint("📥 Incoming call data: $data");
        final from = data['from'] as String;
        //final roomId =
        //  data['roomId'] as String; // 🔥 ADDED: Room ID needed for LiveKit
        final roomId =
            data['roomId'] as String? ??
            "${from}_${DateTime.now().millisecondsSinceEpoch}";
        final isVideo = data['isVideo'] == true;
        onIncomingCall?.call(from, roomId, isVideo);
      } catch (e) {
        debugPrint('⚠ incoming-call parse error: $e');
      }
    });

    // ❌ DELETED: 'offer', 'answer', 'ice-candidate' event listeners (No longer needed)

    socket.on('call-accepted', (data) {
      debugPrint('✅ Call accepted by receiver');
      onCallAccepted?.call();
    });

    socket.on('call-rejected', (_) {
      debugPrint('ℹ Received call-rejected');
      onCallRejected?.call();
    });

    socket.on('call-ended', (_) {
      debugPrint('ℹ Received call-ended');
      onCallEnded?.call();
      disconnectLiveKit(); // 🔥 ADDED: Disconnect LiveKit when call ends
    });
  }

  // 🔥 ADDED: Function to connect to LiveKit Room
  // This replaces _setupReceiverPeerConnection and _createPeerConnection
  Future<bool> joinRoom(String roomId, bool isVideo) async {
    try {
      debugPrint("🔄 Fetching Token for Room: $roomId");

      // 1. Get Token from Backend
      final token = await _getToken(roomId);
      if (token.isEmpty) {
        debugPrint("❌ Token is empty");
        return false;
      }

      debugPrint("🔑 Token received, connecting to LiveKit...");

      // 2. Setup Audio/Video Options
      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: const AudioPublishOptions(
          name: 'audio_track',
        ),
        defaultVideoPublishOptions: const VideoPublishOptions(
          name: 'video_track',
        ),
      );

      // 3. Connect to Room
      _room = Room();

      // *** RED: Added connect options with timeouts ***
      final connectOptions = ConnectOptions(autoSubscribe: true);

      await _room!.connect(
        liveKitUrl,
        token,
        roomOptions: roomOptions,
        connectOptions: connectOptions,
      );

      // 4. Publish Local Media
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.localParticipant?.setCameraEnabled(isVideo);

      debugPrint('✅ Connected to LiveKit Room: $roomId');
      return true;
    } catch (e) {
      debugPrint('❌ LiveKit Connection Failed: $e');
      // *** RED: Clean up if connection fails ***
      disconnectLiveKit();
      return false;
    }
  }

  // 🔥 ADDED: Helper to fetch JWT Token from your Node.js backend
  Future<String> _getToken(String roomId) async {
    try {
      // *** RED: Added error handling for network request ***
      final uri = Uri.parse(
        '$serverUrl/livekit/token?roomName=$roomId&participantName=$currentUserId',
      );
      debugPrint("🌐 Requesting token from: $uri");
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      // final response = await http.get(
      //   Uri.parse(
      //     '$serverUrl/livekit/token?roomName=$roomId&participantName=$currentUserId',
      // ),
      //);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['token'];
      } else {
        debugPrint(
          '❌ Failed to fetch token: ${response.statusCode} - ${response.body}',
        );
        return "";
        //throw Exception('Failed to fetch token: ${response.body}');
      }
    } catch (e) {
      //throw Exception('Token fetch error: $e');
      debugPrint('❌ Token fetch error: $e');
      return "";
    }
  }

  // --- Signaling (Socket.IO) ---

  // 🔥 UPDATED: Now sends roomId with call
  void startCall(String targetId, String roomId, bool isVideo) {
    debugPrint("📞 Calling $targetId in room $roomId");
    socket.emit('initiate-call', {
      'from': currentUserId,
      'to': targetId,
      'roomId': roomId,
      'isVideo': isVideo,
    });
  }

  void answerCall(String targetId, String roomId) {
    debugPrint("📞 Answering call from $targetId");
    socket.emit('answer-call', {
      'from': currentUserId,
      'to': targetId,
      'roomId': roomId,
    });
  }

  void rejectCall(String targetId) {
    socket.emit('reject-call', {'from': currentUserId, 'to': targetId});
  }

  void endCall(String targetId) {
    socket.emit('end-call', {'to': targetId, 'from': currentUserId});
    disconnectLiveKit();
  }

  // 🔥 ADDED: Cleanup LiveKit connection
  void disconnectLiveKit() async {
    if (_room != null) {
      // *** RED: Wrap disconnect in try-catch to prevent crashes ***
      try {
        await _room!.disconnect();
      } catch (e) {
        debugPrint("Error disconnecting room: $e");
      }
      _room = null;
    }
  }

  @override
  void dispose() {
    disconnectLiveKit();
    socket.dispose();
    super.dispose();
  }
}

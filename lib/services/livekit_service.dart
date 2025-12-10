import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart';
import 'socket_service.dart';

const String livekitUrl =
    "wss://hrm-project-3gj7q3cn.livekit.cloud"; // Your LiveKit server URL
//wss://hrm-project-3gj7q3cn.livekit.cloud

class LiveKitService with ChangeNotifier {
  LiveKitService._internal();
  static final LiveKitService instance = LiveKitService._internal();

  Room? _room;
  Room? get room => _room;

  bool _isVideoCall = false;
  bool get isVideoCall => _isVideoCall;

  GlobalKey<NavigatorState>? navigatorKey;
  void setNavigatorKey(GlobalKey<NavigatorState> key) => navigatorKey = key;

  /// -------------------------
  /// Fetch LiveKit token from backend
  /// -------------------------
  Future<String?> _fetchLiveKitToken({
    required String roomName,
    required String identity,
  }) async {
    if (roomName.isEmpty || identity.isEmpty) {
      debugPrint('❌ Room name or identity cannot be empty.');
      return null;
    }

    final url = Uri.parse('$apiBaseUrl/api/get-livekit-token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomName': roomName, 'identity': identity}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final token = data['token'];
        if (token != null && token is String && token.isNotEmpty) {
          return token;
        }
      }
      debugPrint('❌ Failed to fetch token: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Error fetching token: $e');
    }
    return null;
  }

  /// -------------------------
  /// Connect to a LiveKit room
  /// -------------------------
  Future<void> connectToRoom({
    required String roomName,
    required String userName,
    required bool isVideo,
    String? serverUrl,
  }) async {
    try {
      final token = await _fetchLiveKitToken(
        roomName: roomName,
        identity: userName,
      );
      if (token == null)
        throw Exception('Could not fetch a valid LiveKit token.');

      _isVideoCall = isVideo;
      final urlToUse = serverUrl ?? livekitUrl;

      _room = Room(
        roomOptions: RoomOptions(adaptiveStream: true, dynacast: true),
      );

      await _room!.connect(urlToUse, token);
      debugPrint('✅ Connected to LiveKit room: $roomName');

      // Ensure microphone is enabled (most calls assume audio present).
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
      } catch (e) {
        debugPrint('⚠️ setMicrophoneEnabled not available on this SDK: $e');
      }

      // Publish tracks AFTER connecting, based on isVideo flag.
      if (isVideo) {
        try {
          await _room!.localParticipant?.setCameraEnabled(true);
        } catch (e) {
          debugPrint('⚠️ setCameraEnabled(true) failed: $e');
        }
      } else {
        // Audio-only: disable camera and mute any video tracks
        try {
          await _room!.localParticipant?.setCameraEnabled(false);
        } catch (e) {
          debugPrint('⚠️ setCameraEnabled(false) failed: $e');
        }

        try {
          final pubs = _room!.localParticipant?.videoTrackPublications ?? [];
          for (final pub in pubs) {
            try {
              try {
                await (pub as dynamic).mute();
              } catch (_) {
                try {
                  await (pub as dynamic).setMuted(true);
                } catch (_) {}
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('⚠️ could not mute video publications: $e');
        }
      }

      notifyListeners(); // Notify UI that connection and tracks are set up.
    } catch (e) {
      debugPrint('❌ Failed to connect to room: $e');
      rethrow;
    }
  }

  /// -------------------------
  /// Toggle microphone
  /// -------------------------
  Future<void> toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;

    try {
      await lp.setMicrophoneEnabled(!lp.isMicrophoneEnabled());
    } catch (e) {
      debugPrint('⚠️ toggleMic API difference: $e');
    }
    notifyListeners();
  }

  /// -------------------------
  /// Toggle camera
  /// -------------------------
  Future<void> toggleCamera() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;

    final currentlyEnabled = lp.isCameraEnabled();
    final shouldEnable = !currentlyEnabled;

    try {
      await lp.setCameraEnabled(shouldEnable);
    } catch (e) {
      debugPrint('⚠️ setCameraEnabled API difference: $e');
    }

    if (!shouldEnable) {
      try {
        final pubs = lp.videoTrackPublications ?? [];
        for (final pub in pubs) {
          try {
            try {
              await (pub as dynamic).mute();
            } catch (_) {
              try {
                await (pub as dynamic).setMuted(true);
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint(
          '⚠️ Could not mute local video publications on camera toggle: $e',
        );
      }
    }

    notifyListeners();
  }

  /// -------------------------
  /// Disconnect from the room
  /// -------------------------
  Future<void> disconnect() async {
    if (_room != null) {
      try {
        await _room!.disconnect();
      } catch (e) {
        debugPrint('⚠️ disconnect threw: $e');
      }
      _room = null;
      debugPrint('✅ Disconnected from LiveKit room');
    }
    notifyListeners();
  }

  /// -------------------------
  /// Remote participants list
  /// -------------------------
  List<RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];
}

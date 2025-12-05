import 'package:flutter/material.dart' hide ConnectionState;
// FIX: Hide Flutter's ConnectionState to avoid conflict
// ❌ DELETED: import 'package:flutter_webrtc/flutter_webrtc.dart'; // Removed WebRTC
import 'package:livekit_client/livekit_client.dart'; // 🔥 ADDED: LiveKit Client
import 'call_manager.dart';

class AudioCallPage extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final bool isCaller;
  final bool isVideo;
  final Map? offerSignal; // Receiver-ku ithula 'roomId' irukum

  const AudioCallPage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    this.isCaller = false,
    this.isVideo = false,
    this.offerSignal,
  });

  @override
  State<AudioCallPage> createState() => _AudioCallPageState();
}

class _AudioCallPageState extends State<AudioCallPage> {
  late CallManager _callManager;

  // ❌ DELETED: RTCVideoRenderer _remoteRenderer, _localRenderer (Not needed for LiveKit)

  // 🔥 ADDED: LiveKit State Variables
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  List<Participant> participants = [];
  bool _isCallActive = true;

  @override
  void initState() {
    super.initState();
    _setupCallManager();
  }

  void _setupCallManager() {
    _callManager = CallManager(
      serverUrl: 'https://zeai-project.onrender.com', // Unga backend URL
      currentUserId: widget.currentUserId,
    );

    _callManager.init();

    // Listen for End Call event from Remote User
    _callManager.onCallEnded = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Call ended by other user")),
        );
        Navigator.pop(context);
      }
    };

    _startCall();
  }

  Future<void> _startCall() async {
    String roomId;

    if (widget.isCaller) {
      // Caller: Puthu Room ID Create panrom (Unique ID)
      roomId =
          "${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}";
    } else {
      // Receiver: Invitation-la irunthu Room ID Edukurom
      roomId = widget.offerSignal?['roomId'] ?? "default_room";
    }

    debugPrint("🚀 Joining LiveKit Room: $roomId");

    // 🔥 ADDED: Join LiveKit Room via CallManager
    final success = await _callManager.joinRoom(roomId, widget.isVideo);

    if (success && _callManager.room != null) {
      if (!mounted) return;

      setState(() {
        _room = _callManager.room;
        _listener = _room!.createListener();
        _updateParticipantList(); // Initial List
      });

      // 🔥 ADDED: Listeners for Participant Events (Join, Leave, Video On/Off)
      _listener!
        ..on<ParticipantConnectedEvent>((_) => _updateParticipantList())
        ..on<ParticipantDisconnectedEvent>((_) => _updateParticipantList())
        ..on<TrackSubscribedEvent>((_) => _updateParticipantList())
        ..on<TrackUnsubscribedEvent>((_) => _updateParticipantList())
        ..on<TrackMutedEvent>((_) => setState(() {})) // Mute icon update
        ..on<TrackUnmutedEvent>((_) => setState(() {}));

      // Signal the other user via Socket.IO
      if (widget.isCaller) {
        _callManager.startCall(widget.targetUserId, roomId, widget.isVideo);
      } else {
        _callManager.answerCall(widget.targetUserId, roomId);
      }
    } else {
      debugPrint("❌ Failed to join room");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to connect to LiveKit server")),
        );
        Navigator.pop(context);
      }
    }
  }

  void _updateParticipantList() {
    if (_room == null) return;
    if (mounted) {
      setState(() {
        // Combine Local + Remote Participants into one list for the Grid
        participants = [
          _room!.localParticipant!,
          ..._room!.remoteParticipants.values,
        ];
      });
    }
  }

  // Toggle Microphone
  void _toggleMute() async {
    if (_room?.localParticipant != null) {
      final isEnabled = _room!.localParticipant!.isMicrophoneEnabled();
      await _room!.localParticipant!.setMicrophoneEnabled(!isEnabled);
      setState(() {});
    }
  }

  // Toggle Camera
  void _toggleCamera() async {
    if (_room?.localParticipant != null) {
      final isEnabled = _room!.localParticipant!.isCameraEnabled();
      await _room!.localParticipant!.setCameraEnabled(!isEnabled);
      setState(() {});
    }
  }

  // Toggle Speaker (LiveKit handles audio routing usually, but we can force logic here if needed)
  void _toggleSpeaker() {
    // LiveKit usually manages this automatically on mobile.
    // But you can use hardware plugins if needed.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Speaker toggle managed by OS")),
    );
  }

  @override
  void dispose() {
    _isCallActive = false;
    _listener?.dispose();

    // 🔥 ADDED: Proper Cleanup
    // End call signal sending
    _callManager.endCall(widget.targetUserId);
    _callManager.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isVideo ? 'Video Call' : 'Audio Call';

    // Determine connection status
    final isConnected =
        _room != null && _room!.connectionState == ConnectionState.connected;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.deepPurple),
      body: SafeArea(
        child: Column(
          children: [
            /// --- 🔥 ADDED: VIDEO GRID AREA --- ///
            Expanded(
              child: !isConnected
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.deepPurple),
                          SizedBox(height: 20),
                          Text(
                            "Connecting to LiveKit...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : participants.isEmpty
                  ? const Center(
                      child: Text(
                        "Waiting for others...",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2 Columns
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        return ParticipantWidget(
                          participant: participants[index],
                        );
                      },
                    ),
            ),

            /// --- CONTROL BUTTONS --- ///
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.black87,
                border: Border(
                  top: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic Toggle
                  CircleAvatar(
                    backgroundColor:
                        (_room?.localParticipant?.isMicrophoneEnabled() ??
                            false)
                        ? Colors.blue
                        : Colors.orange,
                    radius: 28,
                    child: IconButton(
                      icon: Icon(
                        (_room?.localParticipant?.isMicrophoneEnabled() ??
                                false)
                            ? Icons.mic
                            : Icons.mic_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),

                  // End Call
                  CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 32,
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Video Toggle
                  CircleAvatar(
                    backgroundColor:
                        (_room?.localParticipant?.isCameraEnabled() ?? false)
                        ? Colors.blue
                        : Colors.grey,
                    radius: 28,
                    child: IconButton(
                      icon: Icon(
                        (_room?.localParticipant?.isCameraEnabled() ?? false)
                            ? Icons.videocam
                            : Icons.videocam_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleCamera,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 ADDED: Helper Widget to Render Individual Participant
class ParticipantWidget extends StatelessWidget {
  final Participant participant;

  const ParticipantWidget({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    // 🔥 FIX: Use videoTrackPublications instead of videoTracks
    // Also handle potential nulls safely
    // Get Video Track if available

    VideoTrack? videoTrack;
    if (participant.videoTrackPublications.isNotEmpty) {
      videoTrack =
          participant.videoTrackPublications.first.track as VideoTrack?;
    }

    //final videoTrack =
    //  participant.videoTracks.firstOrNull?.track as VideoTrack?;
    final isMuted = !participant.isMicrophoneEnabled();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Video Layer
          videoTrack != null
              ? VideoTrackRenderer(videoTrack) // 🔥 LiveKit Video Renderer
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, size: 60, color: Colors.white54),
                      const SizedBox(height: 8),
                      Text(
                        participant.identity ?? "User",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

          // Mute Indicator
          if (isMuted)
            const Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Icon(Icons.mic_off, size: 14, color: Colors.white),
              ),
            ),

          // Name Label
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participant.identity ?? "Unknown",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

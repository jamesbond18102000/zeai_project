import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/livekit_service.dart';

class CallScreen extends StatefulWidget {
  final String callType; // "audio" or "video"

  const CallScreen({super.key, required this.callType});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Room? get _room => LiveKitService.instance.room;
  EventsListener? _listener;

  List<Participant> _participants = [];
  bool _isMicMuted = false;
  bool _isCameraOff = false;

  // Prevent double taps while async toggle in progress
  bool _micProcessing = false;
  bool _cameraProcessing = false;

  @override
  void initState() {
    super.initState();

    if (_room != null) {
      _listener = _room!.createListener();
      _setupListeners();
      _updateParticipants();

      final local = _room!.localParticipant;
      if (local != null) {
        _isCameraOff = !local.isCameraEnabled();
        _isMicMuted = !local.isMicrophoneEnabled();
      }
    }
  }

  void _setupListeners() {
    _listener!
      // 1. IMPORTANT: Handle New People Joining
      ..on<ParticipantConnectedEvent>((event) {
        print("Someone joined: ${event.participant.identity}");
        _updateParticipants();
      })
      // 2. IMPORTANT: Handle People Leaving
      ..on<ParticipantDisconnectedEvent>((event) {
        print("Someone left: ${event.participant.identity}");
        _updateParticipants();
      })
      //..on<ParticipantEvent>((_) => _updateParticipants())
      ..on<TrackMutedEvent>((_) => _updateParticipants())
      ..on<TrackUnmutedEvent>((_) => _updateParticipants())
      ..on<LocalTrackPublishedEvent>((_) => _updateParticipants())
      ..on<LocalTrackUnpublishedEvent>((_) => _updateParticipants())
      ..on<TrackSubscribedEvent>(
        (_) => _updateParticipants(),
      ) // Video load aaga ithu thevai
      ..on<TrackUnsubscribedEvent>((_) => _updateParticipants())
      // 4. Handle Disconnection
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted) Navigator.pop(context);
      });
  }

  void _updateParticipants() {
    if (!mounted) return;

    setState(() {
      // 1. Get all remote participants
      _participants = _room?.remoteParticipants.values.toList() ?? [];
      // 2. Add local participant (You) to the START of the list
      if (_room?.localParticipant != null) {
        // Just in case it's already there (rare), remove it first
        _participants.remove(_room!.localParticipant);
        // Insert at Index 0 so you are always the first tile
        _participants.insert(0, _room!.localParticipant!);
      }
    });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  //Future<void> _toggleMic() async {
  /*
  Future<void> _toggleMic() async {
    

    final local = _room?.localParticipant;
    if (local == null) return;

    final newState = !_isMicMuted;
    await local.setMicrophoneEnabled(newState);
    setState(() => _isMicMuted = !newState);
  }


  Future<void> _toggleCamera() async {
    if (widget.callType == "audio") return;
    final local = _room?.localParticipant;
    if (local == null) return;

    final newState = !_isCameraOff;
    await local.setCameraEnabled(newState);
    setState(() => _isCameraOff = !newState);

*/

  Future<void> _toggleMic() async {
    // Prevent double taps
    if (_micProcessing) return;
    _micProcessing = true;

    try {
      final local = _room?.localParticipant;
      if (local == null) return;

      // Current flag _isMicMuted = true means mic is currently muted.
      // We will flip the muted state:
      final newMuted = !_isMicMuted;

      // setMicrophoneEnabled expects "enabled" boolean.
      // enabled = !newMuted
      final enabled = !newMuted;

      // call LiveKit
      await local.setMicrophoneEnabled(enabled);

      // update UI to reflect the new muted state
      if (mounted) setState(() => _isMicMuted = newMuted);
    } catch (e) {
      // optional: you can log or show a toast here
      print('Toggle mic error: $e');
    } finally {
      _micProcessing = false;
    }
  }

  // Future<void> _toggleCamera() async {
  //   if (widget.callType == "audio") return;
  //   final local = _room?.localParticipant;
  //   if (local == null) return;

  //   final newState = !_isCameraOff;
  //   await local.setCameraEnabled(newState);
  //   setState(() => _isCameraOff = !newState);
  // }
  // ---------- FIXED: camera toggle logic ----------
  Future<void> _toggleCamera() async {
    if (widget.callType == "audio") return;
    if (_cameraProcessing) return;
    _cameraProcessing = true;

    try {
      final local = _room?.localParticipant;
      if (local == null) return;

      // _isCameraOff true means camera currently off.
      // We flip to newCameraOff:
      final newCameraOff = !_isCameraOff;
      final enabled = !newCameraOff; // enabled = camera on/off

      await local.setCameraEnabled(enabled);

      if (mounted) setState(() => _isCameraOff = newCameraOff);
    } catch (e) {
      print('Toggle camera error: $e');
    } finally {
      _cameraProcessing = false;
    }
  }

  Future<void> _hangUp() async {
    await LiveKitService.instance.disconnect();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // **FIX: Removed ConstrainedBox & ScrollConfiguration**
    // Now uses SafeArea + Column for full width/height
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.callType == "audio" ? Icons.mic : Icons.videocam,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.callType.toUpperCase()} Video',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_participants.length} Active",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- MAIN CONTENT (UNIFIED GRID) ---
            // Handles BOTH Audio and Video calls using the same logic
            Expanded(child: _buildUnifiedGrid()),
            // --- CONTROLS ---
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  // **NEW: Unified Grid Logic for Audio & Video**
  Widget _buildUnifiedGrid() {
    if (_participants.isEmpty) {
      return const Center(
        child: Text(
          "Waiting for participants...",
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    int count = _participants.length;
    // Dynamic Columns (Teams Style)
    // 1 user -> 1 col
    // 2 users -> 1 col (Vertical Split)
    // 3-4 users -> 2 cols
    // 5+ users -> 2 or 3 cols
    int crossAxisCount = count <= 2 ? 1 : (count <= 6 ? 2 : 3);

    // Aspect Ratio:
    // 1-2 users = 1.3 (Taller)
    // 3+ users = 1.0 (Square)
    double ratio = count <= 2 ? 1.3 : 1.0;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: ratio,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final p = _participants[index];
          // Check if user has video enabled
          bool isVideoOn = p.isCameraEnabled();
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // Green border when speaking
                color: p.isSpeaking ? Colors.greenAccent : Colors.white10,
                width: p.isSpeaking ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Layer 1: Content (Video or Avatar)
                Positioned.fill(
                  child: isVideoOn
                      ? ParticipantTile(participant: p) // Show Video
                      : _buildAudioAvatar(p), // Show Avatar
                ),
                // Layer 2: Name Tag (Always visible)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                          size: 14,
                          color: p.isMicrophoneEnabled()
                              ? Colors.white
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p.identity.isEmpty ? "Unknown" : p.identity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for Audio-only appearance
  Widget _buildAudioAvatar(Participant p) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors
                  .primaries[p.identity.hashCode % Colors.primaries.length],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              p.identity.isNotEmpty ? p.identity[0].toUpperCase() : "?",
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (p.isSpeaking) ...[
            const SizedBox(height: 12),
            const Text(
              "Speaking...",
              style: TextStyle(color: Colors.greenAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          icon: _isMicMuted ? Icons.mic_off : Icons.mic,
          bgColor: _isMicMuted ? Colors.white : Colors.grey[800]!,
          iconColor: _isMicMuted ? Colors.black : Colors.white,
          onPressed: _toggleMic,
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: _hangUp,
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 24),
        _controlButton(
          icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
          bgColor: _isCameraOff ? Colors.white : Colors.grey[800]!,
          iconColor: _isCameraOff ? Colors.black : Colors.white,
          onPressed: _toggleCamera,
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color bgColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}

// Keeping your existing ParticipantTile for Video Rendering
class ParticipantTile extends StatefulWidget {
  final Participant participant;
  const ParticipantTile({super.key, required this.participant});
  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  TrackPublication? get _videoPub =>
      widget.participant.videoTrackPublications.firstOrNull;
  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pub = _videoPub;
    final track = pub?.track;
    final hasVideo = pub != null && pub.subscribed && !pub.muted;
    if (!hasVideo || track is! VideoTrack) {
      // Return empty container here because _buildUnifiedGrid handles the Avatar fallback
      return Container(color: Colors.grey[900]);
    }

    return VideoTrackRenderer(track);
  }
}

//   @override
//   Widget build(BuildContext context) {
//     // **STEP 2: SELF-PROTECTING WRAPPER - Blocks ALL parent scrolling**
//     return Scaffold(
//       resizeToAvoidBottomInset: false,
//       backgroundColor: Colors.black,
//       body: ScrollConfiguration(
//         // **DISABLES ALL SCROLLING GLOBALLY for this screen**
//         behavior: ScrollConfiguration.of(context).copyWith(
//           scrollbars: false,
//           overscroll: false,
//           physics: const NeverScrollableScrollPhysics(),
//         ),
//         child: Center(
//           // **STEP 1: FIXED SIZE BOX - Never exceeds viewport**
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(
//               maxWidth: 480, // Fixed width - fits any laptop
//               maxHeight: 650, // Fixed height - no scroll possible
//             ),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.grey[900],
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.5),
//                     blurRadius: 30,
//                     spreadRadius: 0,
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize:
//                     MainAxisSize.min, // Never grows beyond constraints
//                 children: [
//                   // Header
//                   Container(
//                     height: 60,
//                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                     decoration: BoxDecoration(
//                       color: Colors.black87,
//                       borderRadius: const BorderRadius.vertical(
//                         top: Radius.circular(20),
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           '${widget.callType.toUpperCase()} CALL',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         IconButton(
//                           icon: const Icon(
//                             Icons.close,
//                             color: Colors.white70,
//                             size: 24,
//                           ),
//                           onPressed: _hangUp,
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Main content area
//                   Expanded(
//                     child: Column(
//                       children: [
//                         // Video/Audio area
//                         Expanded(
//                           child: widget.callType == "audio"
//                               ? _buildAudioContent()
//                               : _buildVideoContent(),
//                         ),

//                         // Controls
//                         Container(
//                           height: 90,
//                           padding: const EdgeInsets.symmetric(horizontal: 24),
//                           decoration: BoxDecoration(
//                             color: Colors.black87,
//                             borderRadius: const BorderRadius.vertical(
//                               bottom: Radius.circular(20),
//                             ),
//                           ),
//                           child: _buildControls(),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildAudioContent() {
//     final name = _participants.isNotEmpty
//         ? _participants.first.identity
//         : "Audio Call";

//     return Container(
//       color: Colors.transparent,
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 color: Colors.grey[800],
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.account_circle,
//                 color: Colors.white70,
//                 size: 80,
//               ),
//             ),
//             const SizedBox(height: 24),
//             Text(
//               name,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               "Active Call",
//               style: TextStyle(color: Colors.white70, fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildVideoContent() {
//     final participants = _participants;

//     if (participants.isEmpty) {
//       return Container(
//         color: Colors.black,
//         child: const Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.video_call, color: Colors.white70, size: 80),
//               SizedBox(height: 20),
//               Text(
//                 "Waiting for participants...",
//                 style: TextStyle(color: Colors.white, fontSize: 18),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Container(
//       margin: const EdgeInsets.all(12),
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           final count = participants.length;
//           final columns = count == 1 ? 1 : (count <= 4 ? 2 : 2);
//           final spacing = 12.0;
//           final itemWidth =
//               (constraints.maxWidth - (columns - 1) * spacing) / columns;
//           final itemHeight = constraints.maxHeight * 0.48;

//           return Wrap(
//             spacing: spacing,
//             runSpacing: spacing,
//             alignment: WrapAlignment.center,
//             children: participants.map((participant) {
//               return SizedBox(
//                 width: itemWidth,
//                 height: itemHeight,
//                 child: ParticipantTile(participant: participant),
//               );
//             }).toList(),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildControls() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         _controlButton(
//           icon: _isMicMuted ? Icons.mic_off : Icons.mic,
//           onPressed: _toggleMic,
//         ),
//         const SizedBox(width: 24),
//         GestureDetector(
//           onTap: _hangUp,
//           child: Container(
//             width: 68,
//             height: 68,
//             decoration: const BoxDecoration(
//               color: Colors.red,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.call_end, color: Colors.white, size: 30),
//           ),
//         ),
//         const SizedBox(width: 24),
//         if (widget.callType == "video")
//           _controlButton(
//             icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
//             onPressed: _toggleCamera,
//           ),
//       ],
//     );
//   }

//   Widget _controlButton({
//     required IconData icon,
//     required VoidCallback onPressed,
//   }) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         width: 60,
//         height: 60,
//         decoration: BoxDecoration(
//           color: Colors.grey[800],
//           shape: BoxShape.circle,
//         ),
//         child: Icon(icon, color: Colors.white, size: 28),
//       ),
//     );
//   }
// }

// class ParticipantTile extends StatefulWidget {
//   final Participant participant;

//   const ParticipantTile({super.key, required this.participant});

//   @override
//   State<ParticipantTile> createState() => _ParticipantTileState();
// }

// class _ParticipantTileState extends State<ParticipantTile> {
//   TrackPublication? get _videoPub =>
//       widget.participant.videoTrackPublications.firstOrNull;

//   @override
//   void initState() {
//     super.initState();
//     widget.participant.addListener(_onChange);
//   }

//   @override
//   void dispose() {
//     widget.participant.removeListener(_onChange);
//     super.dispose();
//   }

//   void _onChange() {
//     if (mounted) setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     final pub = _videoPub;
//     final track = pub?.track;
//     final hasVideo = pub != null && pub.subscribed && !pub.muted;

//     if (!hasVideo || track is! VideoTrack) {
//       return _buildPlaceholder();
//     }

//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white24),
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(10),
//         child: Stack(
//           children: [
//             VideoTrackRenderer(track),
//             Positioned(
//               bottom: 8,
//               left: 8,
//               right: 8,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.black54,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   widget.participant.identity,
//                   style: const TextStyle(color: Colors.white, fontSize: 14),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPlaceholder() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white24),
//       ),
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.videocam_off, color: Colors.white60, size: 40),
//             const SizedBox(height: 12),
//             Text(
//               widget.participant.identity,
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//               textAlign: TextAlign.center,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

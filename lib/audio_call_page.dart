import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_manager.dart';

class AudioCallPage extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final bool isCaller;
  final bool isVideo;
  final Map? offerSignal;

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
  final _remoteRenderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();

  bool _connected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isDisposing = false; // 🔴 NEW: Track disposal state

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupCallManager();
  }

  Future<void> _initializeRenderers() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  void _setupCallManager() {
    _callManager = CallManager(
      serverUrl: 'https://zeai-project.onrender.com',
      currentUserId: widget.currentUserId,
    );

    // 🔴 FIXED: Local preview with mounted check
    _callManager.onLocalStream = (stream) {
      if (!mounted || _isDisposing) return;

      setState(() {
        if (widget.isVideo && _localRenderer.srcObject == null) {
          _localRenderer.srcObject = stream;
          debugPrint(
            '📹 Local video set: ${stream.getVideoTracks().length} tracks',
          );
          debugPrint(
            '🎧 Local audio set: ${stream.getAudioTracks().length} tracks',
          );
        }
      });
    };

    // 🔴 CRITICAL FIX: Remote stream with mounted check
    _callManager.onRemoteStream = (stream) {
      if (!mounted || _isDisposing) return;

      setState(() {
        _remoteRenderer.srcObject = stream;

        final audioTracks = stream.getAudioTracks().length;
        final videoTracks = stream.getVideoTracks().length;
        debugPrint('🎧 Remote audio tracks: $audioTracks');
        debugPrint('📹 Remote video tracks: $videoTracks');

        for (var track in stream.getTracks()) {
          debugPrint(
            '   ${track.kind}: enabled=${track.enabled}, muted=${track.muted}',
          );
        }

        _connected = true;
      });
    };

    _callManager.onCallEnded = () {
      if (!mounted || _isDisposing) return;

      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        debugPrint('⚠ Navigation error: $e');
        try {
          Navigator.of(context).pop();
        } catch (e2) {
          debugPrint('⚠ Fallback navigation error: $e2');
        }
      }
    };

    _startCall();
  }

  Future<void> _startCall() async {
    await _callManager.init();

    if (widget.isCaller) {
      await _callManager.startCall(
        targetId: widget.targetUserId,
        isVideo: widget.isVideo,
      );
    } else if (widget.offerSignal != null) {
      await _callManager.answerCall(
        fromId: widget.targetUserId,
        signal: widget.offerSignal!,
      );
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _callManager.localStream != null && !_isDisposing) {
        setState(() {});
      }
    });
  }

  void _toggleMute() {
    final stream = _callManager.localStream;
    if (stream == null) {
      debugPrint("⚠ Local stream not ready for mute toggle");
      return;
    }

    for (var track in stream.getAudioTracks()) {
      track.enabled = !track.enabled;
    }

    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  Future<void> _toggleSpeaker() async {
    try {
      if (_callManager.localStream == null) {
        debugPrint('⚠ No active audio stream to toggle speaker.');
        return;
      }

      await Helper.setSpeakerphoneOn(!_isSpeakerOn);
      if (mounted) setState(() => _isSpeakerOn = !_isSpeakerOn);

      debugPrint(
        _isSpeakerOn ? '🔊 Speaker turned ON' : '🔈 Speaker turned OFF',
      );
    } catch (e) {
      debugPrint("⚠ Speaker toggle error: $e");
    }
  }

  void _inviteParticipant() async {
    final TextEditingController userIdController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Participant"),
        content: TextField(
          controller: userIdController,
          decoration: const InputDecoration(
            labelText: "Enter user ID to invite",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Invite"),
            onPressed: () {
              final newUserId = userIdController.text.trim();
              if (newUserId.isNotEmpty) {
                _callManager.inviteParticipant(
                  targetId: newUserId,
                  roomId: _callManager.currentRoomId,
                  isVideo: widget.isVideo,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invitation sent to $newUserId'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposing = true; // 🔴 Set flag

    // 🔴 CRITICAL FIX: Dispose in correct order with delays
    try {
      _callManager.endCall(forceTargetId: widget.targetUserId);
    } catch (e) {
      debugPrint('⚠ End call error: $e');
    }

    // 🔴 Clear renderers BEFORE disposing
    try {
      _remoteRenderer.srcObject = null;
      _localRenderer.srcObject = null;
    } catch (e) {
      debugPrint('⚠ Clear srcObject error: $e');
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        _remoteRenderer.dispose();
        _localRenderer.dispose();
        _callManager.dispose();
      } catch (e) {
        debugPrint('⚠ Dispose error: $e');
      }
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isVideo ? 'Video Call' : 'Audio Call';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.deepPurple),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            /// --- VIDEO OR AUDIO AREA --- ///
            Expanded(
              child: widget.isVideo
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // 🔴 Remote video (full screen)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black,
                            child: RTCVideoView(
                              _remoteRenderer,
                              mirror: false,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ),

                        // 🔴 FIXED: Local video preview with null check
                        if (_localRenderer.srcObject != null)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Container(
                              width: 120,
                              height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black26,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: RTCVideoView(
                                  _localRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              ),
                            ),
                          ),

                        // 🔴 NEW: Placeholder when no local stream
                        if (_localRenderer.srcObject == null)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Container(
                              width: 120,
                              height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black54,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.videocam_off,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        _connected ? Icons.headset : Icons.call,
                        size: 120,
                        color: _connected
                            ? Colors.greenAccent
                            : Colors.deepPurple,
                      ),
                    ),
            ),

            /// --- STATUS TEXT --- ///
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                widget.isCaller
                    ? 'Calling ${widget.targetUserId}...'
                    : _connected
                    ? 'Connected'
                    : 'Connecting...',
                style: const TextStyle(color: Colors.white, fontSize: 18),
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
                  // 🎙 Mute / Unmute
                  CircleAvatar(
                    backgroundColor: _isMuted ? Colors.orange : Colors.blue,
                    radius: 28,
                    child: IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),

                  // 🔊 Speaker on/off
                  CircleAvatar(
                    backgroundColor: _isSpeakerOn ? Colors.green : Colors.grey,
                    radius: 28,
                    child: IconButton(
                      icon: Icon(
                        _isSpeakerOn
                            ? Icons.volume_up
                            : Icons.volume_down_outlined,
                        color: Colors.white,
                      ),
                      onPressed: _toggleSpeaker,
                    ),
                  ),

                  // ➕ Add participant
                  CircleAvatar(
                    backgroundColor: Colors.purple,
                    radius: 28,
                    child: IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      onPressed: _inviteParticipant,
                    ),
                  ),

                  // 🚫 End Call
                  CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 28,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      onPressed: () {
                        _callManager.endCall(
                          forceTargetId: widget.targetUserId,
                        );
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
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

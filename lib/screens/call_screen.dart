import 'dart:math';
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

  final List<Participant> _participants = [];

  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _micProcessing = false;
  bool _cameraProcessing = false;

  int _currentPage = 0;
  static const int _pageSize = 4;

  @override
  void initState() {
    super.initState();

    if (_room == null) return;

    _listener = _room!.createListener();
    _setupListeners();
    _updateParticipants();

    final local = _room!.localParticipant;
    if (local != null) {
      _isMicMuted = !local.isMicrophoneEnabled();
      _isCameraOff = !local.isCameraEnabled();
    }
  }

  void _setupListeners() {
    _listener!
      ..on<ParticipantConnectedEvent>((_) => _updateParticipants())
      ..on<ParticipantDisconnectedEvent>((_) => _updateParticipants())
      ..on<TrackMutedEvent>((_) => _updateParticipants())
      ..on<TrackUnmutedEvent>((_) => _updateParticipants())
      ..on<TrackSubscribedEvent>((_) => _updateParticipants())
      ..on<TrackUnsubscribedEvent>((_) => _updateParticipants())
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted) Navigator.pop(context);
      });
  }

  void _updateParticipants() {
    if (!mounted || _room == null) return;

    setState(() {
      _participants
        ..clear()
        ..addAll(_room!.remoteParticipants.values);

      if (_room!.localParticipant != null) {
        _participants.insert(0, _room!.localParticipant!);
      }

      final maxPage = max(0, (_participants.length - 1) ~/ _pageSize);
      if (_currentPage > maxPage) _currentPage = maxPage;
    });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micProcessing) return;
    _micProcessing = true;

    try {
      final local = _room?.localParticipant;
      if (local == null) return;

      final enable = _isMicMuted;
      await local.setMicrophoneEnabled(enable);
      if (mounted) setState(() => _isMicMuted = !enable);
    } finally {
      _micProcessing = false;
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.callType == 'audio' || _cameraProcessing) return;
    _cameraProcessing = true;

    try {
      final local = _room?.localParticipant;
      if (local == null) return;

      final enable = _isCameraOff;
      await local.setCameraEnabled(enable);
      if (mounted) setState(() => _isCameraOff = !enable);
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildPaginatedGrid()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${widget.callType.toUpperCase()} CALL',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Row(
            children: [
              Text(
                _participants.length.toString(),
                style: const TextStyle(color: Colors.white70),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _hangUp,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedGrid() {
    if (_participants.isEmpty) return _waitingView();

    final start = _currentPage * _pageSize;
    final end = min(start + _pageSize, _participants.length);
    final visible = _participants.sublist(start, end);

    final totalPages = (_participants.length / _pageSize).ceil();

    return Stack(
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: visible.length <= 2 ? 1 : 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (_, i) => ParticipantTile(participant: visible[i]),
        ),

        if (_currentPage > 0)
          _nav(Icons.arrow_back_ios, () {
            setState(() => _currentPage--);
          }, left: true),

        if (_currentPage < totalPages - 1)
          _nav(Icons.arrow_forward_ios, () {
            setState(() => _currentPage++);
          }),
      ],
    );
  }

  Widget _nav(IconData icon, VoidCallback onTap, {bool left = false}) {
    return Positioned(
      left: left ? 10 : null,
      right: left ? null : 10,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _waitingView() {
    return const Center(
      child: Text(
        'Waiting for participants...',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      height: 90,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _control(
            _isMicMuted ? Icons.mic_off : Icons.mic,
            _toggleMic,
            _isMicMuted,
          ),
          if (widget.callType == 'video')
            _control(
              _isCameraOff ? Icons.videocam_off : Icons.videocam,
              _toggleCamera,
              _isCameraOff,
            ),
          _control(Icons.call_end, _hangUp, true, red: true),
        ],
      ),
    );
  }

  Widget _control(
    IconData icon,
    VoidCallback onTap,
    bool active, {
    bool red = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          radius: 26,
          backgroundColor: red
              ? Colors.red
              : active
              ? Colors.red
              : Colors.white,
          child: Icon(icon, color: red || active ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

class ParticipantTile extends StatelessWidget {
  final Participant participant;

  const ParticipantTile({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    VideoTrack? videoTrack;

    for (final pub in participant.videoTrackPublications) {
      if (pub.track != null && pub.track is VideoTrack) {
        videoTrack = pub.track as VideoTrack;
        break;
      }
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null)
            VideoTrackRenderer(videoTrack)
          else
            Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey[800],
                child: Text(
                  participant.identity.isNotEmpty
                      ? participant.identity[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),

          Positioned(
            left: 8,
            bottom: 8,
            child: Row(
              children: [
                Icon(
                  participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                  size: 14,
                  color: participant.isMicrophoneEnabled()
                      ? Colors.white
                      : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  participant.identity,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

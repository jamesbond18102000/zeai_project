import 'package:flutter/material.dart';
import '../services/livekit_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String receiverId;
  final String roomId;
  final bool isVideo;
  final String serverUrl;
  final String userId;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.receiverId,
    required this.roomId,
    required this.isVideo,
    required this.serverUrl,
    required this.userId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _isConnecting = false;

  Future<void> _acceptCall() async {
    setState(() => _isConnecting = true);

    try {
      final lk = LiveKitService.instance;
      await lk.connectToRoom(
        roomName: widget.roomId,
        userName: widget.userId,
        isVideo: widget.isVideo,
        serverUrl: widget.serverUrl,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CallScreen(callType: widget.isVideo ? "video" : "audio"),
        ),
      );
    } catch (e) {
      debugPrint('❌ Accept call failed: $e');
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Video popup
    if (widget.isVideo) {
      return WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Row(
            children: const [
              Icon(Icons.video_call, color: Colors.deepPurple),
              SizedBox(width: 10),
              Text('Video Call'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.callerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "ID: ${widget.callerId}",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              if (_isConnecting) const CircularProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Decline', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: _isConnecting ? null : _acceptCall,
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    }

    // Audio popup (compact) — NO video controls shown
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: const [
            Icon(Icons.phone, color: Colors.green),
            SizedBox(width: 10),
            Text('Audio Call'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.callerName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              "ID: ${widget.callerId}",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_isConnecting) const CircularProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: _isConnecting ? null : _acceptCall,
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

// lib/incoming_call_popup.dart
import 'package:flutter/material.dart';

// ✅ LIVEKIT COMPATIBLE: This UI component works perfectly with the new system.
class IncomingCallPopup extends StatelessWidget {
  final String callerId;
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallPopup({
    super.key,
    required this.callerId,
    required this.isVideo,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900], // 🔥 UPDATED: Dark Background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 🔥 UPDATED: Rounded Corners
      ),
      title: const Text(
        'Incoming Call',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo ? Icons.videocam : Icons.call,
              size: 48,
              color: Colors.deepPurpleAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$callerId is calling...',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        // Reject Button
        TextButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.call_end, color: Colors.red),
          label: const Text('Reject', style: TextStyle(color: Colors.red)),
        ),

        // Accept Button
        ElevatedButton.icon(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          icon: const Icon(Icons.call),
          label: const Text('Accept'),
        ),
      ],
    );
  }
}

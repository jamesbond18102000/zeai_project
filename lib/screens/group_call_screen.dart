import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'dart:math'; // For Random ID
import '../services/livekit_service.dart';
import 'call_screen.dart'; // Unga Call Screen import
import '../sidebar.dart';

class GroupCallScreen extends StatefulWidget {
  final String userId;
  const GroupCallScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  String _generatedRoomId = "";
  bool _isBusy = false;

  // --- 1. Generate Random Meeting ID ---
  void _generateMeetingId() {
    var r = Random();
    String newId = "TEAM-${1000 + r.nextInt(9000)}";
    setState(() {
      _generatedRoomId = newId;
      _roomIdController.text = newId;
    });
  }

  // --- 2. Join Meeting Logic ---
  Future<void> _joinMeeting() async {
    String roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      _showSnack("Please enter a valid Room ID", isError: true);
      return;
    }

    setState(() => _isBusy = true);
    
    try {
      await LiveKitService.instance.connectToRoom(
        roomName: roomId,
        userName: widget.userId,
        isVideo: true,
      );

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CallScreen(callType: "video"),
        ),
      );
    } catch (e) {
      _showSnack("Connection Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    // Matching the Deep Purple theme from your LeaveApprovalPage
    final primaryColor = Colors.deepPurple;
    // --- USING SIDEBAR WRAPPER (Like LeaveApprovalPage) ---
    return Sidebar(
      title: "Group Conference",
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- Header Illustration ---
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.groups_rounded, size: 80, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              "Connect with your Team",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Create a new meeting link or join an existing one.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 40),
            // --- CARD 1: CREATE NEW ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                children: [
                  if (_generatedRoomId.isEmpty) ...[
                    const Text(
                      "Start a New Meeting", 
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateMeetingId,
                        icon: const Icon(Icons.add_link),
                        label: const Text("Generate Meeting ID"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Show generated ID
                    const Text("Share this ID:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _generatedRoomId,
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 1.5
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.grey),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generatedRoomId));
                              _showSnack("Meeting ID Copied!");
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _joinMeeting,
                        icon: const Icon(Icons.video_call),
                        label: const Text("Join This Meeting Now"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("OR", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ]),
            const SizedBox(height: 30),
            // --- CARD 2: JOIN EXISTING ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Join with ID", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _roomIdController,
              decoration: InputDecoration(
                hintText: "Enter Room ID (e.g. TEAM-1234)",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.keyboard, color: primaryColor),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              ),
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBusy ? null : _joinMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                  ),
                ),
                child: _isBusy
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth:2) )
           : const Text("Join Meeting", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
       ),
     ),
   ],
 ),

),
);
}
}
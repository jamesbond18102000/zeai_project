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

  // Only for the CREATOR to decide
  bool _isVideoCall = true;

  // --- 1. Generate Meeting Link with Mode ---
  void _generateMeetingId() {
    var r = Random();
    String randomId = "HRM-PROJECT-${1000 + r.nextInt(9000)}";

    // DECIDE MODE HERE: Encode into URL
    String mode = _isVideoCall ? 'video' : 'audio';
    String newLink = "https://teams.hrm.com/meet/$randomId?mode=$mode";

    setState(() {
      _generatedRoomId = newLink;
      _roomIdController.text = newLink;
    });
  }

  // --- 2. Join Meeting Logic (Auto-detect Mode) ---
  Future<void> _joinMeeting() async {
    String input = _roomIdController.text.trim();
    if (input.isEmpty) {
      _showSnack("Please enter a valid Link or ID", isError: true);
      return;
    }

    String roomIdToJoin = input;
    bool joinAsVideo = true; // Default fallback

    // LOGIC: Parse URL to find ID and Mode
    if (input.contains("/meet/")) {
      try {
        Uri uri = Uri.parse(input);
        // Extract ID from path (e.g., /meet/HRM-PROJECT-1234)
        if (uri.pathSegments.isNotEmpty) {
          roomIdToJoin = uri.pathSegments.last;
        }

        // Extract Mode from Query Param (e.g., ?mode=audio)
        String? modeParam = uri.queryParameters['mode'];
        if (modeParam != null) {
          if (modeParam == 'audio') joinAsVideo = false;
          if (modeParam == 'video') joinAsVideo = true;
        }
      } catch (e) {
        print("Error parsing URL: $e");
        // Fallback: simple split if Uri.parse fails
        roomIdToJoin = input.split("/meet/").last.split("?").first;
      }
    } else {
      // If just ID is entered, assume Video (or you can ask, but requirements say don't ask joiner)
      roomIdToJoin = input;
    }

    setState(() => _isBusy = true);

    try {
      await LiveKitService.instance.connectToRoom(
        roomName: roomIdToJoin,
        userName: widget.userId,
        isVideo: joinAsVideo, // FORCE mode from link
      );

      if (!mounted) return;

      // Navigate to CallScreen with forced mode
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(callType: joinAsVideo ? "video" : "audio"),
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
    final primaryColor = Colors.deepPurple;

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

            // --- CARD 1: CREATE NEW (Creator Options) ---
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
                  ),
                ],
              ),
              child: Column(
                children: [
                  // --- Meeting Type Toggle (Only for Generator) ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Meeting Mode",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Text(
                              "Audio",
                              style: TextStyle(
                                color: !_isVideoCall
                                    ? primaryColor
                                    : Colors.grey,
                                fontWeight: !_isVideoCall
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Switch(
                              value: _isVideoCall,
                              activeColor: primaryColor,
                              onChanged: (val) {
                                setState(() => _isVideoCall = val);
                              },
                            ),
                            Text(
                              "Video",
                              style: TextStyle(
                                color: _isVideoCall
                                    ? primaryColor
                                    : Colors.grey,
                                fontWeight: _isVideoCall
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_generatedRoomId.isEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateMeetingId,
                        icon: const Icon(Icons.add_link),
                        label: const Text("Generate Meeting Link"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Show generated ID
                    const Text(
                      "Share this Link:",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _generatedRoomId,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.grey),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _generatedRoomId),
                              );
                              _showSnack("Link Copied!");
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
                        icon: Icon(_isVideoCall ? Icons.video_call : Icons.mic),
                        label: Text(
                          "Join Now (${_isVideoCall ? 'Video' : 'Audio'})",
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "OR",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 30),

            // --- CARD 2: JOIN EXISTING (No Options, Just Link) ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Join with Link",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _roomIdController,
              decoration: InputDecoration(
                hintText: "Paste meeting link here...",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.link, color: primaryColor),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 20,
                ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Join Meeting",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

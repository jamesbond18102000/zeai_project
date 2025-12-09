// lib/screens/employee_directory.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'main.dart'; // ✅ Import main.dart to access constants
import 'sidebar.dart';
import 'message.dart';
import 'screens/call_screen.dart';
import 'services/livekit_service.dart';
import 'services/socket_service.dart';

class EmployeeDirectoryPage extends StatefulWidget {
  const EmployeeDirectoryPage({super.key});

  @override
  EmployeeDirectoryPageState createState() => EmployeeDirectoryPageState();
}

class EmployeeDirectoryPageState extends State<EmployeeDirectoryPage> {
  List<dynamic> employees = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String? loggedInEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInEmployeeId = prefs.getString('employeeId');
    });
    await fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/api/employees"), // ✅ Use apiBaseUrl
        //Uri.parse("https://zeai-project.onrender.com/api/employees"),
      );

      if (response.statusCode == 200) {
        setState(() {
          employees = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        debugPrint("Failed to load employees: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching employees: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Employee Directory",
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _searchBox("Search by ID, Name, Position, or Domain..."),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _EmployeeGrid(
                      allEmployees: employees,
                      searchController: _searchController,
                      loggedInEmployeeId: loggedInEmployeeId, // Pass it down
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(String hint) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() {}), // Re-filter on change
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF2D2F41),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ========== EMPLOYEE GRID ==========

class _EmployeeGrid extends StatelessWidget {
  final List<dynamic> allEmployees;
  final TextEditingController searchController;
  final String? loggedInEmployeeId;

  const _EmployeeGrid({
    required this.allEmployees,
    required this.searchController,
    required this.loggedInEmployeeId,
  });

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.toLowerCase();
    final filteredEmployees = allEmployees.where((emp) {
      final name = (emp['employeeName'] ?? '').toLowerCase();
      final id = (emp['employeeId'] ?? '').toLowerCase();
      final position = (emp['position'] ?? '').toLowerCase();
      final domain = (emp['domain'] ?? '').toLowerCase();
      return name.contains(query) ||
          id.contains(query) ||
          position.contains(query) ||
          domain.contains(query);
    }).toList();

    if (filteredEmployees.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty ? "No employees available." : "No results for '$query'",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return GridView.builder(
      itemCount: filteredEmployees.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final emp = filteredEmployees[index];
        final imgPath = emp['employeeImage'];
        final imageUrl =
            (imgPath != null &&
                imgPath.toString().isNotEmpty) // ✅ Use apiBaseUrl
            ? "$apiBaseUrl/$imgPath"
            // ? "https://zeai-project.onrender.com/$imgPath"
            : "";

        return _employeeCard(
          context: context,
          employeeId: emp['employeeId'] ?? "",
          name: emp['employeeName'] ?? "",
          role: emp['position'] ?? "",
          imageUrl: imageUrl,
        );
      },
    );
  }

  // ✅ 5. New function to handle the call action
  void _handleCall(
    BuildContext context,
    String receiverId,
    String receiverName,
    bool isVideo,
  ) async {
    // Fetch the caller's name from SharedPreferences as a fallback
    final prefs = await SharedPreferences.getInstance();
    final callerName = prefs.getString('employeeName');
    final loggedInId = loggedInEmployeeId; // Use local variable for null safety

    if (loggedInId == null) return;

    final roomId = const Uuid().v4();
    AppSocket.instance.callUser(
      toUserId: receiverId,
      fromUserId: loggedInEmployeeId!,
      roomId: roomId,
      isVideo: isVideo,
      callerName: callerName,
    );

    // This check is important. If the socket isn't connected, the call can't be made.
    if (AppSocket.instance.socket.connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Calling $receiverName...")));

      // Connect caller to LiveKit and navigate
      try {
        await LiveKitService.instance.connectToRoom(
          serverUrl: livekitUrl,
          roomName: roomId,
          userName: loggedInId,
          isVideo: isVideo,
        );
        // Navigate on success
        Navigator.push(
          context,
          MaterialPageRoute(
            // ✅ FIX: Pass the correct callType to the CallScreen
            builder: (_) => CallScreen(callType: isVideo ? "video" : "audio"),
          ),
        );
      } catch (e) {
        debugPrint("❌ Failed to connect caller to LiveKit: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to start call.")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Not connected to server.")),
      );
    }
  }

  Widget _employeeCard({
    required BuildContext context,
    required String employeeId,
    required String name,
    required String role,
    required String imageUrl,
  }) {
    final isSelf = loggedInEmployeeId == employeeId;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : const AssetImage("assets/profile.png") as ImageProvider,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              role,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.message,
                    size: 25,
                    color: Colors.deepPurple,
                  ),
                  onPressed: isSelf
                      ? () {
                          // Allow messaging self for testing notifications
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MsgPage(employeeId: employeeId),
                            ),
                          );
                        }
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MsgPage(employeeId: employeeId),
                          ),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, size: 25, color: Colors.green),
                  onPressed: isSelf
                      ? null // Disable calling self
                      : () => _handleCall(
                          context,
                          employeeId,
                          name,
                          false,
                        ), // Pass context, ID, and isVideo
                ),
                IconButton(
                  icon: const Icon(
                    Icons.video_call,
                    size: 28,
                    color: Colors.red,
                  ),
                  onPressed: isSelf
                      ? null // Disable calling self
                      : () => _handleCall(
                          context,
                          employeeId,
                          name,
                          true,
                        ), // Pass context, ID, and isVideo
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

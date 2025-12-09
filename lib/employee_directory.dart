<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'dart:convert';
import 'sidebar.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'message.dart';
import 'audio_call_page.dart';
=======
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
>>>>>>> fcd92e1 (l)

class EmployeeDirectoryPage extends StatefulWidget {
  const EmployeeDirectoryPage({super.key});

  @override
  EmployeeDirectoryPageState createState() => EmployeeDirectoryPageState();
}

class EmployeeDirectoryPageState extends State<EmployeeDirectoryPage> {
  List<dynamic> employees = [];
  bool _isLoading = true;
<<<<<<< HEAD
  final TextEditingController _searchController = TextEditingController();
=======

  final TextEditingController _searchController = TextEditingController();
  String? loggedInEmployeeId;
>>>>>>> fcd92e1 (l)

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    fetchEmployees();
=======
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInEmployeeId = prefs.getString('employeeId');
    });
    await fetchEmployees();
>>>>>>> fcd92e1 (l)
  }

  Future<void> fetchEmployees() async {
    try {
      final response = await http.get(
<<<<<<< HEAD
        Uri.parse("https://zeai-project.onrender.com/api/employees"),
=======
        // Uri.parse("$apiBaseUrl/api/employees"), // ✅ Use apiBaseUrl
        Uri.parse(
          "https://zeai-project.onrender.com/api/employees",
        ), // ✅ Use apiBaseUrl
>>>>>>> fcd92e1 (l)
      );

      if (response.statusCode == 200) {
        setState(() {
          employees = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
<<<<<<< HEAD
        debugPrint("❌ Failed to load employees: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching employees: $e");
=======
        debugPrint("Failed to load employees: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching employees: $e");
>>>>>>> fcd92e1 (l)
      setState(() => _isLoading = false);
    }
  }

  @override
<<<<<<< HEAD
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Employee Directory',
=======
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Employee Directory",
>>>>>>> fcd92e1 (l)
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
<<<<<<< HEAD
            // 🔹 Search + Refresh button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _searchBox(
                    'Search by ID, Name, Position, or Domain...',
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: fetchEmployees, // 🔄 Refresh
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "EmployeeList",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
=======
            _searchBox("Search by ID, Name, Position, or Domain..."),
>>>>>>> fcd92e1 (l)
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _EmployeeGrid(
                      allEmployees: employees,
                      searchController: _searchController,
<<<<<<< HEAD
=======
                      loggedInEmployeeId: loggedInEmployeeId, // Pass it down
>>>>>>> fcd92e1 (l)
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(String hint) {
<<<<<<< HEAD
    return SizedBox(
      child: TextField(
        controller: _searchController,
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
=======
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
>>>>>>> fcd92e1 (l)
        ),
      ),
    );
  }
}

<<<<<<< HEAD
class _EmployeeGrid extends StatefulWidget {
  final List<dynamic> allEmployees;
  final TextEditingController searchController;
=======
// ========== EMPLOYEE GRID ==========

class _EmployeeGrid extends StatelessWidget {
  final List<dynamic> allEmployees;
  final TextEditingController searchController;
  final String? loggedInEmployeeId;
>>>>>>> fcd92e1 (l)

  const _EmployeeGrid({
    required this.allEmployees,
    required this.searchController,
<<<<<<< HEAD
  });

  @override
  State<_EmployeeGrid> createState() => _EmployeeGridState();
}

class _EmployeeGridState extends State<_EmployeeGrid> {
  List<dynamic> _filteredEmployees = [];

  @override
  void initState() {
    super.initState();
    _filteredEmployees = List.from(widget.allEmployees);
    widget.searchController.addListener(_filterEmployees);
  }

  @override
  void didUpdateWidget(covariant _EmployeeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allEmployees != oldWidget.allEmployees) {
      _filterEmployees();
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filterEmployees);
    super.dispose();
  }

  void _filterEmployees() {
    final query = widget.searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = List.from(widget.allEmployees);
      } else {
        _filteredEmployees = widget.allEmployees.where((emp) {
          final name = (emp['employeeName'] ?? '').toLowerCase();
          final id = (emp['employeeId'] ?? '').toLowerCase();
          final position = (emp['position'] ?? '').toLowerCase();
          final domain = (emp['domain'] ?? '').toLowerCase();
          return name.contains(query) ||
              id.contains(query) ||
              position.contains(query) ||
              domain.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredEmployees.isEmpty) {
      return Center(
        child: Text(
          widget.searchController.text.trim().isEmpty
              ? 'No employees available.'
              : 'No results for "${widget.searchController.text.trim()}"',
=======
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
>>>>>>> fcd92e1 (l)
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return GridView.builder(
<<<<<<< HEAD
      itemCount: _filteredEmployees.length,
=======
      itemCount: filteredEmployees.length,
>>>>>>> fcd92e1 (l)
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
<<<<<<< HEAD
        final emp = _filteredEmployees[index];
        final imagePath = emp['employeeImage'];
        final imageUrl = (imagePath != null && imagePath.isNotEmpty)
            ? "https://zeai-project.onrender.com$imagePath"
            : "";
        return _employeeCard(
          emp['employeeId'] ?? "",
          emp['employeeName'] ?? "Unknown",
          emp['position'] ?? "Unknown",
          imageUrl,
=======
        final emp = filteredEmployees[index];
        final imgPath = emp['employeeImage'];
        final imageUrl =
            (imgPath != null &&
                imgPath.toString().isNotEmpty) // ✅ Use apiBaseUrl
            //? "$apiBaseUrl/$imgPath"
            ? "https://zeai-project.onrender.com/$imgPath"
            : "";

        return _employeeCard(
          context: context,
          employeeId: emp['employeeId'] ?? "",
          name: emp['employeeName'] ?? "",
          role: emp['position'] ?? "",
          imageUrl: imageUrl,
>>>>>>> fcd92e1 (l)
        );
      },
    );
  }

<<<<<<< HEAD
  Widget _employeeCard(
    String employeeId,
    String name,
    String role,
    String imageUrl,
  ) {
=======
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

>>>>>>> fcd92e1 (l)
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
<<<<<<< HEAD
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 80,
              backgroundColor: Colors.grey[200],
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : const AssetImage("assets/profile.png") as ImageProvider,
              // onBackgroundImageError: (, _) {
              onBackgroundImageError: (error, stackTrace) {
                debugPrint('Image load error for $imageUrl');
              },
=======
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : const AssetImage("assets/profile.png") as ImageProvider,
>>>>>>> fcd92e1 (l)
            ),
            const SizedBox(height: 8),
            Text(
              name,
<<<<<<< HEAD
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              role,
              style: const TextStyle(fontSize: 15.5, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const Spacer(),

            // ✅ Audio + Video Call Integration
=======
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              role,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const Spacer(),
>>>>>>> fcd92e1 (l)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
<<<<<<< HEAD
                  icon: Icon(
                    Icons.email,
                    size: 25,
                    color: Colors.deepPurple.withOpacity(0.5),
                  ),
                  onPressed: null,
                ),
                IconButton(
=======
>>>>>>> fcd92e1 (l)
                  icon: const Icon(
                    Icons.message,
                    size: 25,
                    color: Colors.deepPurple,
                  ),
<<<<<<< HEAD
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MsgPage(employeeId: employeeId),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.phone,
                    size: 25,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    final currentUserId = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).employeeId!;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AudioCallPage(
                          currentUserId: currentUserId,
                          targetUserId: employeeId,
                          isCaller: true,
                          isVideo: false,
                        ),
                      ),
                    );
                  },
=======
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
>>>>>>> fcd92e1 (l)
                ),
                IconButton(
                  icon: const Icon(
                    Icons.video_call,
<<<<<<< HEAD
                    size: 25,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    final currentUserId = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).employeeId!;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AudioCallPage(
                          currentUserId: currentUserId,
                          targetUserId: employeeId,
                          isCaller: true,
                          isVideo: true,
                        ),
                      ),
                    );
                  },
=======
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
>>>>>>> fcd92e1 (l)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'employee_dashboard.dart';
import 'admin_dashboard.dart';
import 'superadmin_dashboard.dart';
import 'apply_leave.dart';
import 'leave_approval.dart';
import 'emp_payroll.dart';
import 'attendance_login.dart';
import 'admin_notification.dart';
import 'employeenotification.dart';
import 'login.dart';
import 'company_events.dart';
import 'attendance_status.dart';
import 'leave_list.dart';
import 'user_provider.dart';
import 'file_picker.dart';

void main() {
=======
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import 'employee_dashboard.dart';
// import 'admin_dashboard.dart';
// import 'superadmin_dashboard.dart';
// import 'apply_leave.dart';
// import 'leave_approval.dart';
// import 'emp_payroll.dart';
// import 'attendance_login.dart';
// import 'admin_notification.dart';
// import 'employeenotification.dart';
// import 'login.dart';
// import 'company_events.dart';
// import 'attendance_status.dart';
// import 'leave_list.dart';
// import 'user_provider.dart';
// import 'file_picker.dart';

// void main() {
//   runApp(
//     MultiProvider(
//       providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Employee HRM',
//       debugShowCheckedModeBanner: false,
//       initialRoute: '/',
//       routes: {
//         '/': (context) => const LoginPage(),
//         '/dashboard': (context) => const EmployeeDashboard(),
//         '/admin_dashboard': (context) => const AdminDashboard(),
//         '/super_admin': (context) => const SuperAdminDashboard(),
//         '/applyLeave': (context) => const ApplyLeave(),
//         '/emp_payroll': (context) => const EmpPayroll(),
//         '/attendance-login': (context) => const AttendanceLoginPage(),
//         '/employeenotification': (context) {
//           final userProvider = Provider.of<UserProvider>(
//             context,
//             listen: false,
//           );
//           final employeeId = userProvider.employeeId ?? '';
//           return EmployeeNotificationsPage(empId: employeeId);
//         },
//         '/admin_notification': (context) {
//           final userProvider = Provider.of<UserProvider>(
//             context,
//             listen: false,
//           );
//           final employeeId = userProvider.employeeId ?? '';
//           return AdminNotificationsPage(empId: employeeId);
//         },
//         '/company_events': (context) => const CompanyEventsScreen(),
//         '/attendance-status': (context) => AttendanceScreen(),
//         '/leave-list': (context) => const LeaveList(),
//         '/leave-approval': (context) =>
//             const LeaveApprovalPage(userRole: "Admin"),
//         '/leave-approval-super': (context) =>
//             const LeaveApprovalPage(userRole: "Founder"),
//         '/upload': (context) => const UploadScreen(),
//       },
//     );
//   }
// }

// /// ✅ UploadScreen for file picker preview
// class UploadScreen extends StatelessWidget {
//   const UploadScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Upload File")),
//       body: const Center(child: UploadWidget()),
//     );
//   }
// }

// /// ✅ Upload Widget button
// class UploadWidget extends StatelessWidget {
//   const UploadWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton.icon(
//       icon: const Icon(Icons.upload_file),
//       label: const Text("Upload File"),
//       onPressed: () async {
//         final file = await FilePickerHelper.pickFile();
//         if (file != null) {
//           debugPrint("Selected: ${file.name}");
//           FilePickerHelper.showFilePreview(context, file.name);
//         }
//       },
//     );
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html; // Web-specific import

import 'user_provider.dart';
import 'app_routes.dart';

// Services
import 'services/livekit_service.dart';
import 'services/socket_service.dart';

// Screens
import 'screens/incoming_call_screen.dart';
import 'login.dart';

const String apiBaseUrl = "https://zeai-project.onrender.com";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web-specific: Prevent scrolling and set viewport constraints
  if (kIsWeb) {
    html.document.documentElement!.style.overflow = 'hidden';
    html.window.onResize.listen((_) {
      html.document.documentElement!.style.overflow = 'hidden';
    });
  }

>>>>>>> fcd92e1 (l)
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const MyApp(),
    ),
  );
}

<<<<<<< HEAD
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
=======
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSocket socketService = AppSocket.instance;
  final LiveKitService livekitService = LiveKitService.instance;

  @override
  void initState() {
    super.initState();

    // Set navigator key for socket service
    livekitService.setNavigatorKey(socketService.navigatorKey);

    // Add listener for incoming calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      socketService.incomingCallNotifier.addListener(_handleIncomingCall);
      debugPrint("🟢 Incoming call listener attached");
    });
  }

  @override
  void dispose() {
    socketService.incomingCallNotifier.removeListener(_handleIncomingCall);
    super.dispose();
  }

  void _handleIncomingCall() {
    final call = socketService.incomingCallNotifier.value;
    if (call == null) return;

    debugPrint(
      "🔔 Incoming call detected: ${call.callerName}, room: ${call.roomId}",
    );
    // Popup handled inside socket_service; this listener can be used for extra UI updates
  }

  @override
>>>>>>> fcd92e1 (l)
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee HRM',
      debugShowCheckedModeBanner: false,
<<<<<<< HEAD
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const EmployeeDashboard(),
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/super_admin': (context) => const SuperAdminDashboard(),
        '/applyLeave': (context) => const ApplyLeave(),
        '/emp_payroll': (context) => const EmpPayroll(),
        '/attendance-login': (context) => const AttendanceLoginPage(),
        '/employeenotification': (context) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final employeeId = userProvider.employeeId ?? '';
          return EmployeeNotificationsPage(empId: employeeId);
        },
        '/admin_notification': (context) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final employeeId = userProvider.employeeId ?? '';
          return AdminNotificationsPage(empId: employeeId);
        },
        '/company_events': (context) => const CompanyEventsScreen(),
        '/attendance-status': (context) => AttendanceScreen(),
        '/leave-list': (context) => const LeaveList(),
        '/leave-approval': (context) =>
            const LeaveApprovalPage(userRole: "Admin"),
        '/leave-approval-super': (context) =>
            const LeaveApprovalPage(userRole: "Founder"),
        '/upload': (context) => const UploadScreen(),
      },
    );
  }
}

/// ✅ UploadScreen for file picker preview
class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload File")),
      body: const Center(child: UploadWidget()),
    );
  }
}

/// ✅ Upload Widget button
class UploadWidget extends StatelessWidget {
  const UploadWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.upload_file),
      label: const Text("Upload File"),
      onPressed: () async {
        final file = await FilePickerHelper.pickFile();
        if (file != null) {
          debugPrint("Selected: ${file.name}");
          FilePickerHelper.showFilePreview(context, file.name);
        }
      },
=======
      navigatorKey: socketService.navigatorKey,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.getRoutes(context),
>>>>>>> fcd92e1 (l)
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'user_provider.dart';
import 'login.dart';
import 'employee_dashboard.dart';
import 'admin_dashboard.dart';
import 'superadmin_dashboard.dart';
import 'apply_leave.dart';
import 'emp_payroll.dart';
import 'attendance_login.dart';
import 'admin_notification.dart';
import 'employeenotification.dart';
import 'company_events.dart';
import 'attendance_status.dart';
import 'leave_list.dart';
import 'leave_approval.dart';
import 'reports.dart';
import 'employee_directory.dart';
import 'employee_profile.dart';

class AppRoutes {
  static const String login = '/';
  static const String dashboard = '/dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String superAdmin = '/super_admin';
  static const String applyLeave = '/applyLeave';
  static const String empPayroll = '/emp_payroll';
  static const String attendanceLogin = '/attendance-login';
  static const String employeeNotification = '/employeenotification';
  static const String adminNotification = '/admin_notification';
  static const String companyEvents = '/company_events';
  static const String attendanceStatus = '/attendance-status';
  static const String leaveList = '/leave-list';
  static const String leaveApproval = '/leave-approval';
  static const String leaveApprovalSuper = '/leave-approval-super';
  static const String reports = '/reports';
  static const String employeeDirectory = '/employee_directory';
  static const String employeeProfile = '/employee_profile';

  static Map<String, WidgetBuilder> getRoutes(BuildContext context) {
    return {
      login: (_) => const LoginPage(),
      dashboard: (_) => const EmployeeDashboard(),
      adminDashboard: (_) => const AdminDashboard(),
      superAdmin: (_) => const SuperAdminDashboard(),
      applyLeave: (_) => const ApplyLeave(),
      empPayroll: (_) => const EmpPayroll(),
      attendanceLogin: (_) => const AttendanceLoginPage(),
      employeeNotification: (context) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final employeeId = userProvider.employeeId ?? '';
        return EmployeeNotificationsPage(empId: employeeId);
      },
      adminNotification: (context) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final employeeId = userProvider.employeeId ?? '';
        return AdminNotificationsPage(empId: employeeId);
      },
      companyEvents: (_) => const CompanyEventsScreen(),
      attendanceStatus: (_) => AttendanceScreen(),
      leaveList: (_) => const LeaveList(),
      leaveApproval: (_) => const LeaveApprovalPage(userRole: "Admin"),
      leaveApprovalSuper: (_) => const LeaveApprovalPage(userRole: "Founder"),
      reports: (_) => ReportsAnalyticsPage(),
      employeeDirectory: (_) => const EmployeeDirectoryPage(),
      employeeProfile: (_) => EmployeeProfilePage(),
    };
  }
}

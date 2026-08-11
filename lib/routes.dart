import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/landing_screen.dart';
import 'screens/web_landing_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/student_login_screen.dart';
import 'screens/student_id_screen.dart';
import 'screens/student_summary_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'screens/admin/sync_center_screen.dart';
import 'screens/admin/manage_admins_screen.dart';
import 'screens/admin/students_list_screen.dart';
import 'screens/admin/attendance_events_screen.dart';
import 'screens/admin/event_attendance_screen.dart';
import 'screens/admin/id_claims_screen.dart';
import 'screens/admin/activity_logs_screen.dart';
import 'screens/admin/financial_dashboard_screen.dart';
import 'screens/admin/student_obligations_list_screen.dart';
import 'screens/admin/org_cashflow_logs_screen.dart';
import 'screens/claim_id_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_conditions_screen.dart';
import 'services/auth_service.dart';

import 'screens/web/web_student_login_screen.dart';
import 'screens/web/web_admin_login_screen.dart';
import 'screens/web/web_registration_screen.dart';
import 'screens/web/web_student_id_screen.dart';
import 'screens/web/web_student_summary_screen.dart';
import 'screens/web/web_admin_dashboard_screen.dart';
import 'screens/web/web_scanner_screen.dart';

import 'widgets/desktop_mobile_wrapper.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = ref.read(authServiceProvider).currentUser != null;
      final isAdminRoute =
          state.uri.path.startsWith('/admin') &&
          state.uri.path != '/admin/login';
      final isScannerRoute = state.uri.path == '/scanner';

      // Protect admin dashboard and scanner — require login
      if ((isAdminRoute || isScannerRoute) && !isLoggedIn) {
        return '/admin/login';
      }

      // Already logged in, redirect away from login
      if (state.uri.path == '/admin/login' && isLoggedIn) {
        return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      // Public routes
      GoRoute(
        path: '/',
        builder: (context, state) => kIsWeb
            ? const DesktopMobileWrapper(child: WebLandingScreen())
            : const LandingScreen(),
      ),
      GoRoute(path: '/app', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => kIsWeb
            ? const DesktopMobileWrapper(child: WebRegistrationScreen())
            : const RegistrationScreen(),
      ),
      GoRoute(
        path: '/student-login',
        builder: (context, state) => kIsWeb
            ? const DesktopMobileWrapper(child: WebStudentLoginScreen())
            : const StudentLoginScreen(),
      ),
      GoRoute(
        path: '/student/id/:studentId',
        builder: (context, state) => kIsWeb
            ? DesktopMobileWrapper(
                child: WebStudentIdScreen(
                  studentId: state.pathParameters['studentId']!,
                ),
              )
            : StudentIdScreen(studentId: state.pathParameters['studentId']!),
      ),
      GoRoute(
        path: '/student/summary/:studentId',
        builder: (context, state) => kIsWeb
            ? DesktopMobileWrapper(
                child: WebStudentSummaryScreen(
                  studentId: state.pathParameters['studentId']!,
                ),
              )
            : StudentSummaryScreen(
                studentId: state.pathParameters['studentId']!,
              ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            StudentDashboardScreen(initialStudentId: state.extra as String?),
      ),
      GoRoute(
        path: '/claim-id',
        builder: (context, state) => const ClaimIdScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms-conditions',
        builder: (context, state) => const TermsConditionsScreen(),
      ),

      // Admin routes (protected)
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => kIsWeb
            ? const DesktopMobileWrapper(child: WebAdminLoginScreen())
            : const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => kIsWeb
            ? const WebAdminDashboardScreen()
            : const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/students',
        builder: (context, state) => const StudentsListScreen(),
      ),
      GoRoute(
        path: '/admin/attendance',
        builder: (context, state) => const AttendanceEventsScreen(),
      ),
      GoRoute(
        path: '/admin/attendance/:eventId',
        builder: (context, state) =>
            EventAttendanceScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/admin/id-claims',
        builder: (context, state) => const IdClaimsScreen(),
      ),
      GoRoute(
        path: '/admin/finances',
        builder: (context, state) => const FinancialDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/finances/obligations',
        builder: (context, state) => const StudentObligationsListScreen(),
      ),
      GoRoute(
        path: '/admin/finances/cashflow',
        builder: (context, state) => const OrgCashflowLogsScreen(),
      ),
      GoRoute(
        path: '/admin/logs',
        builder: (context, state) => const ActivityLogsScreen(),
      ),
      GoRoute(
        path: '/admin/manage_admins',
        builder: (context, state) => const ManageAdminsScreen(),
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (context, state) => const AdminProfileScreen(),
      ),
      GoRoute(
        path: '/admin/sync-center',
        builder: (context, state) => const SyncCenterScreen(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) =>
            kIsWeb ? const WebScannerScreen() : const ScannerScreen(),
      ),
    ],
  );
});

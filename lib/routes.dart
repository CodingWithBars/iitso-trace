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
import 'screens/admin/admin_student_profile_screen.dart';
import 'screens/admin/manage_admins_screen.dart';
import 'screens/admin/students_list_screen.dart';
import 'screens/admin/attendance_events_screen.dart';
import 'screens/admin/event_attendance_screen.dart';
import 'screens/admin/id_claims_screen.dart';
import 'screens/admin/activity_logs_screen.dart';
import 'screens/admin/financial_dashboard_screen.dart';
import 'screens/admin/student_obligations_list_screen.dart';
import 'screens/admin/org_cashflow_logs_screen.dart';
import 'screens/admin/record_manual_payment_screen.dart';
import 'screens/admin/event_form_screen.dart';
import 'models/event.dart';
import 'screens/claim_id_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_conditions_screen.dart';
import 'services/auth_service.dart';

import 'screens/splash_screen.dart';
import 'screens/web/web_student_login_screen.dart';
import 'screens/web/web_admin_login_screen.dart';
import 'screens/web/web_registration_screen.dart';
import 'screens/web/web_student_id_screen.dart';
import 'screens/web/web_student_summary_screen.dart';
import 'screens/web/web_admin_dashboard_screen.dart';
import 'screens/web/web_scanner_screen.dart';

import 'widgets/desktop_mobile_wrapper.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // ── Auth-stream notifier: tells GoRouter to re-run redirect whenever
  //    Firebase auth state changes (login / logout). Without this, the
  //    redirect callback only fires on explicit navigation, so pressing
  //    Android back after logout would re-show the admin dashboard.
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    // On web the HTML splash already shows during Flutter initialisation,
    // so skip the in-app /splash route and go directly to '/'.
    initialLocation: kIsWeb ? '/' : '/splash',
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      // Skip Flutter splash entirely on web
      if (kIsWeb && state.uri.path == '/splash') return '/';
      if (state.uri.path == '/splash') return null;

      // Use the stream value — reactive to signOut()
      final isLoggedIn =
          ref.read(authStateProvider).valueOrNull != null;
      final isAdminRoute =
          state.uri.path.startsWith('/admin') &&
          state.uri.path != '/admin/login';
      final isScannerRoute = state.uri.path == '/scanner';

      // Redirect to login if accessing protected route without auth
      if ((isAdminRoute || isScannerRoute) && !isLoggedIn) {
        return '/admin/login';
      }

      // If logged-in admin somehow lands on /admin/login, redirect to dashboard
      if (state.uri.path == '/admin/login' && isLoggedIn) {
        return '/admin/dashboard';
      }

      // Role-based route guards
      if (isLoggedIn) {
        final currentRole = ref.read(adminRoleProvider).value;
        if (currentRole != null) {
          // Only superadmin can access manage_admins
          if (state.uri.path == '/admin/manage_admins' &&
              currentRole != 'superadmin') {
            return '/admin/dashboard';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        ),
      ),
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
        path: '/admin/students/:studentId',
        builder: (context, state) => AdminStudentProfileScreen(
          studentId: state.pathParameters['studentId']!,
        ),
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
        path: '/admin/finances/record-payment',
        builder: (context, state) => const RecordManualPaymentScreen(),
      ),
      GoRoute(
        path: '/admin/event-form',
        builder: (context, state) => EventFormScreen(
          event: state.extra as Event?,
        ),
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
        path: '/scanner',
        builder: (context, state) {
          final eventId = state.uri.queryParameters['eventId'];
          return kIsWeb
              ? const WebScannerScreen()
              : ScannerScreen(eventId: eventId);
        },
      ),
    ],
  );
});

/// Bridges the Firebase auth stream into a [ChangeNotifier] so GoRouter's
/// [refreshListenable] re-evaluates redirect guards on every auth state change
/// (login / logout), including when the user presses the Android back button.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (_, _) {
      notifyListeners();
    });
  }
}

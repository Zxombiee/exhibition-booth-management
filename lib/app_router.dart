import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/guest_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/event_details_screen.dart';
import 'screens/exhibitor_dashboard.dart';
import 'screens/floor_plan_screen.dart';
import 'screens/application_form_screen.dart';
import 'screens/browse_events_screen.dart';
import 'screens/my_applications_screen.dart';
import 'screens/organizer_dashboard.dart';
import 'screens/create_event_screen.dart';
import 'screens/my_events_screen.dart';
import 'screens/pending_applications_screen.dart';
import 'screens/my_events_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_floor_plan_screen.dart';
import 'screens/manage_exhibitions_screen.dart';
import 'screens/manage_users_screen.dart';
import 'screens/all_reservations_screen.dart';

// ─────────────────────────────────────────────────────────────
// ROUTE NAMES  — use these constants everywhere instead of
// hardcoded strings so typos are caught at compile time
// ─────────────────────────────────────────────────────────────
class AppRoutes {
  // Guest
  static const guest           = '/guest';
  static const eventDetails    = '/guest/event/:exhibitionId';

  // Auth
  static const login           = '/login';
  static const register        = '/register';

  // Exhibitor
  static const exhibitor       = '/exhibitor';
  static const browseEvents    = '/exhibitor/browse';
  static const myApplications  = '/exhibitor/applications';
  static const floorPlan       = '/exhibitor/floor-plan/:exhibitionId';
  static const applyForm       = '/exhibitor/apply/:exhibitionId';

  // Organizer
  static const organizer       = '/organizer';
  static const createEvent     = '/organizer/create-event';
  static const myEvents        = '/organizer/my-events';
  static const pendingApplications = '/organizer/applications';

  // Admin
  static const admin             = '/admin';
  static const manageExhibitions = '/admin/exhibitions';
  static const adminFloorPlan    = '/admin/floor-plan/:exhibitionId';
  static const manageUsers       = '/admin/users';
  static const allReservations   = '/admin/reservations';

  // Helper to build paths with params
  static String eventDetailsPath(String id) => '/guest/event/$id';
  static String floorPlanPath(String id)    => '/exhibitor/floor-plan/$id';
  static String applyFormPath(String id)    => '/exhibitor/apply/$id';
  static String adminFloorPlanPath(String id) => '/admin/floor-plan/$id';
}

// ─────────────────────────────────────────────────────────────
// ROUTER
// ─────────────────────────────────────────────────────────────
final appRouter = GoRouter(
  initialLocation: AppRoutes.guest,
  debugLogDiagnostics: false,

  // ── Redirect logic ─────────────────────────────────────────
  // Called on every navigation — checks auth + role
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.matchedLocation;

    // Auth-required routes
    final protectedPaths = [
      '/exhibitor', '/organizer', '/admin',
    ];
    final isProtected = protectedPaths.any((p) => path.startsWith(p));
    final isAuthScreen = path == AppRoutes.login || path == AppRoutes.register;

    // Not logged in trying to access protected route → go to login
    if (user == null && isProtected) {
      return AppRoutes.login;
    }

    // Already logged in trying to go to login/register → redirect to dashboard
    if (user != null && isAuthScreen) {
      final role = await _getUserRole(user.uid);
      return _dashboardForRole(role);
    }

    // Logged-in user at root guest page → redirect to their dashboard
    if (user != null && path == AppRoutes.guest) {
      final role = await _getUserRole(user.uid);
      return _dashboardForRole(role);
    }

    return null; // no redirect needed
  },

  routes: [
    // ── Guest ─────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.guest,
      builder: (_, __) => const GuestHomeScreen(),
      routes: [
        GoRoute(
          path: 'event/:exhibitionId',
          builder: (_, state) => EventDetailsScreen(
            exhibitionId: state.pathParameters['exhibitionId']!,
          ),
        ),
      ],
    ),

    // ── Auth ──────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, __) => const RegisterScreen(),
    ),

    // ── Exhibitor ─────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.exhibitor,
      builder: (_, __) => const ExhibitorDashboard(),
      routes: [
        GoRoute(
          path: 'browse',
          builder: (_, __) => const BrowseEventsScreen(),
        ),
        GoRoute(
          path: 'applications',
          builder: (_, __) => const MyApplicationsScreen(),
        ),
        GoRoute(
          path: 'floor-plan/:exhibitionId',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return FloorPlanScreen(
              exhibitionId: state.pathParameters['exhibitionId']!,
              exhibitionName: extra?['exhibitionName'] ?? '',
            );
          },
        ),
      ],
    ),

    // ── Organizer ─────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.organizer,
      builder: (_, __) => const OrganizerDashboard(),
      routes: [
        GoRoute(
          path: 'create-event',
          builder: (_, __) => const CreateEventScreen(),
        ),
        GoRoute(
          path: 'my-events',
          builder: (_, __) => const MyEventsScreen(),
        ),
        GoRoute(
          path: 'applications',
          builder: (_, __) => const PendingApplicationsScreen(),
        ),
      ],
    ),

    // ── Admin ─────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.admin,
      builder: (_, __) => const AdminDashboard(),
      routes: [
        GoRoute(
          path: 'exhibitions',
          builder: (_, __) => const ManageExhibitionsScreen(),
        ),
        GoRoute(
          path: 'floor-plan/:exhibitionId',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return AdminFloorPlanScreen(
              exhibitionId: state.pathParameters['exhibitionId']!,
              exhibitionName: extra?['exhibitionName'] ?? '',
            );
          },
        ),
        GoRoute(
          path: 'users',
          builder: (_, __) => const ManageUsersScreen(),
        ),
        GoRoute(
          path: 'reservations',
          builder: (_, __) => const AllReservationsScreen(),
        ),
      ],
    ),
  ],

  // ── Error page ────────────────────────────────────────────
  errorBuilder: (_, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Page not found: ${state.error}',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => GoRouter.of(state.error!.toString() as BuildContext)
                .go(AppRoutes.guest),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
Future<String> _getUserRole(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    return doc.data()?['role'] as String? ?? 'exhibitor';
  } catch (_) {
    return 'exhibitor';
  }
}

String _dashboardForRole(String role) {
  switch (role) {
    case 'admin':     return AppRoutes.admin;
    case 'organizer': return AppRoutes.organizer;
    default:          return AppRoutes.exhibitor;
  }
}
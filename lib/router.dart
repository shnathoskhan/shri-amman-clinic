// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin/branch_management_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/branch_picker_screen.dart';
import 'screens/refer_screen.dart';
import 'screens/tests_screen.dart';

CustomTransitionPage<void> _fadePage(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: fade,
          child: child,
        );
      },
    );

// Define the GoRouter instance
final GoRouter goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _fadePage(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          _fadePage(state, const DashboardScreen()),
    ),
    GoRoute(
      path: '/patients',
      pageBuilder: (context, state) => _fadePage(state, const PatientsScreen()),
    ),
    GoRoute(
      path: '/reports',
      pageBuilder: (context, state) => _fadePage(state, const ReportsScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _fadePage(state, const SettingsScreen()),
    ),
    // Refer management
    GoRoute(
      path: '/refer',
      pageBuilder: (context, state) => _fadePage(state, const ReferScreen()),
    ),
    // Test management (departments, sample types, parameters, profiles)
    GoRoute(
      path: '/tests',
      pageBuilder: (context, state) => _fadePage(state, const TestsScreen()),
    ),
    // Admin‑only branch management
    GoRoute(
      path: '/branches',
      pageBuilder: (context, state) =>
          _fadePage(state, const BranchManagementScreen()),
    ),
    GoRoute(
      path: '/users',
      pageBuilder: (context, state) =>
          _fadePage(state, const UserManagementScreen()),
    ),
    // Branch picker for dashboard side tab
    GoRoute(
      path: '/selectbranches',
      pageBuilder: (context, state) =>
          _fadePage(state, const BranchPickerScreen()),
    ),
  ],
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final loggingIn = state.location == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    return null;
  },
);

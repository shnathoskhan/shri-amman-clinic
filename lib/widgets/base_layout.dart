// lib/widgets/base_layout.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shri_amman_clinic/theme.dart';
import 'package:intl/intl.dart';

class BaseLayout extends StatefulWidget {
  final String title;
  final Widget child;
  final Widget? floatingActionButton;

  const BaseLayout({
    Key? key,
    required this.title,
    required this.child,
    this.floatingActionButton,
  }) : super(key: key);

  @override
  _BaseLayoutState createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
  bool _isRailExtended = true;
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _selectedIndexFromLocation(String location) {
    switch (location) {
      case '/dashboard':
        return 0;
      case '/patients':
        return 1;
      case '/reports':
        return 2;
      case '/tests':
        return 3;
      case '/branches':
        return 4;
      case '/users':
        return 5;
      case '/refer':
        return 6;
      case '/settings':
        return 7;
      default:
        return 0;
    }
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/patients');
        break;
      case 2:
        context.go('/reports');
        break;
      case 3:
        context.go('/tests');
        break;
      case 4:
        context.go('/branches');
        break;
      case 5:
        context.go('/users');
        break;
      case 6:
        context.go('/refer');
        break;
      case 7:
        context.go('/settings');
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final selectedIndex =
        _selectedIndexFromLocation(GoRouterState.of(context).location);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.onPrimary,
        shadowColor: Colors.grey,
        elevation: 1,
        // Updated AppBar title Row with dynamic branch name and user name (clock moved to bottom bar)
        title: Text(
          'SHRI AMMAN CLINIC',
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          Row(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final branchId = userData['branch'] as String? ?? '';
                    final userName = userData['name'] ?? '';
                    return Row(
                      children: [
                        if (branchId.isNotEmpty)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('branches')
                                .doc(branchId)
                                .snapshots(),
                            builder: (context, branchSnapshot) {
                              if (branchSnapshot.hasData &&
                                  branchSnapshot.data!.exists) {
                                final branchData = branchSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                final branchName = branchData['name'] ?? '';
                                return Text(
                                  'Branch: $branchName',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        const SizedBox(width: 32),
                        // User name
                        Text(userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(width: 8),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle Theme',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          const SizedBox(
            width: 8,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      // Navigation Rail (Material 3) always visible, collapsible via leading icon
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Theme.of(context).colorScheme.onPrimary,
            extended: _isRailExtended,
            useIndicator: true,
            indicatorColor: Theme.of(context).colorScheme.primary,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(
                  icon: Icon(Icons.people), label: Text('Patients')),
              NavigationRailDestination(
                  icon: Icon(Icons.insert_chart), label: Text('Reports')),
              NavigationRailDestination(
                  icon: Icon(Icons.biotech_outlined), label: Text('Tests')),
              NavigationRailDestination(
                  icon: Icon(Icons.business), label: Text('Branches')),
              NavigationRailDestination(
                  icon: Icon(Icons.group), label: Text('Users')),
              NavigationRailDestination(
                  icon: Icon(Icons.redeem), label: Text('Refer')),
              NavigationRailDestination(
                  icon: Icon(Icons.settings), label: Text('Settings')),
            ],
            trailingAtBottom: true,
            trailing: IconButton(
              icon: Icon(_isRailExtended ? Icons.arrow_back : Icons.menu),
              onPressed: () {
                setState(() {
                  _isRailExtended = !_isRailExtended;
                });
              },
            ),
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _navigateTo(context, index),
            unselectedLabelTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
            ),
            selectedLabelTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            selectedIconTheme: const IconThemeData(
              color: Colors.white,
            ),
            unselectedIconTheme: IconThemeData(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const VerticalDivider(thickness: 0.2, width: 0.2),
          Expanded(child: widget.child),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shadowColor: Colors.grey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('© 2026 Shri Amman Clinic'),
              Text(DateFormat('EEEE, d MMMM y, hh:mm:ss a').format(_now)),
            ],
          ),
        ),
      ),
    );
  }
}

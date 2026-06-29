// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shri_amman_clinic/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SHRI AMMAN CLINIC & LAB',
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
                        Text(userName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 254,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Enter Dashboard'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('© 2026 Shri Amman Clinic & Lab'),
                  const SizedBox(width: 16),
                  Text(DateFormat('EEEE, d MMMM y, hh:mm:ss a')
                      .format(DateTime.now())),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

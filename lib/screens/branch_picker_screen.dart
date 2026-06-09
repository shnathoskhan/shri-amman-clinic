// lib/screens/branch_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BranchPickerScreen extends StatelessWidget {
  const BranchPickerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final existingBranch = data?['branch'] as String?;
        if (existingBranch != null && existingBranch.isNotEmpty) {
          // User already has a branch; navigate to dashboard
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/dashboard');
          });
          return const Scaffold();
        }
        // Show branch picker UI
        return Scaffold(
          appBar: AppBar(
            title: const Text('Select Branch'),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('branches').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No branches found.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unnamed';
                  final address = data['address'] ?? '';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(name,
                          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500)),
                      subtitle: address.isNotEmpty ? Text(address) : null,
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () async {
                        // Update branch only if not set
                        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                        final userSnap = await userRef.get();
                        final existing = userSnap.data()?['branch'];
                        if (existing == null || (existing as String).isEmpty) {
                          await userRef.update({'branch': docs[index].id});
                        }
                        context.go('/dashboard');
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

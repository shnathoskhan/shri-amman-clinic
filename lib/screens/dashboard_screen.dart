// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const BaseLayout(
      title: 'Dashboard',
      child: Center(child: Text('Dashboard Overview')),
    );
  }
}

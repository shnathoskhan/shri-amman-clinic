// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const BaseLayout(
      title: 'Reports',
      child: Center(child: Text('Reports goes here')),
    );
  }
}

// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const BaseLayout(
      title: 'Settings',
      child: Center(child: Text('Settings goes here')),
    );
  }
}

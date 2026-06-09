// lib/screens/patients_screen.dart
import 'package:flutter/material.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const BaseLayout(
      title: 'Patients',
      child: Center(child: Text('Patients list goes here')),
    );
  }
}

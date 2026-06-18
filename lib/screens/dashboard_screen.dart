// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Time range options
  final List<String> _ranges = [
    '7 Days',
    '1 Month',
    '3 Months',
    '6 Months',
    '1 Year'
  ];
  String _selectedRange = '7 Days';

  // Summary counts (placeholder defaults)
  int totalPatients = 0;
  int totalReports = 0;
  int totalDoctors = 0;
  int totalHospitals = 0;
  int totalLabs = 0;
  int totalDepartments = 0;
  int totalAppointments = 0;

  // Chart data (mock random data)
  List<FlSpot> _chartSpots = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadChartData();
  }

  Future<void> _loadSummary() async {
    // Fetch counts from Firestore collections – replace with actual collection names
    final patients =
        await FirebaseFirestore.instance.collection('patients').get();
    final reports =
        await FirebaseFirestore.instance.collection('reports').get();
    final doctors =
        await FirebaseFirestore.instance.collection('doctors').get();
    final hospitals =
        await FirebaseFirestore.instance.collection('hospitals').get();
    final labs = await FirebaseFirestore.instance.collection('labs').get();
    final departments =
        await FirebaseFirestore.instance.collection('departments').get();
    final appointments =
        await FirebaseFirestore.instance.collection('appointments').get();
    setState(() {
      totalPatients = patients.size;
      totalReports = reports.size;
      totalDoctors = doctors.size;
      totalHospitals = hospitals.size;
      totalLabs = labs.size;
      totalDepartments = departments.size;
      totalAppointments = appointments.size;
    });
  }

  void _loadChartData() {
    // Generate mock data points based on selected range – in a real app, query Firestore analytics
    final now = DateTime.now();
    final days = {
          '7 Days': 7,
          '1 Month': 30,
          '3 Months': 90,
          '6 Months': 180,
          '1 Year': 365,
        }[_selectedRange] ??
        7;
    final rand = List.generate(days,
        (i) => FlSpot(i.toDouble(), (i * 5 + 20 + (i % 3) * 10).toDouble()));
    setState(() {
      _chartSpots = rand;
    });
  }

  Widget _buildCard(String title, int count, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Colors.white70),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(NumberFormat.decimalPattern().format(count),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Patients Over Time',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: _selectedRange,
                  items: _ranges
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedRange = v);
                      _loadChartData();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _chartSpots,
                      isCurved: true,
                      color: Colors.deepPurpleAccent,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 28)),
                    bottomTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Dashboard',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildCard('Total Patients', totalPatients, Icons.people,
                    Colors.indigo),
                _buildCard('Total Reports', totalReports, Icons.insert_chart,
                    Colors.teal),
                _buildCard('Total Doctors', totalDoctors,
                    Icons.medical_services, Colors.deepOrange),
                _buildCard('Total Hospitals', totalHospitals,
                    Icons.local_hospital, Colors.green),
                _buildCard('Total Labs', totalLabs, Icons.biotech_outlined,
                    Colors.purple),
                _buildCard('Total Departments', totalDepartments,
                    Icons.business, Colors.brown),
                _buildCard('Total Appointments', totalAppointments,
                    Icons.calendar_today, Colors.cyan),
                _buildCard('Total Staff', totalDoctors + totalDepartments,
                    Icons.group, Colors.amber),
              ],
            ),
            const SizedBox(height: 24),
            _buildChart(),
            const SizedBox(height: 24),
            // Additional chart for reports could be added similarly
          ],
        ),
      ),
    );
  }
}

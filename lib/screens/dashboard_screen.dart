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
  // ─── Palette ────────────────────────────────────────────────────────────────
  static const _purple = Color(0xFF534AB7);
  static const _purpleBg = Color(0xFFEEEDFE);
  static const _teal = Color(0xFF0F6E56);
  static const _tealBg = Color(0xFFE1F5EE);
  static const _coral = Color(0xFF993C1D);
  static const _coralBg = Color(0xFFFAECE7);
  static const _amber = Color(0xFF854F0B);
  static const _amberBg = Color(0xFFFAEEDA);
  static const _green = Color(0xFF3B6D11);
  static const _greenBg = Color(0xFFEAF3DE);
  static const _pink = Color(0xFF993556);
  static const _pinkBg = Color(0xFFFBEAF0);

  // ─── State ──────────────────────────────────────────────────────────────────
  String _selectedDuration = 'Last 30 days';
  final List<String> _durations = [
    'Today',
    'Yesterday',
    'Last 7 days',
    'Last 30 days',
    'Last 90 days',
    'Last 180 days',
    'Last 360 days'
  ];

  List<DocumentSnapshot> _patientDocs = [];
  List<DocumentSnapshot> _reportDocs = [];
  List<DocumentSnapshot> _doctorDocs = [];
  List<DocumentSnapshot> _hospitalDocs = [];
  List<DocumentSnapshot> _labDocs = [];
  List<DocumentSnapshot> _departmentDocs = [];
  List<DocumentSnapshot> _appointmentDocs = [];

  // Computed values
  int patientCount = 0;
  String patientDelta = '';

  int appointmentCount = 0;
  String appointmentDelta = '';

  int doctorCount = 0;
  String doctorDelta = '';

  int reportCount = 0;
  String reportDelta = '';

  int hospitalCount = 0;
  String hospitalDelta = '';

  int labCount = 0;
  String labDelta = '';

  int departmentCount = 0;
  String departmentDelta = '';

  int staffCount = 0;
  String staffDelta = '';

  List<FlSpot> _patientSpots = [];
  List<FlSpot> _reportSpots = [];
  double _chartIntervalY = 1.0;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadChartData();
  }

  // ─── Data loading ───────────────────────────────────────────────────────────
  DateTime? _getDocDate(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final fields = ['createdAt', 'date', 'updatedAt', 'timestamp'];
    for (final field in fields) {
      if (data[field] is Timestamp) {
        return (data[field] as Timestamp).toDate();
      }
    }
    return null;
  }

  (DateTime, DateTime, DateTime, DateTime) _getDateTimeRanges(String duration) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(
        const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

    switch (duration) {
      case 'Today':
        final start = todayStart;
        final end = todayEnd;
        final startPrev = todayStart.subtract(const Duration(days: 1));
        final endPrev = todayEnd.subtract(const Duration(days: 1));
        return (start, end, startPrev, endPrev);

      case 'Yesterday':
        final start = todayStart.subtract(const Duration(days: 1));
        final end = todayEnd.subtract(const Duration(days: 1));
        final startPrev = todayStart.subtract(const Duration(days: 2));
        final endPrev = todayEnd.subtract(const Duration(days: 2));
        return (start, end, startPrev, endPrev);

      case 'Last 7 days':
        final start = todayStart.subtract(const Duration(days: 6));
        final end = todayEnd;
        final startPrev = todayStart.subtract(const Duration(days: 13));
        final endPrev = todayStart.subtract(const Duration(days: 7));
        return (start, end, startPrev, endPrev);

      case 'Last 90 days':
        final start = todayStart.subtract(const Duration(days: 89));
        final end = todayEnd;
        final startPrev = todayStart.subtract(const Duration(days: 179));
        final endPrev = todayStart.subtract(const Duration(days: 90));
        return (start, end, startPrev, endPrev);

      case 'Last 180 days':
        final start = todayStart.subtract(const Duration(days: 179));
        final end = todayEnd;
        final startPrev = todayStart.subtract(const Duration(days: 359));
        final endPrev = todayStart.subtract(const Duration(days: 180));
        return (start, end, startPrev, endPrev);

      case 'Last 360 days':
        final start = todayStart.subtract(const Duration(days: 359));
        final end = todayEnd;
        final startPrev = todayStart.subtract(const Duration(days: 719));
        final endPrev = todayStart.subtract(const Duration(days: 360));
        return (start, end, startPrev, endPrev);

      case 'Last 30 days':
      default:
        final start = todayStart.subtract(const Duration(days: 29));
        final end = todayEnd;
        final startPrev = todayStart.subtract(const Duration(days: 59));
        final endPrev = todayStart.subtract(const Duration(days: 30));
        return (start, end, startPrev, endPrev);
    }
  }

  void _updateStatsForDuration() {
    final (start, end, startPrev, endPrev) =
        _getDateTimeRanges(_selectedDuration);

    int countInPeriod(List<DocumentSnapshot> docs, DateTime s, DateTime e) {
      return docs.where((doc) {
        final d = _getDocDate(doc);
        if (d == null) return false;
        return d.isAfter(s) && d.isBefore(e);
      }).length;
    }

    // Patients
    final currentPatients = countInPeriod(_patientDocs, start, end);
    final prevPatients = countInPeriod(_patientDocs, startPrev, endPrev);
    patientCount = currentPatients;
    patientDelta = _formatDelta(currentPatients, prevPatients);

    // Appointments
    final currentAppts = countInPeriod(_appointmentDocs, start, end);
    final prevAppts = countInPeriod(_appointmentDocs, startPrev, endPrev);
    appointmentCount = currentAppts;
    appointmentDelta = _formatDelta(currentAppts, prevAppts);

    // Reports
    final currentReports = countInPeriod(_reportDocs, start, end);
    final prevReports = countInPeriod(_reportDocs, startPrev, endPrev);
    reportCount = currentReports;
    reportDelta = _formatDelta(currentReports, prevReports);

    // Doctors
    doctorCount = _doctorDocs.length;
    final newDoctors = countInPeriod(_doctorDocs, start, end);
    doctorDelta = newDoctors > 0 ? '↑ +$newDoctors new' : 'No new doctors';

    // Hospitals
    hospitalCount = _hospitalDocs.length;
    final newHospitals = countInPeriod(_hospitalDocs, start, end);
    hospitalDelta =
        newHospitals > 0 ? '↑ +$newHospitals new' : 'All operational';

    // Labs
    labCount = _labDocs.length;
    final newLabs = countInPeriod(_labDocs, start, end);
    labDelta = newLabs > 0 ? '↑ +$newLabs new' : 'All active';

    // Departments
    departmentCount = _departmentDocs.length;
    final newDepts = countInPeriod(_departmentDocs, start, end);
    departmentDelta = newDepts > 0 ? '↑ +$newDepts new' : 'All staffed';

    // Staff
    staffCount = doctorCount + departmentCount;
    final newStaff = newDoctors + newDepts;
    staffDelta = newStaff > 0 ? '↑ +$newStaff new' : 'No change';

    setState(() {});
  }

  String _formatDelta(int current, int prev) {
    if (prev == 0) {
      if (current == 0) return 'No change';
      return '↑ +$current';
    }
    final pct = ((current - prev) / prev * 100).round();
    if (pct > 0) {
      return '↑ +$pct%';
    } else if (pct < 0) {
      return '↓ $pct%';
    } else {
      return 'No change';
    }
  }

  Future<void> _loadSummary() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('patients').get(),
      FirebaseFirestore.instance.collection('reports').get(),
      FirebaseFirestore.instance.collection('doctors').get(),
      FirebaseFirestore.instance.collection('hospitals').get(),
      FirebaseFirestore.instance.collection('labs').get(),
      FirebaseFirestore.instance.collection('departments').get(),
      FirebaseFirestore.instance.collection('appointments').get(),
    ]);

    _patientDocs = results[0].docs;
    _reportDocs = results[1].docs;
    _doctorDocs = results[2].docs;
    _hospitalDocs = results[3].docs;
    _labDocs = results[4].docs;
    _departmentDocs = results[5].docs;
    _appointmentDocs = results[6].docs;

    _updateStatsForDuration();
    _loadChartData();
  }

  void _loadChartData() {
    if (_patientDocs.isEmpty && _reportDocs.isEmpty) {
      setState(() {
        _patientSpots = [const FlSpot(0, 0)];
        _reportSpots = [const FlSpot(0, 0)];
        _chartIntervalY = 1.0;
      });
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    List<FlSpot> patientSpots = [];
    List<FlSpot> reportSpots = [];
    double intervalY = 1.0;

    if (_selectedDuration == 'Today' || _selectedDuration == 'Yesterday') {
      // 24 hourly spots
      final targetDayStart = _selectedDuration == 'Today'
          ? todayStart
          : todayStart.subtract(const Duration(days: 1));
      final targetDayEnd = targetDayStart
          .add(const Duration(hours: 23, minutes: 59, seconds: 59));

      final Map<int, int> patientPerHour = {};
      final Map<int, int> reportPerHour = {};
      for (int i = 0; i < 24; i++) {
        patientPerHour[i] = 0;
        reportPerHour[i] = 0;
      }

      for (final doc in _patientDocs) {
        final d = _getDocDate(doc);
        if (d == null) continue;
        if (d.isAfter(targetDayStart) && d.isBefore(targetDayEnd)) {
          final hour = d.hour;
          patientPerHour[hour] = (patientPerHour[hour] ?? 0) + 1;
        }
      }

      for (final doc in _reportDocs) {
        final d = _getDocDate(doc);
        if (d == null) continue;
        if (d.isAfter(targetDayStart) && d.isBefore(targetDayEnd)) {
          final hour = d.hour;
          reportPerHour[hour] = (reportPerHour[hour] ?? 0) + 1;
        }
      }

      patientSpots = List.generate(24, (i) {
        return FlSpot(i.toDouble(), (patientPerHour[i] ?? 0).toDouble());
      });
      reportSpots = List.generate(24, (i) {
        return FlSpot(i.toDouble(), (reportPerHour[i] ?? 0).toDouble());
      });
    } else {
      // Daily spots
      int days = 30;
      if (_selectedDuration == 'Last 7 days') days = 7;
      if (_selectedDuration == 'Last 90 days') days = 90;
      if (_selectedDuration == 'Last 180 days') days = 180;
      if (_selectedDuration == 'Last 360 days') days = 360;

      final cutoff = todayStart.subtract(Duration(days: days - 1));

      final Map<int, int> patientPerDay = {};
      final Map<int, int> reportPerDay = {};
      for (int i = 0; i < days; i++) {
        patientPerDay[i] = 0;
        reportPerDay[i] = 0;
      }

      for (final doc in _patientDocs) {
        final d = _getDocDate(doc);
        if (d == null) continue;
        if (d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)) {
          final diffDays = d.difference(cutoff).inDays;
          if (diffDays >= 0 && diffDays < days) {
            patientPerDay[diffDays] = (patientPerDay[diffDays] ?? 0) + 1;
          }
        }
      }

      for (final doc in _reportDocs) {
        final d = _getDocDate(doc);
        if (d == null) continue;
        if (d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)) {
          final diffDays = d.difference(cutoff).inDays;
          if (diffDays >= 0 && diffDays < days) {
            reportPerDay[diffDays] = (reportPerDay[diffDays] ?? 0) + 1;
          }
        }
      }

      patientSpots = List.generate(days, (i) {
        return FlSpot(i.toDouble(), (patientPerDay[i] ?? 0).toDouble());
      });
      reportSpots = List.generate(days, (i) {
        return FlSpot(i.toDouble(), (reportPerDay[i] ?? 0).toDouble());
      });
    }

    final maxPatient = patientSpots.isEmpty
        ? 0.0
        : patientSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxReport = reportSpots.isEmpty
        ? 0.0
        : reportSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxVal = maxPatient > maxReport ? maxPatient : maxReport;
    intervalY = maxVal > 5 ? (maxVal / 5).ceilToDouble() : 1.0;

    setState(() {
      _patientSpots = patientSpots;
      _reportSpots = reportSpots;
      _chartIntervalY = intervalY;
    });
  }

  // ─── Stat card ──────────────────────────────────────────────────────────────
  Widget _buildStatCard({
    required String label,
    required int value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String delta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: icon and label
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right side: value and delta
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                NumberFormat.decimalPattern().format(value),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                delta,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: (delta.startsWith('↑') || delta.contains('+'))
                      ? _teal
                      : (delta.startsWith('↓') || delta.contains('-'))
                          ? _coral
                          : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Line chart ─────────────────────────────────────────────────────────────
  Widget _buildLineChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Patients & Reports ($_selectedDuration)',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 8,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  // Patients line
                  LineChartBarData(
                    spots: _patientSpots,
                    isCurved: true,
                    color: _purple,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _purple.withOpacity(0.07),
                    ),
                  ),
                  // Reports line
                  LineChartBarData(
                    spots: _reportSpots,
                    isCurved: true,
                    color: _coral,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _coral.withOpacity(0.07),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _chartIntervalY,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: _chartIntervalY,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              s.y.toInt().toString(),
                              TextStyle(
                                color: s.barIndex == 0 ? _purple : _coral,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            children: [
              _legendItem(color: _purple, label: 'Patients', dashed: false),
              const SizedBox(width: 20),
              _legendItem(color: _coral, label: 'Reports', dashed: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(
      {required Color color, required String label, required bool dashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(24, 2),
          painter: _LegendLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return BaseLayout(
      title: 'Dashboard',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Greeting bar ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, Admin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shri Amman Clinic & Lab ·  ${DateFormat('EEEE, d MMM y').format(now)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.08),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: _selectedDuration,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: Colors.black54),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedDuration = newValue;
                                _updateStatsForDuration();
                                _loadChartData();
                              });
                            }
                          },
                          items: _durations
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _tealBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: _teal, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'System active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Stat grid ─────────────────────────────────────────────────
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isWide ? 3 : 3,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  label: 'Patients',
                  value: patientCount,
                  icon: Icons.people_alt_outlined,
                  iconColor: _purple,
                  iconBg: _purpleBg,
                  delta: patientDelta,
                ),
                _buildStatCard(
                  label: 'Doctors',
                  value: doctorCount,
                  icon: Icons.medical_services_outlined,
                  iconColor: _teal,
                  iconBg: _tealBg,
                  delta: doctorDelta,
                ),
                _buildStatCard(
                  label: 'Reports',
                  value: reportCount,
                  icon: Icons.insert_chart_outlined,
                  iconColor: _coral,
                  iconBg: _coralBg,
                  delta: reportDelta,
                ),
                _buildStatCard(
                  label: 'Hospitals',
                  value: hospitalCount,
                  icon: Icons.local_hospital_outlined,
                  iconColor: _amber,
                  iconBg: _amberBg,
                  delta: hospitalDelta,
                ),
                _buildStatCard(
                  label: 'Labs',
                  value: labCount,
                  icon: Icons.biotech_outlined,
                  iconColor: _green,
                  iconBg: _greenBg,
                  delta: labDelta,
                ),
                _buildStatCard(
                  label: 'Departments',
                  value: departmentCount,
                  icon: Icons.business_outlined,
                  iconColor: _pink,
                  iconBg: _pinkBg,
                  delta: departmentDelta,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Charts row ────────────────────────────────────────────────
            _buildLineChart(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, size.height / 2),
            Offset((x + 5).clamp(0, size.width), size.height / 2), paint);
        x += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) =>
      old.color != color || old.dashed != dashed;
}

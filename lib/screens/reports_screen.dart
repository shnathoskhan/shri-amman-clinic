// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shri_amman_clinic/utils/pdf_helper.dart';

class ParameterData {
  final TextEditingController nameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController refRangeCtrl;
  final TextEditingController valueCtrl;

  ParameterData({
    required String name,
    required String unit,
    required String refRange,
    String value = '',
  })  : nameCtrl = TextEditingController(text: name),
        unitCtrl = TextEditingController(text: unit),
        refRangeCtrl = TextEditingController(text: refRange),
        valueCtrl = TextEditingController(text: value);

  void dispose() {
    nameCtrl.dispose();
    unitCtrl.dispose();
    refRangeCtrl.dispose();
    valueCtrl.dispose();
  }

  Map<String, dynamic> toMap() => {
        'name': nameCtrl.text.trim(),
        'unit': unitCtrl.text.trim(),
        'referenceRange': refRangeCtrl.text.trim(),
        'value': valueCtrl.text.trim(),
      };
}

class TestEntry {
  final bool isProfile;
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController priceCtrl;
  final List<ParameterData> parameters;
  bool isExpanded;

  TestEntry({
    required this.isProfile,
    required this.id,
    required String title,
    required double price,
    required this.parameters,
    this.isExpanded = false,
  })  : titleCtrl = TextEditingController(text: title),
        priceCtrl = TextEditingController(
            text: price.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), ''));

  void dispose() {
    titleCtrl.dispose();
    priceCtrl.dispose();
    for (var p in parameters) {
      p.dispose();
    }
  }

  String get title => titleCtrl.text.trim();
  double get price => double.tryParse(priceCtrl.text) ?? 0.0;

  Map<String, dynamic> toMap() => {
        'isProfile': isProfile,
        'id': id,
        'title': titleCtrl.text.trim(),
        'price': price,
        'isExpanded': isExpanded,
        'parameters': parameters.map((p) => p.toMap()).toList(),
      };
}

Future<void> showReportDialog(
  BuildContext context, {
  DocumentSnapshot? doc,
  bool isReadOnly = false,
  DocumentSnapshot? initialPatient,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddReportDialog(
      doc: doc,
      isReadOnly: isReadOnly,
      initialPatient: initialPatient,
    ),
  );
}

class _AddReportDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  final bool isReadOnly;
  final DocumentSnapshot? initialPatient;
  const _AddReportDialog({
    this.doc,
    this.isReadOnly = false,
    this.initialPatient,
  });

  @override
  State<_AddReportDialog> createState() => _AddReportDialogState();
}

class _AddReportDialogState extends State<_AddReportDialog> {
  // Pre-loaded data for autocomplete
  List<DocumentSnapshot> _patients = [];
  List<DocumentSnapshot> _parameters = [];
  List<DocumentSnapshot> _profiles = [];
  List<DocumentSnapshot> _sampleTypes = [];
  List<DocumentSnapshot> _departments = [];

  List<String> _doctors = [];
  List<String> _hospitals = [];
  List<String> _labs = [];

  String _referralDr = '';
  String _referralHospital = '';
  String _referralLab = '';
  DocumentSnapshot? _selectedDepartment;

  bool _loading = true;
  String _status = 'Pending';
  String _paymentStatus = 'Pending';

  // Selections
  DocumentSnapshot? _selectedPatient;
  DocumentSnapshot? _selectedSampleType;
  final List<TestEntry> _entries = [];

  final _patientSearchCtrl = TextEditingController();
  final _testSearchCtrl = TextEditingController();
  final _sampleTypeSearchCtrl = TextEditingController();
  final _departmentSearchCtrl = TextEditingController();
  TextEditingController? _internalTestCtrl;
  final _grandTotalCtrl = TextEditingController(text: '0');
  final _sampleTypeSearchFocusNode = FocusNode();
  final _departmentSearchFocusNode = FocusNode();
  final _testSearchFocusNode = FocusNode();
  String _discountMode = 'Amount';
  final _discountCtrl = TextEditingController(text: '0');
  final _discountFocusNode = FocusNode();
  late final FocusNode _reportSwitchFocusNode;
  late final FocusNode _paymentSwitchFocusNode;

  @override
  void initState() {
    super.initState();
    _reportSwitchFocusNode = FocusNode(skipTraversal: true);
    _paymentSwitchFocusNode = FocusNode(skipTraversal: true);
    _loadData();
  }

  @override
  void dispose() {
    for (var e in _entries) {
      e.dispose();
    }
    _patientSearchCtrl.dispose();
    _testSearchCtrl.dispose();
    _sampleTypeSearchCtrl.dispose();
    _departmentSearchCtrl.dispose();
    _grandTotalCtrl.dispose();
    _discountCtrl.dispose();
    _discountFocusNode.dispose();
    _sampleTypeSearchFocusNode.dispose();
    _departmentSearchFocusNode.dispose();
    _testSearchFocusNode.dispose();
    _reportSwitchFocusNode.dispose();
    _paymentSwitchFocusNode.dispose();
    super.dispose();
  }

  void _updateTotal() {
    double total = 0.0;
    for (var e in _entries) {
      total += e.price;
    }
    final discVal = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    double discountAmount = 0.0;
    if (_discountMode == 'Percentage') {
      discountAmount = total * (discVal / 100.0);
    } else {
      discountAmount = discVal;
    }
    double grandTotal = total - discountAmount;
    if (grandTotal < 0) grandTotal = 0.0;
    _grandTotalCtrl.text =
        grandTotal.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  Future<void> _loadData() async {
    try {
      final fs = FirebaseFirestore.instance;
      final snaps = await Future.wait([
        fs.collection('patients').get(),
        fs.collection('parameters').get(),
        fs.collection('profiles').get(),
        fs.collection('sampleTypes').get(),
        fs.collection('doctors').get(),
        fs.collection('hospitals').get(),
        fs.collection('labs').get(),
        fs.collection('departments').get(),
      ]);

      if (mounted) {
        setState(() {
          _patients = snaps[0].docs;
          _parameters = snaps[1].docs;
          _profiles = snaps[2].docs;
          _sampleTypes = snaps[3].docs;
          _departments = snaps[7].docs;

          List<String> toNames(QuerySnapshot s) => s.docs
              .map((d) =>
                  (d.data() as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList()
            ..sort();

          _doctors = toNames(snaps[4]);
          _hospitals = toNames(snaps[5]);
          _labs = toNames(snaps[6]);

          if (widget.doc != null) {
            _populateFromDoc();
          } else if (widget.initialPatient != null) {
            try {
              _selectedPatient = _patients
                  .firstWhere((p) => p.id == widget.initialPatient!.id);
            } catch (_) {
              _selectedPatient = widget.initialPatient;
            }
            if (_selectedPatient != null) {
              final pData = _selectedPatient!.data() as Map<String, dynamic>;
              _patientSearchCtrl.text =
                  '${pData['fullName'] ?? ''} (${pData['patient_id'] ?? ''})';
              _referralDr = pData['referralDr'] ?? '';
              if (!_doctors.contains(_referralDr)) _referralDr = '';
              _referralHospital = pData['referralHospital'] ?? '';
              if (!_hospitals.contains(_referralHospital))
                _referralHospital = '';
              _referralLab = pData['referralLab'] ?? '';
              if (!_labs.contains(_referralLab)) _referralLab = '';
            }
          }

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  void _populateFromDoc() {
    final data = widget.doc!.data() as Map<String, dynamic>;

    _patientSearchCtrl.text = '${data['patientName']} (${data['patientId']})';
    try {
      _selectedPatient =
          _patients.firstWhere((p) => p.id == data['patientRefId']);
    } catch (_) {}

    try {
      _selectedSampleType = _sampleTypes
          .firstWhere((s) => (s.data() as Map)['name'] == data['sampleType']);
    } catch (_) {}

    _status = data['status'] as String? ?? 'Pending';
    _paymentStatus = data['paymentStatus'] as String? ?? 'Pending';
    _discountMode = data['discountMode'] as String? ?? 'Amount';
    _discountCtrl.text = data['discount']?.toString() ?? '0';
    _referralDr = data['referralDr'] as String? ?? '';
    _referralHospital = data['referralHospital'] as String? ?? '';
    _referralLab = data['referralLab'] as String? ?? '';
    try {
      _selectedDepartment = _departments
          .firstWhere((d) => (d.data() as Map)['name'] == data['department']);
      _departmentSearchCtrl.text = data['department'] as String? ?? '';
    } catch (_) {}
    _grandTotalCtrl.text = data['totalPrice']?.toString() ?? '0';

    final testsList =
        (data['tests'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (var t in testsList) {
      final paramsList =
          (t['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final params = paramsList.map((p) {
        return ParameterData(
          name: p['name'] ?? '',
          unit: p['unit'] ?? '',
          refRange: p['referenceRange'] ?? '',
          value: p['value'] ?? '',
        );
      }).toList();

      _entries.add(TestEntry(
        isProfile: t['isProfile'] ?? false,
        id: t['id'] ?? '',
        title: t['title'] ?? '',
        price: (t['price'] ?? 0.0).toDouble(),
        parameters: params,
        isExpanded: t['isExpanded'] ?? true,
      ));
    }
  }

  void _addParameter(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _entries.add(TestEntry(
        isProfile: false,
        id: doc.id,
        title: data['name'] ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        parameters: [
          ParameterData(
            name: data['name'] ?? '',
            unit: data['unit'] ?? '',
            refRange: data['referenceRange'] ?? '',
          )
        ],
      ));
      _updateTotal();
    });
  }

  void _addProfile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final paramsData =
        (data['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    setState(() {
      _entries.add(TestEntry(
        isProfile: true,
        id: doc.id,
        title: data['title'] ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        parameters: paramsData
            .map((p) => ParameterData(
                  name: p['name'] ?? '',
                  unit: p['unit'] ?? '',
                  refRange: p['referenceRange'] ?? '',
                ))
            .toList(),
      ));
      _updateTotal();
    });
  }

  Future<String> _generateReportId() async {
    final now = DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final prefix = 'SAR$yy$mm$dd';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('reports')
          .where('report_id', isGreaterThanOrEqualTo: prefix)
          .where('report_id', isLessThan: '$prefix\uf8ff')
          .orderBy('report_id', descending: true)
          .limit(1)
          .get();

      int seq = 1;
      if (snap.docs.isNotEmpty) {
        final lastId = snap.docs.first.data()['report_id'] as String?;
        if (lastId != null && lastId.length >= prefix.length + 3) {
          final lastSeqStr = lastId.substring(prefix.length);
          final lastSeq = int.tryParse(lastSeqStr);
          if (lastSeq != null) {
            seq = lastSeq + 1;
          }
        }
      }
      return '$prefix${seq.toString().padLeft(3, '0')}';
    } catch (e) {
      return '${prefix}001';
    }
  }

  Future<String> _generateSampleId() async {
    final now = DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final prefix = 'SID$yy$mm$dd';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('reports')
          .where('sid', isGreaterThanOrEqualTo: prefix)
          .where('sid', isLessThan: '$prefix\uf8ff')
          .orderBy('sid', descending: true)
          .limit(1)
          .get();

      int seq = 1;
      if (snap.docs.isNotEmpty) {
        final lastId = snap.docs.first.data()['sid'] as String?;
        if (lastId != null && lastId.length >= prefix.length + 3) {
          final lastSeqStr = lastId.substring(prefix.length);
          final lastSeq = int.tryParse(lastSeqStr);
          if (lastSeq != null) {
            seq = lastSeq + 1;
          }
        }
      }
      return '$prefix${seq.toString().padLeft(3, '0')}';
    } catch (e) {
      return '${prefix}001';
    }
  }

  Future<void> _saveReport() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a patient')));
      return;
    }
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one test')));
      return;
    }
    if (_selectedSampleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a sample type')));
      return;
    }

    final pData = _selectedPatient!.data() as Map<String, dynamic>;
    final patientId = pData['patient_id'] ?? '';
    final patientName = pData['fullName'] ?? '';
    final sampleTypeName = (_selectedSampleType!.data() as Map)['name'] ?? '';

    final grandTotal = double.tryParse(_grandTotalCtrl.text.trim()) ?? 0.0;

    final reportData = <String, dynamic>{
      'patientRefId': _selectedPatient!.id,
      'patientId': patientId,
      'patientName': patientName,
      'patientAge':
          '${pData['age'] ?? ''}${pData['ageUnit'] != null ? ' ${pData['ageUnit']}' : ''}',
      'patientGender': pData['gender'] ?? '',
      'patientMobile': pData['mobile'] ?? '',
      'patientAddress': pData['address'] ?? '',
      'patientCity': pData['city'] ?? '',
      'patientPincode': pData['pincode'] ?? '',
      'sampleType': sampleTypeName,
      'updatedAt': FieldValue.serverTimestamp(),
      'totalPrice': grandTotal,
      'status': _status,
      'paymentStatus': _paymentStatus,
      'referralDr': _referralDr,
      'referralHospital': _referralHospital,
      'referralLab': _referralLab,
      'department': _selectedDepartment != null
          ? (_selectedDepartment!.data() as Map)['name'] ?? ''
          : '',
      'tests': _entries.map((e) => e.toMap()).toList(),
      'discount': double.tryParse(_discountCtrl.text.trim()) ?? 0.0,
      'discountMode': _discountMode,
    };

    try {
      if (widget.doc == null) {
        final reportId = await _generateReportId();
        final sampleId = await _generateSampleId();
        reportData['report_id'] = reportId;
        reportData['sid'] = sampleId;
        reportData['createdAt'] = FieldValue.serverTimestamp();
        reportData['sampleCollected'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('reports')
            .add(reportData);
        if (mounted) {
          final newDoc = await docRef.get();
          final mobile =
              ((_selectedPatient!.data() as Map<String, dynamic>)['mobile'] ??
                      '')
                  .toString();
          await _showPrintShareDialog(
              context, newDoc, mobile, _status, _paymentStatus);
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        await widget.doc!.reference.update(reportData);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save report: $e')));
      }
    }
  }

  /// Shows a print/share popup after report creation.
  /// Print Report / Share Report only shown if [status] == 'Completed'.
  /// Print Bill / Share Bill only shown if [paymentStatus] == 'Paid'.
  Future<void> _showPrintShareDialog(
    BuildContext ctx,
    DocumentSnapshot doc,
    String mobile,
    String status,
    String paymentStatus,
  ) async {
    final showReport = status == 'Completed';
    final showBill = paymentStatus == 'Paid';
    if (!showReport && !showBill) return;
    if (!ctx.mounted) return;

    final data = doc.data() as Map<String, dynamic>;
    final reportId = data['report_id'] ?? '';

    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 22),
            const SizedBox(width: 8),
            const Text('Report Saved'),
            const Spacer(),
            Text(reportId,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showReport) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Report',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print'),
                      onPressed: () async => PdfHelper.printReport(doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      onPressed: () async => PdfHelper.shareReport(doc, mobile),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (showBill) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Bill',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: const Text('Print'),
                      onPressed: () async => PdfHelper.printBill(doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      onPressed: () async => PdfHelper.shareBill(doc, mobile),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _drop(String label, String value, List<String> options,
      Function(String) onChanged) {
    final valid = value.isEmpty || options.contains(value) ? value : '';
    final opts = ['— None —', ...options];
    final current = valid.isEmpty ? '— None —' : valid;

    return Expanded(
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): NextFocusIntent(),
        },
        child: DropdownButtonFormField<String>(
          value: current,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: opts
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            onChanged(val == '— None —' ? '' : val);
          },
        ),
      ),
    );
  }

  Widget _patientInfoChip(
      IconData icon, String label, String value, ColorScheme cs) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSearch() {
    return Autocomplete<DocumentSnapshot>(
      displayStringForOption: (doc) {
        final d = doc.data() as Map<String, dynamic>;
        return '${d['fullName'] ?? ''} (${d['patient_id'] ?? ''}) - ${d['mobile'] ?? ''}';
      },
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<DocumentSnapshot>.empty();
        }
        final q = textEditingValue.text.toLowerCase();
        return _patients.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['fullName'] ?? '').toString().toLowerCase();
          final id = (d['patient_id'] ?? '').toString().toLowerCase();
          final phone = (d['mobile'] ?? '').toString().toLowerCase();
          return name.contains(q) || id.contains(q) || phone.contains(q);
        });
      },
      onSelected: (doc) {
        setState(() {
          _selectedPatient = doc;
          final d = doc.data() as Map<String, dynamic>;
          _referralDr = d['referralDr'] ?? '';
          if (!_doctors.contains(_referralDr)) _referralDr = '';
          _referralHospital = d['referralHospital'] ?? '';
          if (!_hospitals.contains(_referralHospital)) _referralHospital = '';
          _referralLab = d['referralLab'] ?? '';
          if (!_labs.contains(_referralLab)) _referralLab = '';
        });
        _sampleTypeSearchFocusNode.requestFocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.doc == null && !widget.isReadOnly,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Search Patient',
            hintText: 'Name, ID, or Phone',
            prefixIcon: const Icon(Icons.person_search_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixIcon: _selectedPatient != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      setState(() => _selectedPatient = null);
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final doc = options.elementAt(index);
                  final d = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(d['fullName'] ?? ''),
                    subtitle: Text(
                        'ID: ${d['patient_id'] ?? ''} | Ph: ${d['mobile'] ?? ''}'),
                    onTap: () => onSelected(doc),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestSearch() {
    return Autocomplete<DocumentSnapshot>(
      focusNode: _testSearchFocusNode,
      textEditingController: _testSearchCtrl,
      displayStringForOption: (doc) {
        final d = doc.data() as Map<String, dynamic>;
        final isProfile = d.containsKey('title');
        return isProfile ? d['title'] ?? '' : d['name'] ?? '';
      },
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<DocumentSnapshot>.empty();
        }
        final q = textEditingValue.text.toLowerCase();

        final matchedParams = _parameters.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['name'] ?? '').toString().toLowerCase().contains(q);
        });

        final matchedProfiles = _profiles.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['title'] ?? '').toString().toLowerCase().contains(q);
        });

        return [...matchedProfiles, ...matchedParams];
      },
      onSelected: (doc) {
        final isProfile = (doc.data() as Map).containsKey('title');
        if (isProfile) {
          _addProfile(doc);
        } else {
          _addParameter(doc);
        }
        Future.delayed(const Duration(milliseconds: 50), () {
          _internalTestCtrl?.clear();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _internalTestCtrl = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Search Parameter or Profile',
            hintText: 'e.g. CBC or Glucose',
            prefixIcon: const Icon(Icons.search_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final doc = options.elementAt(index);
                  final d = doc.data() as Map<String, dynamic>;
                  final isProfile = d.containsKey('title');
                  final name = isProfile ? d['title'] : d['name'];
                  return ListTile(
                    leading: Icon(
                      isProfile ? Icons.playlist_add_check : Icons.biotech,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(name ?? ''),
                    subtitle: Text(isProfile ? 'Profile' : 'Parameter'),
                    onTap: () {
                      onSelected(doc);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParameterRow(ParameterData param, bool isIndented,
      {VoidCallback? onRemove}) {
    return Padding(
      padding:
          EdgeInsets.only(left: isIndented ? 32.0 : 0.0, top: 8.0, bottom: 8.0),
      child: Row(
        children: [
          if (onRemove != null && !widget.isReadOnly) ...[
            IconButton(
              focusNode: FocusNode(skipTraversal: true),
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 20),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: widget.isReadOnly
                ? Text(param.nameCtrl.text,
                    style: const TextStyle(fontWeight: FontWeight.w500))
                : TextField(
                    controller: param.nameCtrl,
                    focusNode: FocusNode(skipTraversal: true),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Name'),
                  ),
          ),
          Expanded(
            flex: 1,
            child: widget.isReadOnly
                ? Text(param.unitCtrl.text,
                    style: const TextStyle(color: Colors.grey))
                : TextField(
                    controller: param.unitCtrl,
                    focusNode: FocusNode(skipTraversal: true),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Unit'),
                  ),
          ),
          Expanded(
            flex: 2,
            child: widget.isReadOnly
                ? Text(param.refRangeCtrl.text,
                    style: const TextStyle(color: Colors.grey))
                : TextField(
                    controller: param.refRangeCtrl,
                    focusNode: FocusNode(skipTraversal: true),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Ref. Range'),
                  ),
          ),
          Expanded(
            flex: 2,
            child: widget.isReadOnly
                ? Text(
                    param.valueCtrl.text.isEmpty ? '-' : param.valueCtrl.text,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  )
                : TextField(
                    controller: param.valueCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Result Value',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleTypeSearch() {
    return Autocomplete<DocumentSnapshot>(
      focusNode: _sampleTypeSearchFocusNode,
      textEditingController: _sampleTypeSearchCtrl,
      displayStringForOption: (doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['name'] ?? '';
      },
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<DocumentSnapshot>.empty();
        }
        final q = textEditingValue.text.toLowerCase();
        return _sampleTypes.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['name'] ?? '').toString().toLowerCase();
          return name.contains(q);
        });
      },
      onSelected: (doc) {
        setState(() => _selectedSampleType = doc);
        _departmentSearchFocusNode.requestFocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Search Sample Type',
            hintText: 'e.g. Blood, Serum',
            prefixIcon: const Icon(Icons.colorize_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixIcon: _selectedSampleType != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      setState(() => _selectedSampleType = null);
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final doc = options.elementAt(index);
                  final d = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(d['name'] ?? ''),
                    onTap: () => onSelected(doc),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentSearch() {
    return Autocomplete<DocumentSnapshot>(
      focusNode: _departmentSearchFocusNode,
      textEditingController: _departmentSearchCtrl,
      displayStringForOption: (doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['name'] ?? '';
      },
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<DocumentSnapshot>.empty();
        }
        final q = textEditingValue.text.toLowerCase();
        return _departments.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['name'] ?? '').toString().toLowerCase();
          return name.contains(q);
        });
      },
      onSelected: (doc) {
        setState(() => _selectedDepartment = doc);
        _testSearchFocusNode.requestFocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Search Department',
            hintText: 'e.g. Pathology, Biochemistry',
            prefixIcon: const Icon(Icons.business_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixIcon: _selectedDepartment != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      setState(() => _selectedDepartment = null);
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final doc = options.elementAt(index);
                  final d = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(d['name'] ?? ''),
                    onTap: () => onSelected(doc),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: cs.surfaceContainerLow,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.isReadOnly
                        ? cs.primaryContainer
                        : cs.secondaryContainer,
                    child: Icon(
                        widget.isReadOnly
                            ? Icons.assignment
                            : Icons.note_add_outlined,
                        color: widget.isReadOnly
                            ? cs.onPrimaryContainer
                            : cs.onSecondaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            widget.isReadOnly
                                ? 'View Report'
                                : (widget.doc == null
                                    ? 'Add New Report'
                                    : 'Edit Report'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        if (widget.doc != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Report ID: ${(widget.doc?.data() as Map<String, dynamic>?)?['report_id'] ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Builder(builder: (context) {
                            final d =
                                widget.doc?.data() as Map<String, dynamic>?;
                            if (d == null) return const SizedBox.shrink();
                            final created = d['createdAt'] as Timestamp?;
                            final updated = d['updatedAt'] as Timestamp?;

                            String cStr = created != null
                                ? DateFormat('MMM dd, yyyy hh:mm a')
                                    .format(created.toDate())
                                : 'N/A';
                            String uStr = updated != null
                                ? DateFormat('MMM dd, yyyy hh:mm a')
                                    .format(updated.toDate())
                                : 'N/A';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Created: $cStr • Updated: $uStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (widget.isReadOnly)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _status == 'Completed'
                                              ? Colors.green
                                                  .withValues(alpha: 0.15)
                                              : Colors.orange
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Report: $_status',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _status == 'Completed'
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _paymentStatus == 'Paid'
                                              ? Colors.green
                                                  .withValues(alpha: 0.15)
                                              : Colors.red
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Payment: $_paymentStatus',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _paymentStatus == 'Paid'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _status == 'Completed'
                                              ? Colors.green
                                                  .withValues(alpha: 0.15)
                                              : Colors.orange
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Report: $_status',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _status == 'Completed'
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _paymentStatus == 'Paid'
                                              ? Colors.green
                                                  .withValues(alpha: 0.15)
                                              : Colors.red
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Payment: $_paymentStatus',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _paymentStatus == 'Paid'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  if (widget.doc != null) ...[
                    const SizedBox(width: 12),
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: (widget.doc?.data()
                              as Map<String, dynamic>?)?['report_id'] ??
                          '',
                      width: 120,
                      height: 35,
                      drawText: false,
                    ),
                  ],
                ],
              ),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: FocusTraversalGroup(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Patient Selection
                        const Text('Patient Details',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (widget.isReadOnly || _selectedPatient != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Builder(builder: (context) {
                              final pData = _selectedPatient != null
                                  ? _selectedPatient!.data()
                                      as Map<String, dynamic>
                                  : <String, dynamic>{};
                              final name = pData['fullName'] ??
                                  _patientSearchCtrl.text.split(' (').first;
                              final patientId = pData['patient_id'] ??
                                  _patientSearchCtrl.text
                                      .split(' (')
                                      .last
                                      .replaceAll(')', '');
                              final age = pData['age']?.toString() ?? '';
                              final gender = pData['gender'] ?? '';
                              final mobile = pData['mobile'] ?? '';
                              final address = pData['address'] ?? '';
                              final pincode = pData['pincode'] ?? '';

                              return Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: cs.primaryContainer,
                                        child: Icon(Icons.person,
                                            color: cs.onPrimaryContainer),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'ID: $patientId',
                                              style: TextStyle(
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      BarcodeWidget(
                                        barcode: Barcode.code128(),
                                        data: patientId.toString(),
                                        width: 100,
                                        height: 35,
                                        drawText: false,
                                      ),
                                      if (!widget.isReadOnly) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              _selectedPatient = null;
                                              _patientSearchCtrl.clear();
                                            });
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (_selectedPatient != null) ...[
                                    const SizedBox(height: 10),
                                    Divider(
                                        height: 1,
                                        color: cs.outlineVariant
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _patientInfoChip(Icons.cake_outlined,
                                            'Age/Gender', '$age / $gender', cs),
                                        const SizedBox(width: 16),
                                        _patientInfoChip(
                                            Icons.phone_outlined,
                                            'Contact',
                                            mobile.isEmpty ? 'N/A' : mobile,
                                            cs),
                                        const SizedBox(width: 16),
                                        _patientInfoChip(
                                            Icons.location_on_outlined,
                                            'Address',
                                            address.isEmpty ? 'N/A' : address,
                                            cs),
                                        const SizedBox(width: 16),
                                        _patientInfoChip(
                                            Icons.pin_drop_outlined,
                                            'Pincode',
                                            pincode.isEmpty ? 'N/A' : pincode,
                                            cs),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Builder(builder: (context) {
                                      if (!widget.isReadOnly) {
                                        return Row(
                                          children: [
                                            _drop(
                                                'Ref. Doctor',
                                                _referralDr,
                                                _doctors,
                                                (v) => setState(
                                                    () => _referralDr = v)),
                                            const SizedBox(width: 8),
                                            _drop(
                                                'Ref. Hospital',
                                                _referralHospital,
                                                _hospitals,
                                                (v) => setState(() =>
                                                    _referralHospital = v)),
                                            const SizedBox(width: 8),
                                            _drop(
                                                'Ref. Lab',
                                                _referralLab,
                                                _labs,
                                                (v) => setState(
                                                    () => _referralLab = v)),
                                          ],
                                        );
                                      }

                                      bool isValid(String s) =>
                                          s.isNotEmpty && s != '— None —';
                                      String referValue = 'Self';
                                      IconData referIcon = Icons.person_outline;
                                      String referLabel = 'Referred By';

                                      if (isValid(_referralDr)) {
                                        referValue = _referralDr;
                                        referIcon =
                                            Icons.medical_services_outlined;
                                        referLabel = 'Ref. Doctor';
                                      } else if (isValid(_referralHospital)) {
                                        referValue = _referralHospital;
                                        referIcon =
                                            Icons.local_hospital_outlined;
                                        referLabel = 'Ref. Hospital';
                                      } else if (isValid(_referralLab)) {
                                        referValue = _referralLab;
                                        referIcon = Icons.science_outlined;
                                        referLabel = 'Ref. Lab';
                                      }

                                      return Row(
                                        children: [
                                          _patientInfoChip(referIcon,
                                              referLabel, referValue, cs),
                                          const SizedBox(width: 16),
                                          const Expanded(
                                              flex: 2,
                                              child: SizedBox.shrink()),
                                        ],
                                      );
                                    }),
                                  ],
                                ],
                              );
                            }),
                          )
                        else
                          _buildPatientSearch(),
                        const SizedBox(height: 24),

                        // 2. Sample Type & SID
                        const Text('Sample Type & SID',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (widget.isReadOnly || _selectedSampleType != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: cs.secondaryContainer,
                                  child: Icon(Icons.science,
                                      color: cs.onSecondaryContainer),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedSampleType != null
                                            ? (_selectedSampleType!.data()
                                                    as Map<String,
                                                        dynamic>)['name'] ??
                                                ''
                                            : (widget.doc!.data() as Map<String,
                                                    dynamic>)['sampleType'] ??
                                                '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16),
                                      ),
                                      if (widget.doc != null)
                                        Text(
                                          'SID: ${(widget.doc!.data() as Map<String, dynamic>)['sid'] ?? ''}',
                                          style: TextStyle(
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.6),
                                              fontSize: 13),
                                        ),
                                    ],
                                  ),
                                ),
                                if (widget.doc != null) ...[
                                  const SizedBox(width: 12),
                                  BarcodeWidget(
                                    barcode: Barcode.code128(),
                                    data: (widget.doc!.data()
                                                as Map<String, dynamic>)['sid']
                                            ?.toString() ??
                                        '',
                                    width: 100,
                                    height: 35,
                                    drawText: false,
                                  ),
                                ],
                                if (!widget.isReadOnly) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _selectedSampleType = null;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          _buildSampleTypeSearch(),
                        const SizedBox(height: 24),

                        // 3. Department
                        const Text('Department',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (widget.isReadOnly || _selectedDepartment != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: cs.tertiaryContainer,
                                  child: Icon(Icons.business,
                                      color: cs.onTertiaryContainer),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDepartment != null
                                        ? (_selectedDepartment!.data() as Map<
                                                String, dynamic>)['name'] ??
                                            ''
                                        : (widget.doc!.data() as Map<String,
                                                dynamic>)['department'] ??
                                            '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                ),
                                if (!widget.isReadOnly) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _selectedDepartment = null;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          _buildDepartmentSearch(),
                        const SizedBox(height: 24),

                        if (!widget.isReadOnly) ...[
                          // 4.  Add Tests
                          const Text('Tests',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _buildTestSearch(),
                          const SizedBox(height: 24),
                        ],

                        // 4. Selected Tests List
                        if (_entries.isNotEmpty) ...[
                          Row(
                            children: [
                              const Text('Selected Tests',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                focusNode: FocusNode(skipTraversal: true),
                                onPressed: () {
                                  setState(() {
                                    for (var e in _entries) {
                                      e.isExpanded = true;
                                    }
                                  });
                                },
                                icon: const Icon(Icons.expand, size: 16),
                                label: const Text('Expand All',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                focusNode: FocusNode(skipTraversal: true),
                                onPressed: () {
                                  setState(() {
                                    for (var e in _entries) {
                                      e.isExpanded = false;
                                    }
                                  });
                                },
                                icon: const Icon(Icons.compress, size: 16),
                                label: const Text('Collapse All',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children:
                                  _entries.asMap().entries.map((entryPair) {
                                final index = entryPair.key;
                                final entry = entryPair.value;
                                return Column(
                                  children: [
                                    if (index > 0)
                                      const Divider(height: 1, thickness: 1),
                                    // Profile / Parameter Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      color: cs.primaryContainer
                                          .withValues(alpha: 0.3),
                                      child: Row(
                                        children: [
                                          if (!widget.isReadOnly)
                                            IconButton(
                                              focusNode: FocusNode(
                                                  skipTraversal: true),
                                              icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Colors.red,
                                                  size: 20),
                                              onPressed: () {
                                                setState(() =>
                                                    _entries.removeAt(index));
                                                _updateTotal();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          if (!widget.isReadOnly)
                                            const SizedBox(width: 12),
                                          Icon(Icons.playlist_add_check,
                                              size: 18, color: cs.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: widget.isReadOnly
                                                ? Text(entry.titleCtrl.text,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: cs.primary))
                                                : TextField(
                                                    controller: entry.titleCtrl,
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: cs.primary,
                                                        fontSize: 14),
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    decoration:
                                                        const InputDecoration(
                                                      isDense: true,
                                                      border: InputBorder.none,
                                                      hintText: 'Profile Title',
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Subtotal: ₹ ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          widget.isReadOnly
                                              ? Text('${entry.price}',
                                                  style: TextStyle(
                                                      color: cs.primary,
                                                      fontWeight:
                                                          FontWeight.w600))
                                              : SizedBox(
                                                  width: 60,
                                                  child: TextField(
                                                    controller: entry.priceCtrl,
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                            decimal: true),
                                                    style: TextStyle(
                                                        color: cs.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13),
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    decoration:
                                                        const InputDecoration(
                                                      isDense: true,
                                                      border: InputBorder.none,
                                                      hintText: '0.00',
                                                    ),
                                                    onChanged: (_) =>
                                                        _updateTotal(),
                                                  ),
                                                ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            focusNode:
                                                FocusNode(skipTraversal: true),
                                            icon: Icon(
                                                entry.isExpanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                color: cs.primary,
                                                size: 24),
                                            onPressed: () {
                                              setState(() {
                                                entry.isExpanded =
                                                    !entry.isExpanded;
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Profile Parameters
                                    if (entry.isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            right: 12, bottom: 8),
                                        child: Column(
                                          children: entry.parameters
                                              .asMap()
                                              .entries
                                              .map((pEntry) {
                                            final pIdx = pEntry.key;
                                            final param = pEntry.value;
                                            return _buildParameterRow(
                                                param, true, onRemove: () {
                                              setState(() {
                                                entry.parameters.removeAt(pIdx);
                                              });
                                            });
                                          }).toList(),
                                        ),
                                      ),
                                    // No else block needed; individual parameters reuse profile UI.
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Status & Payment Switches (edit mode only)
                          if (!widget.isReadOnly) ...[
                            Row(
                              children: [
                                // Report Status Switch
                                Icon(Icons.assignment_outlined,
                                    size: 16,
                                    color: cs.onSurface.withValues(alpha: 0.6)),
                                const SizedBox(width: 6),
                                Text('Report:',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.7))),
                                const SizedBox(width: 4),
                                Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    focusNode: _reportSwitchFocusNode,
                                    value: _status == 'Completed',
                                    activeThumbColor: Colors.green,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) {
                                      setState(() {
                                        _status = val ? 'Completed' : 'Pending';
                                      });
                                    },
                                  ),
                                ),
                                Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _status == 'Completed'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _status == 'Completed'
                                        ? Colors.green.shade700
                                        : cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const Spacer(),
                                // Payment Status Switch
                                Icon(Icons.payment,
                                    size: 16,
                                    color: cs.onSurface.withValues(alpha: 0.6)),
                                const SizedBox(width: 6),
                                Text('Payment:',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.7))),
                                const SizedBox(width: 4),
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _paymentStatus == 'Pending'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _paymentStatus == 'Pending'
                                        ? Colors.red.shade700
                                        : cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    focusNode: _paymentSwitchFocusNode,
                                    value: _paymentStatus == 'Paid',
                                    activeThumbColor: Colors.green,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) {
                                      setState(() {
                                        _paymentStatus =
                                            val ? 'Paid' : 'Pending';
                                      });
                                    },
                                  ),
                                ),
                                Text(
                                  'Paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _paymentStatus == 'Paid'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _paymentStatus == 'Paid'
                                        ? Colors.green.shade700
                                        : cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Discount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Discount: ',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                              ExcludeFocus(
                                child: ToggleButtons(
                                  isSelected: [
                                    _discountMode == 'Amount',
                                    _discountMode == 'Percentage'
                                  ],
                                  onPressed: widget.isReadOnly
                                      ? null
                                      : (index) {
                                          setState(() {
                                            _discountMode = index == 0
                                                ? 'Amount'
                                                : 'Percentage';
                                            _updateTotal();
                                          });
                                        },
                                  borderRadius: BorderRadius.circular(6),
                                  constraints: const BoxConstraints(
                                      minHeight: 28, minWidth: 40),
                                  children: const [
                                    Text('₹',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    Text('%',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: widget.isReadOnly
                                    ? Text(
                                        '${_discountCtrl.text} ${_discountMode == 'Amount' ? '₹' : '%'}',
                                        style: const TextStyle(fontSize: 14),
                                      )
                                    : TextField(
                                        controller: _discountCtrl,
                                        focusNode: _discountFocusNode,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        onChanged: (_) => _updateTotal(),
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Grand Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Grand Total ₹: ',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(
                                width: 120,
                                child: widget.isReadOnly
                                    ? Text(
                                        _grandTotalCtrl.text.isEmpty
                                            ? '0.00'
                                            : _grandTotalCtrl.text,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                        textAlign: TextAlign.right,
                                      )
                                    : TextField(
                                        controller: _grandTotalCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _saveReport(),
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              color: cs.surfaceContainerLow,
              child: Row(
                children: [
                  // ── Print / Share buttons in View mode ──────────────────
                  if (widget.isReadOnly && widget.doc != null && !_loading) ...[
                    // Report actions: only when status == 'Completed'
                    if (_status == 'Completed') ...[
                      _ViewActionBtn(
                        icon: Icons.print_rounded,
                        label: 'Print Report',
                        color: Colors.blue,
                        onPressed: () async =>
                            PdfHelper.printReport(widget.doc!),
                      ),
                      const SizedBox(width: 6),
                      _ViewActionBtn(
                        icon: Icons.share_rounded,
                        label: 'Share Report',
                        color: Colors.green,
                        onPressed: () async {
                          final mobile = _selectedPatient != null
                              ? ((_selectedPatient!.data()
                                          as Map<String, dynamic>)['mobile'] ??
                                      '')
                                  .toString()
                              : '';
                          await PdfHelper.shareReport(widget.doc!, mobile);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Bill actions: only when paymentStatus == 'Paid'
                    if (_paymentStatus == 'Paid') ...[
                      _ViewActionBtn(
                        icon: Icons.receipt_long_rounded,
                        label: 'Print Bill',
                        color: Colors.blueAccent,
                        onPressed: () async => PdfHelper.printBill(widget.doc!),
                      ),
                      const SizedBox(width: 6),
                      _ViewActionBtn(
                        icon: Icons.share_rounded,
                        label: 'Share Bill',
                        color: Colors.teal,
                        onPressed: () async {
                          final mobile = _selectedPatient != null
                              ? ((_selectedPatient!.data()
                                          as Map<String, dynamic>)['mobile'] ??
                                      '')
                                  .toString()
                              : '';
                          await PdfHelper.shareBill(widget.doc!, mobile);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.isReadOnly ? 'Close' : 'Cancel'),
                  ),
                  if (!widget.isReadOnly) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _loading ? null : _saveReport,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Report'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _filter = '';
  bool _sortAscending = true;
  int _rowsPerPage = 10;

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext ctx, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    final name = data?['patientName'] ?? 'Unnamed';
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete report'),
        content: Text(
            'Permanently remove report for "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(content: Text('Report deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BaseLayout(
      title: 'Reports',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final all = snap.data?.docs ?? [];
          final filtered = (_filter.isEmpty
              ? all
              : all.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  final q = _filter;
                  return (m['patientName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                      (m['patientId'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                      (m['report_id'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                      (m['sid'] ?? '').toString().toLowerCase().contains(q);
                }).toList())
            ..sort((a, b) {
              final na = (a['patientName'] ?? '').toString();
              final nb = (b['patientName'] ?? '').toString();
              return _sortAscending ? na.compareTo(nb) : nb.compareTo(na);
            });

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.6)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                hintText:
                                    'Search by name, ID, report ID, or sample ID',
                                hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurface.withValues(alpha: 0.4)),
                                prefixIcon: Icon(Icons.search_rounded,
                                    size: 18,
                                    color: cs.onSurface.withValues(alpha: 0.4)),
                                suffixIcon: _filter.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 16),
                                        onPressed: () => setState(() {
                                          _searchCtrl.clear();
                                          _filter = '';
                                        }),
                                      )
                                    : null,
                              ),
                              onChanged: (v) => setState(
                                  () => _filter = v.trim().toLowerCase()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => showReportDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Report'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 40,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.2)),
                                  const SizedBox(height: 8),
                                  Text('No reports found',
                                      style: TextStyle(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4))),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: constraints.maxWidth > 1100
                                            ? constraints.maxWidth
                                            : 1100,
                                        child: PaginatedDataTable(
                                          columnSpacing: 20,
                                          horizontalMargin: 24,
                                          headingRowHeight: 40,
                                          dataRowMinHeight: 48,
                                          dataRowMaxHeight: 56,
                                          rowsPerPage: _rowsPerPage,
                                          onRowsPerPageChanged: (v) {
                                            if (v != null) {
                                              setState(() => _rowsPerPage = v);
                                            }
                                          },
                                          sortColumnIndex: 1,
                                          sortAscending: _sortAscending,
                                          columns: [
                                            const DataColumn(
                                                label: Text('S.No')),
                                            DataColumn(
                                              label: const Text('Report ID'),
                                              onSort: (_, asc) => setState(
                                                  () => _sortAscending = asc),
                                            ),
                                            const DataColumn(
                                                label: Text('Patient')),
                                            const DataColumn(
                                                label: Text('Price')),
                                            const DataColumn(
                                                label: Text('Status')),
                                            const DataColumn(
                                                label: Text('Report')),
                                            const DataColumn(
                                                label: Text('Payment')),
                                            const DataColumn(
                                                label: Text('Bill')),
                                            const DataColumn(
                                                label: Text('Actions')),
                                          ],
                                          source: _ReportDataSource(
                                            docs: filtered,
                                            context: context,
                                            onView: (d) => showReportDialog(
                                                context,
                                                doc: d,
                                                isReadOnly: true),
                                            onEdit: (d) => showReportDialog(
                                                context,
                                                doc: d),
                                            onDelete: (d) =>
                                                _confirmDelete(context, d),
                                            onStatusChange:
                                                (doc, newStatus) async {
                                              await doc.reference.update(
                                                  {'status': newStatus});
                                              setState(() {});
                                            },
                                            onPaymentChange:
                                                (doc, newPayment) async {
                                              await doc.reference.update({
                                                'paymentStatus': newPayment
                                              });
                                              setState(() {});
                                            },
                                          ), // end of _ReportDataSource
                                        ), // end of PaginatedDataTable
                                      ), // end of SizedBox
                                    )); // end of return SingleChildScrollView
                              }, // end of builder
                            ), // end of LayoutBuilder
                    ), // end of Expanded
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Data source
// -----------------------------------------------------------------------------
class _ReportDataSource extends DataTableSource {
  _ReportDataSource({
    required this.docs,
    required this.context,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onPaymentChange,
  });

  final List<DocumentSnapshot> docs;
  final BuildContext context;
  final void Function(DocumentSnapshot) onView, onEdit, onDelete;
  final void Function(DocumentSnapshot doc, String newStatus) onStatusChange;
  final void Function(DocumentSnapshot doc, String newPayment) onPaymentChange;

  @override
  DataRow? getRow(int i) {
    if (i >= docs.length) return null;
    final doc = docs[i];
    final data = doc.data() as Map<String, dynamic>;

    final reportId = data['report_id'] ?? '-';
    final patientName = data['patientName'] ?? '';
    final patientId = data['patientId'] ?? '';
    final price = data['totalPrice'] ?? 0.0;
    final status = data['status'] ?? 'Pending';
    final paymentStatus = data['paymentStatus'] ?? 'Pending';

    final cs = Theme.of(context).colorScheme;

    return DataRow.byIndex(
      index: i,
      cells: [
        DataCell(Text('${i + 1}',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4)))),
        DataCell(Text(reportId.toString(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        DataCell(Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.person, size: 16, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(patientId,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ],
        )),
        DataCell(Text('\u20B9 $price',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: status == 'Completed',
                  activeThumbColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) {
                    onStatusChange(doc, val ? 'Completed' : 'Pending');
                  },
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status == 'Completed'
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'Completed') ...[
              _RActionBtn(
                icon: Icons.print,
                tooltip: 'Print Report',
                color: Colors.blue,
                onPressed: () async {
                  await PdfHelper.printReport(doc);
                },
              ),
              _RActionBtn(
                icon: Icons.share,
                tooltip: 'Share Report (WhatsApp)',
                color: Colors.green,
                onPressed: () async {
                  final pDoc = await FirebaseFirestore.instance
                      .collection('patients')
                      .doc(data['patientRefId'])
                      .get();
                  final mobile = pDoc.data()?['mobile'] ?? '';
                  await PdfHelper.shareReport(doc, mobile);
                },
              ),
            ],
          ],
        )),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: paymentStatus == 'Paid',
                  activeThumbColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) {
                    onPaymentChange(doc, val ? 'Paid' : 'Pending');
                  },
                ),
              ),
              Text(
                paymentStatus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: paymentStatus == 'Paid'
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (paymentStatus == 'Paid') ...[
              _RActionBtn(
                icon: Icons.receipt_long,
                tooltip: 'Print Bill',
                color: Colors.blueAccent,
                onPressed: () async {
                  await PdfHelper.printBill(doc);
                },
              ),
              _RActionBtn(
                icon: Icons.share,
                tooltip: 'Share Bill (WhatsApp)',
                color: Colors.teal,
                onPressed: () async {
                  final pDoc = await FirebaseFirestore.instance
                      .collection('patients')
                      .doc(data['patientRefId'])
                      .get();
                  final mobile = pDoc.data()?['mobile'] ?? '';
                  await PdfHelper.shareBill(doc, mobile);
                },
              ),
            ],
          ],
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RActionBtn(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                onPressed: () => onView(doc)),
            _RActionBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onPressed: () => onEdit(doc)),
            _RActionBtn(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                color: Colors.redAccent,
                onPressed: () => onDelete(doc)),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => docs.length;
  @override
  int get selectedRowCount => 0;
}

class _RActionBtn extends StatelessWidget {
  const _RActionBtn(
      {required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );
}

/// Compact icon+label button used in the view-dialog footer for print/share.
class _ViewActionBtn extends StatelessWidget {
  const _ViewActionBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: (color ?? Colors.grey).withOpacity(0.5)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 15),
        label: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        onPressed: onPressed,
      ),
    );
  }
}

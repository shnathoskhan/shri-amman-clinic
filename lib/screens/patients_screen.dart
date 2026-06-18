// lib/screens/admin/patient_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';
import 'package:barcode_widget/barcode_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const _kTitles = ['Mr', 'Mrs', 'Ms', 'Miss', 'Dr'];
const _kGenders = ['Male', 'Female', 'Others'];
const _kAgeUnits = ['Y', 'M', 'D'];
const _kNationality = ['INDIA'];
// Doctors, labs, and hospitals are loaded from Firestore (config/referrals).
// Fallbacks used while loading or if doc is absent.
const _kDoctorsFallback = <String>[];
const _kLabsFallback = <String>[];
const _kHospitalsFallback = <String>[];

// ─────────────────────────────────────────────────────────────────────────────
// Section model
// ─────────────────────────────────────────────────────────────────────────────
class _Section {
  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _sections = [
  _Section('Personal', Icons.person_outline_rounded),
  _Section('Contact', Icons.phone_outlined),
  _Section('Identity', Icons.badge_outlined),
  _Section('Referral', Icons.share_outlined),
  _Section('Clinical', Icons.monitor_heart_outlined),
];

// ─────────────────────────────────────────────────────────────────────────────
// Public dialog entry-point
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showPatientDialog(
  BuildContext context, {
  DocumentSnapshot? doc,
  bool isReadOnly = false,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PatientDialog(doc: doc, isReadOnly: isReadOnly),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog widget
// ─────────────────────────────────────────────────────────────────────────────
class _PatientDialog extends StatefulWidget {
  const _PatientDialog({this.doc, required this.isReadOnly});
  final DocumentSnapshot? doc;
  final bool isReadOnly;

  @override
  State<_PatientDialog> createState() => _PatientDialogState();
}

class _PatientDialogState extends State<_PatientDialog> {
  // Section nav
  int _activeSec = 0;
  final _formKey = GlobalKey<FormState>();
  late final ScrollController _scrollCtrl;
  final List<GlobalKey> _secKeys = List.generate(5, (_) => GlobalKey());

  // --- Text controllers ---
  late final TextEditingController _name,
      _dob,
      _age,
      _mobile,
      _altMobile,
      _email,
      _address,
      _city,
      _pincode,
      _passport,
      _aadhaar,
      _height,
      _weight,
      _bp;

  // --- Dropdown state ---
  late String _title,
      _gender,
      _ageUnit,
      _nationality,
      _referralLab,
      _referralDr,
      _referralHospital;

  // --- Firestore-loaded referral lists ---
  List<String> _doctors = _kDoctorsFallback;
  List<String> _labs = _kLabsFallback;
  List<String> _hospitals = _kHospitalsFallback;
  bool _referralListsLoading = true;

  Map<String, dynamic>? get _d => widget.doc?.data() as Map<String, dynamic>?;
  String _v(String k) => _d?[k]?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    _name = TextEditingController(text: _v('fullName'));
    _dob = TextEditingController(text: _v('dob'));
    _age = TextEditingController(text: _v('age'));
    _mobile = TextEditingController(text: _v('mobile'));
    _altMobile = TextEditingController(text: _v('altMobile'));
    _email = TextEditingController(text: _v('email'));
    _address = TextEditingController(text: _v('address'));
    _city = TextEditingController(text: (() {
      final v = _v('city');
      return v.isNotEmpty ? v : 'Salem';
    })());
    _pincode = TextEditingController(text: _v('pincode'));
    _passport = TextEditingController(text: _v('passport'));
    _aadhaar = TextEditingController(text: _v('aadhaar'));
    _height = TextEditingController(text: _v('height'));
    _weight = TextEditingController(text: _v('weight'));
    _bp = TextEditingController(text: _v('bp'));
    _title = _d?['title'] ?? 'Mr';
    _gender = _d?['gender'] ?? 'Male';
    _ageUnit = _d?['ageUnit'] ?? 'Y';
    _nationality = _d?['nationality'] ?? 'INDIA';
    _referralLab = _d?['referralLab'] ?? '';
    // Treat legacy 'SELF' value same as empty (None).
    final rawDr = _d?['referralDr'] ?? '';
    _referralDr = rawDr == 'SELF' ? '' : rawDr;
    _referralHospital = _d?['referralHospital'] ?? '';
    _loadReferralLists();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (final c in [
      _name,
      _dob,
      _age,
      _mobile,
      _altMobile,
      _email,
      _address,
      _city,
      _pincode,
      _passport,
      _aadhaar,
      _height,
      _weight,
      _bp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    for (int i = _secKeys.length - 1; i >= 0; i--) {
      final ctx = _secKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      if (pos.dy < MediaQuery.of(context).size.height * .5) {
        if (_activeSec != i) setState(() => _activeSec = i);
        break;
      }
    }
  }

  void _jumpTo(int index) {
    final ctx = _secKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _activeSec = index);
  }

  /// Loads names from the dedicated `doctors`, `labs`, and `hospitals` collections.
  Future<void> _loadReferralLists() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('doctors').get(),
        FirebaseFirestore.instance.collection('labs').get(),
        FirebaseFirestore.instance.collection('hospitals').get(),
      ]);
      if (!mounted) return;

      List<String> _nameList(QuerySnapshot snap) => snap.docs
          .map((d) =>
              (d.data() as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList()
        ..sort();

      setState(() {
        _doctors = _nameList(results[0]);
        _labs = _nameList(results[1]);
        _hospitals = _nameList(results[2]);
        // Reset selections that no longer exist in the loaded lists.
        if (_referralDr.isNotEmpty && !_doctors.contains(_referralDr)) {
          _referralDr = '';
        }
        if (_referralLab.isNotEmpty && !_labs.contains(_referralLab)) {
          _referralLab = '';
        }
        if (_referralHospital.isNotEmpty &&
            !_hospitals.contains(_referralHospital)) {
          _referralHospital = '';
        }
        _referralListsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _referralListsLoading = false);
    }
  }

  Future<String> _generatePatientId() async {
    final now = DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final prefix = 'SAP$yy$mm$dd';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('patients')
          .where('patient_id', isGreaterThanOrEqualTo: prefix)
          .where('patient_id', isLessThan: prefix + '\uf8ff')
          .orderBy('patient_id', descending: true)
          .limit(1)
          .get();

      int seq = 1;
      if (snap.docs.isNotEmpty) {
        final lastId = snap.docs.first.data()['patient_id'] as String?;
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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Full name is required')));
      return;
    }
    if (_mobile.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mobile number is required')));
      return;
    }
    final data = {
      'title': _title,
      'fullName': _name.text.trim(),
      'gender': _gender,
      'dob': _dob.text.trim(),
      'age': int.tryParse(_age.text) ?? 0,
      'ageUnit': _ageUnit,
      'mobile': _mobile.text.trim(),
      'altMobile': _altMobile.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'pincode': _pincode.text.trim(),
      'nationality': _nationality,
      'passport': _passport.text.trim(),
      'aadhaar': _aadhaar.text.trim(),
      'referralLab': _referralLab,
      'referralDr': _referralDr,
      'referralHospital': _referralHospital,
      'height': _height.text.trim(),
      'weight': _weight.text.trim(),
      'bp': _bp.text.trim(),
    };
    if (widget.doc == null) {
      data['patient_id'] = await _generatePatientId();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref =
          await FirebaseFirestore.instance.collection('patients').add(data);
      await ref.update({'id': ref.id});
    } else {
      await widget.doc!.reference.update(data);
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  InputDecoration _dec(String label, {String? hint, String? prefix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? kb,
    String? hint,
    String? prefix,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: ctrl,
        readOnly: widget.isReadOnly,
        keyboardType: kb,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: _dec(label, hint: hint, prefix: prefix),
      );

  Widget _drop<T>(String label, String val, List<String> opts,
      void Function(String) onChanged,
      {bool allowEmpty = false}) {
    final items = [
      if (allowEmpty)
        const DropdownMenuItem<String>(value: '', child: Text('— None —')),
      ...opts.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))),
    ];
    return DropdownButtonFormField<String>(
      value: val.isEmpty && !allowEmpty ? opts.first : val,
      decoration: _dec(label),
      style: const TextStyle(fontSize: 14),
      items: items,
      onChanged: widget.isReadOnly ? null : (v) => onChanged(v ?? val),
    );
  }

  Widget _secHeader(String title, int index) => Padding(
        key: _secKeys[index],
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .8,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _row(List<Widget> children, {List<int>? flex}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(flex: flex != null ? flex[i] : 1, child: children[i]),
          ],
        ],
      );

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildPersonal() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('Personal details', 0),
          _row([
            _drop('Title', _title, _kTitles, (v) => setState(() => _title = v)),
            _drop('Gender', _gender, _kGenders,
                (v) => setState(() => _gender = v)),
          ]),
          const SizedBox(height: 12),
          _field('Full name', _name, hint: 'e.g. Elavarasan'),
          const SizedBox(height: 12),
          _row([
            _field('Date of birth', _dob, hint: 'dd-mm-yyyy'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field('Age', _age, kb: TextInputType.number),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: _drop('Unit', _ageUnit, _kAgeUnits,
                      (v) => setState(() => _ageUnit = v)),
                ),
              ],
            ),
          ]),
        ],
      );

  Widget _buildContact() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('Contact', 1),
          _row([
            _field('Mobile', _mobile, kb: TextInputType.phone, prefix: '+91 '),
            _field('Alt. mobile', _altMobile,
                kb: TextInputType.phone, prefix: '+91 '),
          ]),
          const SizedBox(height: 12),
          _field('Email', _email, kb: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field('Address', _address, maxLines: 2),
          const SizedBox(height: 12),
          _row([
            _field('City', _city),
            _field('Pincode', _pincode, kb: TextInputType.number),
          ]),
        ],
      );

  Widget _buildIdentity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('Identity', 2),
          _drop('Nationality', _nationality, _kNationality,
              (v) => setState(() => _nationality = v)),
          const SizedBox(height: 12),
          _row([
            _field('Aadhaar no.', _aadhaar, hint: 'XXXX XXXX XXXX'),
            _field('Passport no.', _passport, hint: 'Optional'),
          ]),
        ],
      );

  Widget _buildReferral() {
    if (_referralListsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('Referral', 3),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHeader('Referral', 3),
        _row([
          // Doctors: allowEmpty = true so "— None —" behaves same as old SELF
          _drop('Referred by (doctor)', _referralDr, _doctors,
              (v) => setState(() => _referralDr = v),
              allowEmpty: true),
          _drop('Outside lab', _referralLab, _labs,
              (v) => setState(() => _referralLab = v),
              allowEmpty: true),
        ]),
        const SizedBox(height: 12),
        _drop('Referring hospital', _referralHospital, _hospitals,
            (v) => setState(() => _referralHospital = v),
            allowEmpty: true),
      ],
    );
  }

  Widget _buildClinical() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('Clinical', 4),
          _row([
            _field('Height (cm)', _height, kb: TextInputType.number),
            _field('Weight (kg)', _weight, kb: TextInputType.number),
            _field('BP', _bp, hint: '120/80'),
          ]),
          const SizedBox(height: 12),
        ],
      );

  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNew = widget.doc == null;
    final title = widget.isReadOnly
        ? 'View patient'
        : isNew
            ? 'Add patient'
            : 'Edit patient';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(
                      bottom:
                          BorderSide(color: cs.outlineVariant.withOpacity(.5))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .start, // Aligns elements neatly at the top if the column grows
                  children: [
                    // 1. Icon Container
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isNew ? Icons.person_add_outlined : Icons.edit_outlined,
                        size: 17,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 2. Text & Barcode Info (Wrapped in Expanded to prevent overflow)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow
                                .ellipsis, // Safely handles ultra-long titles
                          ),
                          if (widget.isReadOnly && widget.doc != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Patient ID: ${(_d)?['patient_id'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(.6),
                              ),
                            ),
                            const SizedBox(
                                height:
                                    8), // Slightly increased for breathing room
                            BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: (_d)?['patient_id'] ?? '',
                              width: 140,
                              height: 40,
                              drawText: false,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(
                        width: 8), // Small gap between content and close button

                    // 3. Close Button
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets
                          .zero, // Cleans up accidental internal padding
                      constraints:
                          const BoxConstraints(), // Shrinks hit target tightly around the compact icon
                    ),
                  ],
                ),
              ),

              // ── Body (sidenav + form) ──────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sidenav
                    Container(
                      width: 156,
                      decoration: BoxDecoration(
                        border: Border(
                            right: BorderSide(
                                color: cs.outlineVariant.withOpacity(.5))),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _sections.length,
                        itemBuilder: (_, i) {
                          final active = _activeSec == i;
                          // FIX: added missing `child:` parameter to AnimatedContainer
                          return InkWell(
                            onTap: () => _jumpTo(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: active
                                        ? cs.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                color: active
                                    ? cs.primary.withOpacity(.07)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sections[i].icon,
                                    size: 16,
                                    color: active
                                        ? cs.primary
                                        : cs.onSurface.withOpacity(.45),
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    _sections[i].label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                      color: active
                                          ? cs.primary
                                          : cs.onSurface.withOpacity(.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Form area
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPersonal(),
                            const SizedBox(height: 28),
                            _buildContact(),
                            const SizedBox(height: 28),
                            _buildIdentity(),
                            const SizedBox(height: 28),
                            _buildReferral(),
                            const SizedBox(height: 28),
                            _buildClinical(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(
                      top:
                          BorderSide(color: cs.outlineVariant.withOpacity(.5))),
                ),
                child: Row(
                  children: [
                    Text('* Full name is required',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(.45))),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.isReadOnly)
                      FilledButton.icon(
                        onPressed: _save,
                        icon: Icon(
                            isNew
                                ? Icons.person_add_outlined
                                : Icons.check_rounded,
                            size: 16),
                        label: Text(isNew ? 'Create patient' : 'Save changes'),
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String _filter = '';
  bool _sortAscending = true;
  int _rowsPerPage = 10;

  final Stream<QuerySnapshot> _patientsStream =
      FirebaseFirestore.instance.collection('patients').snapshots();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext ctx, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    final name = data?['fullName'] ?? 'Unnamed';
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete patient'),
        content: Text('Permanently remove "$name"? This cannot be undone.'),
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
            .showSnackBar(const SnackBar(content: Text('Patient deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BaseLayout(
      title: 'Patient Management',
      child: StreamBuilder<QuerySnapshot>(
        stream: _patientsStream,
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
                  return (m['fullName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q) ||
                      (m['mobile'] ?? '').toString().contains(q) ||
                      (m['email'] ?? '').toString().toLowerCase().contains(q) ||
                      (m['patient_id'] ?? '').toString().toLowerCase().contains(q);
                }).toList())
            ..sort((a, b) {
              final na = (a['fullName'] ?? '').toString();
              final nb = (b['fullName'] ?? '').toString();
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
                    // ── Top bar ───────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: cs.outlineVariant.withOpacity(.6)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                hintText: 'Search by name, ID, phone, or email…',
                                hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurface.withOpacity(.4)),
                                prefixIcon: Icon(Icons.search_rounded,
                                    size: 18,
                                    color: cs.onSurface.withOpacity(.4)),
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
                          onPressed: () => showPatientDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add patient'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Table ─────────────────────────────────────────────
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 40,
                                      color: cs.onSurface.withOpacity(.2)),
                                  const SizedBox(height: 8),
                                  Text('No patients found',
                                      style: TextStyle(
                                          color: cs.onSurface.withOpacity(.4))),
                                ],
                              ),
                            )
                          : PaginatedDataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              rowsPerPage: _rowsPerPage,
                              onRowsPerPageChanged: (v) {
                                if (v != null) setState(() => _rowsPerPage = v);
                              },
                              sortColumnIndex: 1,
                              sortAscending: _sortAscending,
                              columns: [
                                const DataColumn(label: Text('S.No')),
                                const DataColumn(label: Text('Patient ID')),
                                DataColumn(
                                  label: const Text('Full name'),
                                  onSort: (_, asc) =>
                                      setState(() => _sortAscending = asc),
                                ),
                                const DataColumn(label: Text('Phone')),
                                const DataColumn(label: Text('Email')),
                                const DataColumn(label: Text('Actions')),
                              ],
                              source: _PatientDataSource(
                                docs: filtered,
                                context: context,
                                onView: (d) => showPatientDialog(context,
                                    doc: d, isReadOnly: true),
                                onEdit: (d) =>
                                    showPatientDialog(context, doc: d),
                                onDelete: (d) => _confirmDelete(context, d),
                              ),
                            ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Data source
// ─────────────────────────────────────────────────────────────────────────────
class _PatientDataSource extends DataTableSource {
  _PatientDataSource({
    required this.docs,
    required this.context,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<DocumentSnapshot> docs;
  final BuildContext context;
  final void Function(DocumentSnapshot) onView, onEdit, onDelete;

  @override
  DataRow? getRow(int i) {
    if (i >= docs.length) return null;
    final doc = docs[i];
    final data = doc.data() as Map<String, dynamic>;
    final name = data['fullName'] ?? '';
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return DataRow.byIndex(
      index: i,
      cells: [
        DataCell(Text('${i + 1}',
            style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(.4)))),
        DataCell(Text(data['patient_id'] ?? '-',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        DataCell(Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ),
            const SizedBox(width: 10),
            Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        )),
        DataCell(
            Text(data['mobile'] ?? '', style: const TextStyle(fontSize: 13))),
        DataCell(
            Text(data['email'] ?? '', style: const TextStyle(fontSize: 13))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionBtn(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                onPressed: () => onView(doc)),
            _ActionBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onPressed: () => onEdit(doc)),
            _ActionBtn(
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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
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

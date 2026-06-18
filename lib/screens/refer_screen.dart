// lib/screens/refer_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _tabs = [
    (Icons.medical_services_outlined, 'Doctors'),
    (Icons.science_outlined, 'Labs'),
    (Icons.local_hospital_outlined, 'Hospitals'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BaseLayout(
      title: 'Referral Management',
      child: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────────────
          Container(
            color: cs.surfaceContainerLow,
            child: TabBar(
              controller: _tab,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: .55),
              indicatorColor: cs.primary,
              indicatorWeight: 2.5,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabs
                  .map((t) => Tab(icon: Icon(t.$1, size: 18), text: t.$2))
                  .toList(),
            ),
          ),
          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _DoctorsTab(),
                _LabsTab(),
                _HospitalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

String _getInitials(String name) {
  if (name.trim().isEmpty) return '?';
  return name
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
}

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.icon, required this.tip, required this.onTap, this.color});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 18, color: color),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );
}

Future<bool> _confirmDelete(BuildContext ctx, String name) async {
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Remove "$name"? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Standard search + table page wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _TabPage extends StatefulWidget {
  const _TabPage({
    required this.collection,
    required this.columns,
    required this.rowBuilder,
    required this.onAdd,
    required this.addLabel,
    this.filterFn,
  });

  final String collection;
  final List<DataColumn> columns;
  final DataRow? Function(int i, DocumentSnapshot doc) rowBuilder;
  final VoidCallback onAdd;
  final String addLabel;
  final bool Function(Map<String, dynamic> data, String q)? filterFn;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  String _q = '';
  int _rpp = 10;
  final bool _asc = true;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection(widget.collection).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final all = snap.data?.docs ?? [];
        final filtered = _q.isEmpty
            ? all
            : all.where((d) {
                final m = d.data() as Map<String, dynamic>;
                if (widget.filterFn != null) return widget.filterFn!(m, _q);
                return (m['name'] ?? '').toString().toLowerCase().contains(_q);
              }).toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Search + Add
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: .6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              hintText: 'Search…',
                              hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurface.withValues(alpha: .4)),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: .4)),
                              suffixIcon: _q.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          size: 16),
                                      onPressed: () => setState(() {
                                        _searchCtrl.clear();
                                        _q = '';
                                      }),
                                    )
                                  : null,
                            ),
                            onChanged: (v) =>
                                setState(() => _q = v.trim().toLowerCase()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: widget.onAdd,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(widget.addLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Table
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 40,
                                    color: cs.onSurface.withValues(alpha: .2)),
                                const SizedBox(height: 8),
                                Text('No records found',
                                    style: TextStyle(
                                        color: cs.onSurface
                                            .withValues(alpha: .4))),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: PaginatedDataTable(
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 56,
                                    rowsPerPage: _rpp,
                                    onRowsPerPageChanged: (v) {
                                      if (v != null) setState(() => _rpp = v);
                                    },
                                    sortColumnIndex: 0,
                                    sortAscending: _asc,
                                    columns: widget.columns,
                                    source: _DocSource(
                                      docs: filtered,
                                      rowBuilder: widget.rowBuilder,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DocSource extends DataTableSource {
  _DocSource({required this.docs, required this.rowBuilder});
  final List<DocumentSnapshot> docs;
  final DataRow? Function(int i, DocumentSnapshot doc) rowBuilder;

  @override
  DataRow? getRow(int i) => i < docs.length ? rowBuilder(i, docs[i]) : null;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => docs.length;
  @override
  int get selectedRowCount => 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Doctors
// ─────────────────────────────────────────────────────────────────────────────
class _DoctorsTab extends StatefulWidget {
  const _DoctorsTab();

  @override
  State<_DoctorsTab> createState() => _DoctorsTabState();
}

class _DoctorsTabState extends State<_DoctorsTab> {
  void _openDialog(List<DocumentSnapshot> hospitals, {DocumentSnapshot? doc}) {
    final data = doc == null ? null : doc.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: data?['email'] ?? '');
    final specialistCtrl =
        TextEditingController(text: data?['specialist'] ?? '');

    String? selectedHospital = data?['hospital'];
    if (selectedHospital != null && selectedHospital.isEmpty) {
      selectedHospital = null;
    }
    // Ensure the selected hospital exists in the list to avoid dropdown errors
    if (selectedHospital != null &&
        !hospitals.any((h) => h.id == selectedHospital)) {
      selectedHospital = null;
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text(doc == null ? 'Add Doctor' : 'Edit Doctor'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Doctor name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Phone', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Email', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: specialistCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Specialist / Specialty',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'Hospital',
                            border: OutlineInputBorder()),
                        initialValue: selectedHospital,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('None')),
                          ...hospitals.map((h) {
                            final hd = h.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: h.id,
                              child: Text(hd['name']?.toString() ?? 'Unknown'),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => selectedHospital = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final payload = {
                  'name': name,
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'specialist': specialistCtrl.text.trim(),
                  'hospital': selectedHospital ?? '',
                };
                final col = FirebaseFirestore.instance.collection('doctors');
                if (doc == null) {
                  await col.add(payload);
                } else {
                  await doc.reference.update(payload);
                }
                if (c.mounted) Navigator.pop(c);
              },
              child: Text(doc == null ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hospitals').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final hospitals = snapshot.data!.docs;
        final hospitalMap = {
          for (var h in hospitals)
            h.id: (h.data() as Map<String, dynamic>)['name']?.toString() ??
                'Unknown'
        };

        return _TabPage(
          collection: 'doctors',
          addLabel: 'Add Doctor',
          onAdd: () => _openDialog(hospitals),
          filterFn: (m, q) =>
              (m['name'] ?? '').toString().toLowerCase().contains(q) ||
              (m['phone'] ?? '').toString().toLowerCase().contains(q) ||
              (m['specialist'] ?? '').toString().toLowerCase().contains(q),
          columns: const [
            DataColumn(label: Text('S.No')),
            DataColumn(label: Text('Doctor name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Specialist')),
            DataColumn(label: Text('Hospital')),
            DataColumn(label: Text('Actions')),
          ],
          rowBuilder: (i, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final initials = _getInitials(name);
            final cs = Theme.of(context).colorScheme;

            final hospitalId = data['hospital'] ?? '';
            final hospitalName = hospitalId.isEmpty
                ? ''
                : (hospitalMap[hospitalId] ?? hospitalId);

            return DataRow.byIndex(
              index: i,
              cells: [
                DataCell(Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: .4)))),
                DataCell(Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primaryContainer,
                      child: Text(initials,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 10),
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                  ],
                )),
                DataCell(Text(data['phone'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(data['email'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(data['specialist'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(
                    Text(hospitalName, style: const TextStyle(fontSize: 13))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Btn(
                        icon: Icons.edit_outlined,
                        tip: 'Edit',
                        onTap: () => _openDialog(hospitals, doc: doc)),
                    _Btn(
                        icon: Icons.delete_outline_rounded,
                        tip: 'Delete',
                        color: Colors.redAccent,
                        onTap: () async {
                          if (await _confirmDelete(context, name)) {
                            await doc.reference.delete();
                          }
                        }),
                  ],
                )),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Labs
// ─────────────────────────────────────────────────────────────────────────────
class _LabsTab extends StatefulWidget {
  const _LabsTab();

  @override
  State<_LabsTab> createState() => _LabsTabState();
}

class _LabsTabState extends State<_LabsTab> {
  void _openDialog({DocumentSnapshot? doc}) {
    final data = doc == null ? null : doc.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: data?['email'] ?? '');
    final addressCtrl = TextEditingController(text: data?['address'] ?? '');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(doc == null ? 'Add Lab' : 'Edit Lab'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Lab name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final payload = {
                'name': name,
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
              };
              final col = FirebaseFirestore.instance.collection('labs');
              if (doc == null) {
                await col.add(payload);
              } else {
                await doc.reference.update(payload);
              }
              if (c.mounted) Navigator.pop(c);
            },
            child: Text(doc == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TabPage(
      collection: 'labs',
      addLabel: 'Add Lab',
      onAdd: () => _openDialog(),
      filterFn: (m, q) =>
          (m['name'] ?? '').toString().toLowerCase().contains(q) ||
          (m['phone'] ?? '').toString().toLowerCase().contains(q),
      columns: const [
        DataColumn(label: Text('S.No')),
        DataColumn(label: Text('Lab name')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Address')),
        DataColumn(label: Text('Actions')),
      ],
      rowBuilder: (i, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? '';
        final initials = _getInitials(name);
        final cs = Theme.of(context).colorScheme;
        return DataRow.byIndex(
          index: i,
          cells: [
            DataCell(Text('${i + 1}',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: .4)))),
            DataCell(Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 10),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
              ],
            )),
            DataCell(Text(data['phone'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Text(data['email'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Text(data['address'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Btn(
                    icon: Icons.edit_outlined,
                    tip: 'Edit',
                    onTap: () => _openDialog(doc: doc)),
                _Btn(
                    icon: Icons.delete_outline_rounded,
                    tip: 'Delete',
                    color: Colors.redAccent,
                    onTap: () async {
                      if (await _confirmDelete(context, name)) {
                        await doc.reference.delete();
                      }
                    }),
              ],
            )),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Hospitals
// ─────────────────────────────────────────────────────────────────────────────
class _HospitalsTab extends StatefulWidget {
  const _HospitalsTab();

  @override
  State<_HospitalsTab> createState() => _HospitalsTabState();
}

class _HospitalsTabState extends State<_HospitalsTab> {
  void _openDialog({DocumentSnapshot? doc}) {
    final data = doc == null ? null : doc.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: data?['email'] ?? '');
    final addressCtrl = TextEditingController(text: data?['address'] ?? '');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(doc == null ? 'Add Hospital' : 'Edit Hospital'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Hospital name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final payload = {
                'name': name,
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
              };
              final col = FirebaseFirestore.instance.collection('hospitals');
              if (doc == null) {
                await col.add(payload);
              } else {
                await doc.reference.update(payload);
              }
              if (c.mounted) Navigator.pop(c);
            },
            child: Text(doc == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TabPage(
      collection: 'hospitals',
      addLabel: 'Add Hospital',
      onAdd: () => _openDialog(),
      filterFn: (m, q) =>
          (m['name'] ?? '').toString().toLowerCase().contains(q) ||
          (m['phone'] ?? '').toString().toLowerCase().contains(q),
      columns: const [
        DataColumn(label: Text('S.No')),
        DataColumn(label: Text('Hospital name')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Address')),
        DataColumn(label: Text('Actions')),
      ],
      rowBuilder: (i, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? '';
        final initials = _getInitials(name);
        final cs = Theme.of(context).colorScheme;
        return DataRow.byIndex(
          index: i,
          cells: [
            DataCell(Text('${i + 1}',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: .4)))),
            DataCell(Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 10),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
              ],
            )),
            DataCell(Text(data['phone'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Text(data['email'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Text(data['address'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Btn(
                    icon: Icons.edit_outlined,
                    tip: 'Edit',
                    onTap: () => _openDialog(doc: doc)),
                _Btn(
                    icon: Icons.delete_outline_rounded,
                    tip: 'Delete',
                    color: Colors.redAccent,
                    onTap: () async {
                      if (await _confirmDelete(context, name)) {
                        await doc.reference.delete();
                      }
                    }),
              ],
            )),
          ],
        );
      },
    );
  }
}

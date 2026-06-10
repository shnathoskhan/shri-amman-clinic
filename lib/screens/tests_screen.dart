// lib/screens/tests_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _tabs = [
    (Icons.category_outlined, 'Departments'),
    (Icons.colorize_outlined, 'Sample Types'),
    (Icons.biotech_outlined, 'Parameters'),
    (Icons.playlist_add_check_outlined, 'Profiles'),
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
      title: 'Test Management',
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
                _SimpleNameTab(
                    collection: 'departments', singularLabel: 'Department'),
                _SimpleNameTab(
                    collection: 'sampleTypes', singularLabel: 'Sample Type'),
                _ParametersTab(),
                _ProfilesTab(),
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

/// Small icon-button used in action columns.
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

/// Confirm delete dialog.
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

/// Standard search + table page wrapper.
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
  bool _asc = true;
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
// Tab 1 & 2 — Simple name-only tables (Departments / Sample Types)
// ─────────────────────────────────────────────────────────────────────────────
class _SimpleNameTab extends StatefulWidget {
  const _SimpleNameTab({required this.collection, required this.singularLabel});
  final String collection;
  final String singularLabel;

  @override
  State<_SimpleNameTab> createState() => _SimpleNameTabState();
}

class _SimpleNameTabState extends State<_SimpleNameTab> {
  void _openDialog({DocumentSnapshot? doc}) {
    final ctrl = TextEditingController(
        text: doc == null
            ? ''
            : (doc.data() as Map<String, dynamic>)['name'] ?? '');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(doc == null
            ? 'Add ${widget.singularLabel}'
            : 'Edit ${widget.singularLabel}'),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Name',
              border: const OutlineInputBorder(),
              hintText: 'e.g. ${widget.singularLabel} name',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final col =
                  FirebaseFirestore.instance.collection(widget.collection);
              if (doc == null) {
                await col.add({'name': name});
              } else {
                await doc.reference.update({'name': name});
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
      collection: widget.collection,
      addLabel: 'Add ${widget.singularLabel}',
      onAdd: () => _openDialog(),
      columns: const [
        DataColumn(label: Text('S.No')),
        DataColumn(label: Text('Name')),
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
// Tab 3 — Parameters (name, unit, reference range)
// ─────────────────────────────────────────────────────────────────────────────
class _ParametersTab extends StatefulWidget {
  const _ParametersTab();

  @override
  State<_ParametersTab> createState() => _ParametersTabState();
}

class _ParametersTabState extends State<_ParametersTab> {
  void _openDialog({DocumentSnapshot? doc}) {
    final data = doc == null ? null : doc.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final unitCtrl = TextEditingController(text: data?['unit'] ?? '');
    final rangeCtrl =
        TextEditingController(text: data?['referenceRange'] ?? '');
    final priceCtrl =
        TextEditingController(text: data?['price']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(doc == null ? 'Add Parameter' : 'Edit Parameter'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Parameter name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'e.g. mg/dL',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rangeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Reference range',
                          hintText: 'e.g. 70–100',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Price (₹)',
                    hintText: 'e.g. 150',
                    border: OutlineInputBorder()),
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
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final payload = {
                'name': name,
                'unit': unitCtrl.text.trim(),
                'referenceRange': rangeCtrl.text.trim(),
                'price': price,
              };
              if (doc == null) {
                await FirebaseFirestore.instance
                    .collection('parameters')
                    .add(payload);
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
      collection: 'parameters',
      addLabel: 'Add Parameter',
      onAdd: () => _openDialog(),
      filterFn: (m, q) =>
          (m['name'] ?? '').toString().toLowerCase().contains(q) ||
          (m['unit'] ?? '').toString().toLowerCase().contains(q),
      columns: const [
        DataColumn(label: Text('S.No')),
        DataColumn(label: Text('Parameter name')),
        DataColumn(label: Text('Unit')),
        DataColumn(label: Text('Reference range')),
        DataColumn(label: Text('Price')),
        DataColumn(label: Text('Actions')),
      ],
      rowBuilder: (i, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? '';
        final price = data['price'] ?? 0.0;
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
            DataCell(
                Text(data['unit'] ?? '', style: const TextStyle(fontSize: 13))),
            DataCell(Text(data['referenceRange'] ?? '',
                style: const TextStyle(fontSize: 13))),
            DataCell(Text(
                '₹${price is num ? (price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2)) : price}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500))),
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
// Tab 4 — Profiles (title + assigned parameters)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfilesTab extends StatefulWidget {
  const _ProfilesTab();

  @override
  State<_ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<_ProfilesTab> {
  void _openDialog({DocumentSnapshot? doc}) {
    final data = doc == null ? null : doc.data() as Map<String, dynamic>?;
    final titleCtrl = TextEditingController(text: data?['title'] ?? '');

    // Pre-populate selected parameters from the doc.
    final existingParams = (data?['parameters'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => _ProfileDialog(
        titleCtrl: titleCtrl,
        initialParams: existingParams,
        doc: doc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TabPage(
      collection: 'profiles',
      addLabel: 'Add Profile',
      onAdd: () => _openDialog(),
      filterFn: (m, q) =>
          (m['title'] ?? '').toString().toLowerCase().contains(q),
      columns: const [
        DataColumn(label: Text('S.No')),
        DataColumn(label: Text('Profile title')),
        DataColumn(label: Text('Parameters')),
        DataColumn(label: Text('Actions')),
      ],
      rowBuilder: (i, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title'] ?? '';
        final params =
            (data['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final initials = _getInitials(title);
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
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
              ],
            )),
            DataCell(
              params.isEmpty
                  ? Text('—',
                      style:
                          TextStyle(color: cs.onSurface.withValues(alpha: .4)))
                  : Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: params
                          .map((p) => Chip(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                label: Text(p['name'] ?? '',
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
            ),
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
                      if (await _confirmDelete(context, title)) {
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
// Profile add/edit dialog (stateful — needs its own widget for checkbox state)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.titleCtrl,
    required this.initialParams,
    this.doc,
  });
  final TextEditingController titleCtrl;
  final List<Map<String, dynamic>> initialParams;
  final DocumentSnapshot? doc;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final List<Map<String, dynamic>> _selected;
  String _paramSearch = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialParams);
  }

  bool _isSelected(String id) => _selected.any((p) => p['id'] == id);

  void _toggle(DocumentSnapshot paramDoc) {
    final data = paramDoc.data() as Map<String, dynamic>;
    setState(() {
      if (_isSelected(paramDoc.id)) {
        _selected.removeWhere((p) => p['id'] == paramDoc.id);
      } else {
        _selected.add({
          'id': paramDoc.id,
          'name': data['name'] ?? '',
          'unit': data['unit'] ?? '',
          'referenceRange': data['referenceRange'] ?? '',
          'price': data['price'] ?? 0.0,
        });
      }
    });
  }

  Future<void> _save() async {
    final title = widget.titleCtrl.text.trim();
    if (title.isEmpty) return;
    final payload = {
      'title': title,
      'parameters': _selected,
    };
    if (widget.doc == null) {
      await FirebaseFirestore.instance.collection('profiles').add(payload);
    } else {
      await widget.doc!.reference.update(payload);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNew = widget.doc == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: cs.surfaceContainerLow,
              child: Row(
                children: [
                  Icon(Icons.playlist_add_check_outlined,
                      color: cs.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(isNew ? 'Add Profile' : 'Edit Profile',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      controller: widget.titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Profile title',
                        hintText: 'e.g. Lipid Profile, CBC…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Parameter picker label + search
                    Text('Assign parameters',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .5,
                            color: cs.primary)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter parameters…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 17),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (v) =>
                          setState(() => _paramSearch = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),

                    // Checkboxes list
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('parameters')
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2));
                          }
                          final all = snap.data?.docs ?? [];
                          final visible = _paramSearch.isEmpty
                              ? all
                              : all.where((d) {
                                  final m = d.data() as Map<String, dynamic>;
                                  return (m['name'] ?? '')
                                      .toString()
                                      .toLowerCase()
                                      .contains(_paramSearch);
                                }).toList();

                          if (visible.isEmpty) {
                            return Center(
                              child: Text('No parameters found',
                                  style: TextStyle(
                                      color:
                                          cs.onSurface.withValues(alpha: .4))),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: .6)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color:
                                      cs.outlineVariant.withValues(alpha: .4)),
                              itemBuilder: (_, i) {
                                final d = visible[i];
                                final m = d.data() as Map<String, dynamic>;
                                final name = m['name'] ?? '';
                                final unit = m['unit'] ?? '';
                                final range = m['referenceRange'] ?? '';
                                final sel = _isSelected(d.id);
                                return CheckboxListTile(
                                  dense: true,
                                  value: sel,
                                  onChanged: (_) => _toggle(d),
                                  title: Text(name,
                                      style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(
                                    [
                                      if (unit.isNotEmpty) unit,
                                      if (range.isNotEmpty) range,
                                      '₹${m['price'] ?? 0}',
                                    ].join(' · '),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            cs.onSurface.withValues(alpha: .5)),
                                  ),
                                  activeColor: cs.primary,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Selected count chip
                    if (_selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_selected.length} parameter(s) assigned',
                          style: TextStyle(fontSize: 12, color: cs.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: cs.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(isNew ? Icons.add_rounded : Icons.check_rounded,
                        size: 16),
                    label: Text(isNew ? 'Create profile' : 'Save changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

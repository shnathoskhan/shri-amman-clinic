// lib/screens/admin/branch_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({Key? key}) : super(key: key);

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  // Filtering
  String _filter = '';
  // Sorting
  final bool _sortAscending = true;
  // Rows per page (default 10, max 50)
  int _rowsPerPage = 10;

  final Stream<QuerySnapshot> _branchesStream =
      FirebaseFirestore.instance.collection('branches').snapshots();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showBranchDialog(BuildContext context,
      {DocumentSnapshot? doc, bool isReadOnly = false}) async {
    final nameCtrl =
        TextEditingController(text: doc != null ? doc['name'] ?? '' : '');
    final buildingFlatCtrl = TextEditingController(
        text: doc != null ? doc['buildingFlat'] ?? '' : '');
    final streetCtrl =
        TextEditingController(text: doc != null ? doc['street'] ?? '' : '');
    final areaCtrl =
        TextEditingController(text: doc != null ? doc['area'] ?? '' : '');
    final cityCtrl =
        TextEditingController(text: doc != null ? doc['city'] ?? '' : '');
    final stateCtrl =
        TextEditingController(text: doc != null ? doc['state'] ?? '' : '');
    final countryCtrl =
        TextEditingController(text: doc != null ? doc['country'] ?? '' : '');
    final postcodeCtrl =
        TextEditingController(text: doc != null ? doc['postcode'] ?? '' : '');
    final contactCtrl =
        TextEditingController(text: doc != null ? doc['contact'] ?? '' : '');
    final emailCtrl =
        TextEditingController(text: doc != null ? doc['email'] ?? '' : '');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isReadOnly
            ? 'View Branch'
            : (doc == null ? 'Add Branch' : 'Edit Branch')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contactCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Contact / Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: buildingFlatCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Building/Flat',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: streetCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Street',
                  prefixIcon: Icon(Icons.add_road_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Area',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cityCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stateCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'State',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: countryCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: postcodeCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Postcode',
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          if (isReadOnly)
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Close'),
            )
          else ...[
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'buildingFlat': buildingFlatCtrl.text.trim(),
                  'street': streetCtrl.text.trim(),
                  'area': areaCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'state': stateCtrl.text.trim(),
                  'country': countryCtrl.text.trim(),
                  'postcode': postcodeCtrl.text.trim(),
                  'contact': contactCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                };
                if (doc == null) {
                  final docRef = await FirebaseFirestore.instance
                      .collection('branches')
                      .add(data);
                  await docRef.update({'id': docRef.id});
                } else {
                  await doc.reference.update(data);
                }
                if (c.mounted) {
                  Navigator.of(c).pop();
                }
              },
              child: Text(doc == null ? 'Create' : 'Save'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    final name = data != null ? data['name'] ?? 'Unnamed' : 'Unnamed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete branch "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await doc.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch deleted successfully')),
        );
      }
    }
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            labelText: 'Search by name, email, contact or address',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _filter.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchCtrl.clear();
                        _filter = '';
                      });
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() {
              _filter = val.trim().toLowerCase();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Branch Management',
      child: StreamBuilder<QuerySnapshot>(
        stream: _branchesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final allDocs = snapshot.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No branches found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showBranchDialog(context),
                    label: const Text('Add Branch'),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            );
          }
          // Apply filter (case‑insensitive contains on name, email, contact, or address fields)
          final filtered = _filter.isEmpty
              ? allDocs
              : allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final contact =
                      (data['contact'] ?? '').toString().toLowerCase();
                  final city = (data['city'] ?? '').toString().toLowerCase();
                  final area = (data['area'] ?? '').toString().toLowerCase();
                  return name.contains(_filter) ||
                      email.contains(_filter) ||
                      contact.contains(_filter) ||
                      city.contains(_filter) ||
                      area.contains(_filter);
                }).toList();

          // Apply sorting by name
          filtered.sort((a, b) {
            final nameA = (a['name'] ?? '').toString();
            final nameB = (b['name'] ?? '').toString();
            return _sortAscending
                ? nameA.compareTo(nameB)
                : nameB.compareTo(nameA);
          });

          final dataSource = _BranchDataSource(
            docs: filtered,
            context: context,
            onView: (doc) =>
                _showBranchDialog(context, doc: doc, isReadOnly: true),
            onEdit: (doc) =>
                _showBranchDialog(context, doc: doc, isReadOnly: false),
            onDelete: (doc) => _showDeleteConfirmation(context, doc),
            sortAscending: _sortAscending,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchCard(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No branches match your search',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Theme(
                              data: Theme.of(context).copyWith(
                                cardTheme: CardThemeData(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: PaginatedDataTable(
                                  header: const Text(
                                    'Branches',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  actions: [
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _showBranchDialog(context),
                                      label: const Text('Add Branch'),
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                  rowsPerPage: _rowsPerPage,
                                  onRowsPerPageChanged: (value) {
                                    if (value != null && value <= 50) {
                                      setState(() => _rowsPerPage = value);
                                    }
                                  },
                                  sortColumnIndex: 1,
                                  sortAscending: _sortAscending,
                                  onSelectAll: null,
                                  columns: const [
                                    DataColumn(label: Text('S.No')),
                                    DataColumn(label: Text('Full Name')),
                                    DataColumn(label: Text('Phone')),
                                    DataColumn(label: Text('Email')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  source: dataSource,
                                ),
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

// Data source for the PaginatedDataTable
class _BranchDataSource extends DataTableSource {
  final List<DocumentSnapshot> docs;
  final BuildContext context;
  final Function(DocumentSnapshot) onView;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;
  final bool sortAscending;

  _BranchDataSource({
    required this.docs,
    required this.context,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.sortAscending,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= docs.length) return null;
    final doc = docs[index];
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unnamed';
    final email = data['email'] ?? '';
    final phone = data['contact'] ?? '';
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text((index + 1).toString())),
        DataCell(Text(name)),
        DataCell(Text(phone)),
        DataCell(Text(email)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'View',
              onPressed: () => onView(doc),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => onEdit(doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete',
              onPressed: () => onDelete(doc),
            ),
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

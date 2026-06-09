// lib/screens/admin/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shri_amman_clinic/widgets/base_layout.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // Filtering
  String _filter = '';
  // Sorting
  bool _sortAscending = true;
  // Rows per page (default 10, max 50)
  int _rowsPerPage = 10; // default rows per page

  final Stream<QuerySnapshot> _usersStream =
      FirebaseFirestore.instance.collection('users').snapshots();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Dialog for adding / editing / viewing a user
  Future<void> _showUserDialog(BuildContext context,
      {DocumentSnapshot? doc, bool isReadOnly = false}) async {
    final emailCtrl =
        TextEditingController(text: doc != null ? doc['email'] ?? '' : '');
    final nameCtrl =
        TextEditingController(text: doc != null ? doc['name'] ?? '' : '');
    final roleCtrl = TextEditingController(
        text: doc != null ? doc['role'] ?? 'employee' : 'employee');
    final phoneCtrl = TextEditingController(
        text: doc != null ? doc['phone']?.replaceFirst('+91', '') ?? '' : '');
    // Load branches for selection
    final branchesSnapshot =
        await FirebaseFirestore.instance.collection('branches').get();
    final branchItems = branchesSnapshot.docs;
    String selectedBranchId = doc != null
        ? doc['branch'] ?? ''
        : (branchItems.isNotEmpty ? branchItems.first.id : '');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isReadOnly
            ? 'View User'
            : (doc == null ? 'Add User' : 'Edit User')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                readOnly: doc != null || isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: roleCtrl.text.isNotEmpty ? roleCtrl.text : null,
                items: ['employee', 'admin']
                    .map((r) =>
                        DropdownMenuItem<String>(value: r, child: Text(r)))
                    .toList(),
                onChanged: isReadOnly
                    ? null
                    : (val) => roleCtrl.text = val ?? 'employee',
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                  enabled: !isReadOnly,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                readOnly: isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Phone (without +91)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    selectedBranchId.isNotEmpty ? selectedBranchId : null,
                items: branchItems
                    .map((b) => DropdownMenuItem<String>(
                        value: b.id, child: Text(b['name'] ?? 'Branch')))
                    .toList(),
                onChanged:
                    isReadOnly ? null : (val) => selectedBranchId = val ?? '',
                decoration: InputDecoration(
                  labelText: 'Branch',
                  prefixIcon: const Icon(Icons.business_outlined),
                  enabled: !isReadOnly,
                ),
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
                final email = emailCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final role = roleCtrl.text.trim();
                final phone = '+91${phoneCtrl.text.trim()}';
                final branchId = selectedBranchId;

                if (doc == null) {
                  // Create Auth user then Firestore entry
                  try {
                    final cred = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(
                      email: email,
                      password: 'SAC@12345',
                    );
                    final uid = cred.user?.uid ?? '';
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .set({
                      'uid': uid,
                      'email': email,
                      'name': name,
                      'role': role,
                      'phone': phone,
                      'branch': branchId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                } else {
                  await doc.reference.update({
                    'email': email,
                    'name': name,
                    'role': role,
                    'phone': phone,
                    'branch': branchId,
                  });
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
        content: Text('Are you sure you want to delete user "$name"?'),
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
          const SnackBar(content: Text('User deleted successfully')),
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
            labelText: 'Search by name, email or phone',
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
      title: 'User Management',
      child: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final allDocs = snapshot.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          // Apply filter (case‑insensitive contains on name, email or phone)
          final filtered = _filter.isEmpty
              ? allDocs
              : allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(_filter) ||
                      email.contains(_filter) ||
                      phone.contains(_filter);
                }).toList();
          // Apply sorting by name
          filtered.sort((a, b) {
            final nameA = (a['name'] ?? '').toString();
            final nameB = (b['name'] ?? '').toString();
            return _sortAscending
                ? nameA.compareTo(nameB)
                : nameB.compareTo(nameA);
          });

          final dataSource = _UserDataSource(
            docs: filtered,
            context: context,
            onView: (doc) =>
                _showUserDialog(context, doc: doc, isReadOnly: true),
            onEdit: (doc) =>
                _showUserDialog(context, doc: doc, isReadOnly: false),
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
                                    'No users match your search',
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
                                    'Users',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  actions: [
                                    FilledButton.icon(
                                      onPressed: () => _showUserDialog(context),
                                      label: const Text('Add User'),
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
                                  columns: [
                                    const DataColumn(label: Text('S.No')),
                                    DataColumn(
                                      label: const Text('Name'),
                                      numeric: false,
                                      onSort: (columnIndex, ascending) {
                                        setState(() {
                                          _sortAscending = ascending;
                                        });
                                      },
                                    ),
                                    const DataColumn(label: Text('Email')),
                                    const DataColumn(label: Text('Phone')),
                                    const DataColumn(label: Text('Actions')),
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
class _UserDataSource extends DataTableSource {
  final List<DocumentSnapshot> docs;
  final BuildContext context;
  final Function(DocumentSnapshot) onView;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;
  final bool sortAscending;

  _UserDataSource({
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
    final phone = data['phone'] ?? '';
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text((index + 1).toString())),
        DataCell(Text(name)),
        DataCell(Text(email)),
        DataCell(Text(phone)),
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

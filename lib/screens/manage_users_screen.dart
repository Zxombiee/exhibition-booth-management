import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _query  = '';
  String _filter = 'all'; // all | exhibitor | organizer | admin

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':     return Colors.red;
      case 'organizer': return Colors.orange;
      default:          return Colors.blue;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':     return Icons.admin_panel_settings_outlined;
      case 'organizer': return Icons.manage_accounts_outlined;
      default:          return Icons.business_center_outlined;
    }
  }

  Future<void> _changeRole(String uid, String currentRole, String name) async {
    final roles = ['exhibitor', 'organizer', 'admin'];
    String selected = currentRole;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Change role for $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((r) {
              final c = _roleColor(r);
              return RadioListTile<String>(
                value: r,
                groupValue: selected,
                activeColor: c,
                title: Text(r.toUpperCase(),
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: c)),
                onChanged: (v) => setS(() => selected = v!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selected == currentRole) return;

    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .update({'role': selected});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name role changed to $selected'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _deleteUser(String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "$name"?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                    'This only removes the user record. '
                        'Their auth account remains active.',
                    style: TextStyle(fontSize: 12))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('users').doc(uid).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$name" removed'),
        backgroundColor: Colors.red.shade400,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Manage Users',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: Column(children: [
        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: const TextStyle(
                  color: Color(0xFF90A4AE), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF90A4AE), size: 20),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                  child: const Icon(Icons.close,
                      color: Color(0xFF90A4AE), size: 18))
                  : null,
              filled: true, fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [
                ('all', 'All'),
                ('exhibitor', 'Exhibitor'),
                ('organizer', 'Organizer'),
                ('admin', 'Admin'),
              ])
                Padding(padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                            color: _filter == f.$1
                                ? _kBlue : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _filter == f.$1 ? _kBlue : _kBorder)),
                        child: Text(f.$2, style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _filter == f.$1
                                ? Colors.white : const Color(0xFF546E7A))),
                      ),
                    )),
            ]),
          ),
        ),
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kBlue));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }

              final docs = (snap.data?.docs ?? []).where((doc) {
                final d    = doc.data() as Map<String, dynamic>;
                final name  = (d['name']  ?? '').toString().toLowerCase();
                final email = (d['email'] ?? '').toString().toLowerCase();
                final role  = (d['role']  ?? 'exhibitor').toString();

                if (_filter != 'all' && role != _filter) return false;
                if (_query.isNotEmpty &&
                    !name.contains(_query) && !email.contains(_query))
                  return false;
                return true;
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 56,
                        color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(_query.isNotEmpty
                        ? 'No users match "$_query"'
                        : 'No $_filter users',
                        style: const TextStyle(fontSize: 15,
                            color: Color(0xFF37474F))),
                  ],
                ));
              }

              // Summary counts
              final allDocs = snap.data?.docs ?? [];
              final counts = <String, int>{};
              for (final d in allDocs) {
                final role = (d.data() as Map)['role'] ?? 'exhibitor';
                counts[role] = (counts[role] ?? 0) + 1;
              }

              return Column(children: [
                // Summary bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Text('${allDocs.length} total users',
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFF546E7A),
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    for (final r in ['exhibitor', 'organizer', 'admin'])
                      Padding(padding: const EdgeInsets.only(left: 10),
                        child: Text(
                            '${counts[r] ?? 0} ${r}s',
                            style: TextStyle(fontSize: 11,
                                color: _roleColor(r),
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),
                const Divider(height: 1, color: Color(0xFFECEFF1)),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc  = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final uid  = doc.id;
                      final name  = data['name']        ?? 'No name';
                      final email = data['email']       ?? '';
                      final role  = data['role']        ?? 'exhibitor';
                      final company = data['companyName'] as String?;
                      final createdAt =
                      (data['createdAt'] as Timestamp?)?.toDate();
                      final rc = _roleColor(role);
                      final fmt = DateFormat('d MMM yyyy');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                              14, 8, 10, 8),
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: rc.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_roleIcon(role),
                                color: rc, size: 22),
                          ),
                          title: Text(name,
                              style: const TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A237E))),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(email,
                                  style: const TextStyle(fontSize: 12,
                                      color: Color(0xFF78909C))),
                              if (company != null && company.isNotEmpty)
                                Text(company,
                                    style: const TextStyle(fontSize: 11,
                                        color: Color(0xFF90A4AE))),
                              if (createdAt != null)
                                Text('Joined ${fmt.format(createdAt)}',
                                    style: const TextStyle(fontSize: 10,
                                        color: Color(0xFFB0BEC5))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Role badge
                              GestureDetector(
                                onTap: () => _changeRole(uid, role, name),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: rc.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: rc.withOpacity(0.4)),
                                  ),
                                  child: Text(role.toUpperCase(),
                                      style: TextStyle(fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: rc)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Delete
                              GestureDetector(
                                onTap: () => _deleteUser(uid, name),
                                child: Icon(Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red.shade300),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
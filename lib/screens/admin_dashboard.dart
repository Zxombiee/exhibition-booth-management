import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_router.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int  _totalEvents   = 0;
  int  _totalUsers    = 0;
  int  _totalBookings = 0;
  bool _loading       = true;

  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final e = await FirebaseFirestore.instance.collection('exhibitions').get();
      final u = await FirebaseFirestore.instance.collection('users').get();
      final b = await FirebaseFirestore.instance
          .collection('applications')
          .where('status', isEqualTo: 'approved')
          .get();
      if (!mounted) return;
      setState(() {
        _totalEvents   = e.docs.length;
        _totalUsers    = u.docs.length;
        _totalBookings = b.docs.length;
        _loading       = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go(AppRoutes.guest);
  }

  Future<List<Map<String, dynamic>>> _getExhibitions() async {
    final snap = await FirebaseFirestore.instance
        .collection('exhibitions').get();
    return snap.docs.map((doc) => {
      'id':    doc.id,
      'name':  doc.data()['name']  ?? 'Unnamed',
      'venue': doc.data()['venue'] ?? '',
    }).toList();
  }

  void _selectExhibition() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Exhibition'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getExhibitions(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 80,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (!snap.hasData || snap.data!.isEmpty) {
                return const Text('No exhibitions found.');
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: snap.data!.map((ex) => ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(ex['name']),
                      subtitle: Text(ex['venue']),
                      onTap: () {
                        context.pop();
                        context.push(
                          AppRoutes.adminFloorPlanPath(ex['id']),
                          extra: {'exhibitionName': ex['name']},
                        );
                      },
                    )).toList(),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: _loadStats,
              tooltip: 'Refresh'),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Banner ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Panel',
                          style: TextStyle(color: Colors.white,
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(email,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Stats ────────────────────────────────────
              Row(children: [
                _StatTile(
                  label: 'Events',
                  value: _loading ? null : '$_totalEvents',
                  icon: Icons.event_outlined,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  label: 'Users',
                  value: _loading ? null : '$_totalUsers',
                  icon: Icons.people_outline,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  label: 'Approved',
                  value: _loading ? null : '$_totalBookings',
                  icon: Icons.bookmark_outlined,
                  color: Colors.purple,
                ),
              ]),
              const SizedBox(height: 24),

              // ── Management cards ──────────────────────────
              const Text('Management',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E))),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ManageCard(
                    icon: Icons.event_outlined,
                    title: 'Manage\nExhibitions',
                    color: Colors.blue,
                    onTap: () => context.push(AppRoutes.manageExhibitions),
                  ),
                  _ManageCard(
                    icon: Icons.map_outlined,
                    title: 'Floor Plan\nManagement',
                    color: Colors.green,
                    onTap: _selectExhibition,
                  ),
                  _ManageCard(
                    icon: Icons.people_outline,
                    title: 'Manage\nUsers',
                    color: Colors.orange,
                    onTap: () => context.push(AppRoutes.manageUsers),
                  ),
                  _ManageCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'All\nReservations',
                    color: Colors.purple,
                    onTap: () => context.push(AppRoutes.allReservations),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Recent applications ───────────────────────
              const Text('Recent Applications',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E))),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('applications')
                    .orderBy('submittedAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Center(child: Text(
                          'No applications yet',
                          style: TextStyle(color: Color(0xFF78909C)))),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      children: docs.asMap().entries.map((entry) {
                        final data =
                        entry.value.data() as Map<String, dynamic>;
                        final company  = data['companyName']   ?? 'Unknown';
                        final status   = data['status']        ?? 'pending';
                        final exName   = data['exhibitionName'] ?? '';
                        final isLast   = entry.key == docs.length - 1;
                        final sc = status == 'approved'
                            ? Colors.green
                            : status == 'rejected'
                            ? Colors.red : Colors.orange;
                        return Column(children: [
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: sc.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.business,
                                  color: sc, size: 17),
                            ),
                            title: Text(company,
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(exName,
                                style: const TextStyle(fontSize: 11,
                                    color: Color(0xFF78909C))),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sc.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sc.withOpacity(0.4)),
                              ),
                              child: Text(status.toUpperCase(),
                                  style: TextStyle(fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: sc)),
                            ),
                          ),
                          if (!isLast)
                            const Divider(height: 1,
                                color: Color(0xFFECEFF1), indent: 16),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String? value; // null = loading
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCDD5E0)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          value == null
              ? SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color))
              : Text(value!,
              style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10,
                  color: Color(0xFF78909C))),
        ]),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ManageCard({
    required this.icon, required this.title,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDD5E0)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37474F))),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
// PENDING APPLICATIONS SCREEN  (Organizer)
// ─────────────────────────────────────────────────────────────
class PendingApplicationsScreen extends StatefulWidget {
  const PendingApplicationsScreen({super.key});

  @override
  State<PendingApplicationsScreen> createState() =>
      _PendingApplicationsScreenState();
}

class _PendingApplicationsScreenState
    extends State<PendingApplicationsScreen>
    with SingleTickerProviderStateMixin {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  List<String> _eventIds = [];
  bool _loadingIds = true;
  late final TabController _tabCtrl;

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadEventIds();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEventIds() async {
    final snap = await FirebaseFirestore.instance
        .collection('exhibitions')
        .where('organizerId', isEqualTo: _uid)
        .get();
    setState(() {
      _eventIds   = snap.docs.map((d) => d.id).toList();
      _loadingIds = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Applications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            Container(height: 1, color: _kBorder),
            TabBar(
              controller: _tabCtrl,
              labelColor: _kBlue,
              unselectedLabelColor: const Color(0xFF78909C),
              indicatorColor: _kBlue,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'Rejected'),
              ],
            ),
          ]),
        ),
      ),
      body: _loadingIds
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _eventIds.isEmpty
          ? _buildNoEvents()
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _ApplicationList(
              eventIds: _eventIds, status: 'pending'),
          _ApplicationList(
              eventIds: _eventIds, status: 'approved'),
          _ApplicationList(
              eventIds: _eventIds, status: 'rejected'),
        ],
      ),
    );
  }

  Widget _buildNoEvents() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.event_busy, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No events created yet',
            style: TextStyle(fontSize: 15, color: Color(0xFF37474F))),
        const SizedBox(height: 6),
        const Text('Create an event first to receive applications',
            style: TextStyle(fontSize: 13, color: Color(0xFF78909C))),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// APPLICATION LIST  (one per tab)
// ─────────────────────────────────────────────────────────────
class _ApplicationList extends StatelessWidget {
  final List<String> eventIds;
  final String status;

  const _ApplicationList({
    required this.eventIds,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('exhibitionId', whereIn: eventIds)
          .where('status', isEqualTo: status)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1565C0)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_emptyIcon(status), size: 56,
                    color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No $status applications',
                    style: const TextStyle(fontSize: 15,
                        color: Color(0xFF37474F))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) => _AppCard(
              doc: docs[i], status: status),
        );
      },
    );
  }

  IconData _emptyIcon(String s) {
    switch (s) {
      case 'approved': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      default:         return Icons.inbox_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// APPLICATION CARD
// ─────────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String status;

  static const _kBorder = Color(0xFFCDD5E0);

  const _AppCard({required this.doc, required this.status});

  Color get _statusColor {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  Future<void> _approve(BuildContext context, String appId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Application'),
        content: const Text('Approve this booth application?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green),
            child: const Text('Approve',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('applications').doc(appId)
          .update({'status': 'approved'});

      // Update booth statuses to booked
      final appDoc = await FirebaseFirestore.instance
          .collection('applications').doc(appId).get();
      final appData = appDoc.data() as Map<String, dynamic>;
      final booths  = appData['booths'] as List? ?? [];
      final exId    = appData['exhibitionId'] as String?;

      for (final b in booths) {
        final bNum = b['boothNumber'] as String?;
        if (bNum == null || exId == null) continue;
        final bSnap = await FirebaseFirestore.instance
            .collection('booths')
            .where('exhibitionId', isEqualTo: exId)
            .where('boothNumber', isEqualTo: bNum)
            .get();
        for (final bd in bSnap.docs) {
          await bd.reference.update({'status': 'booked'});
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application approved!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject(BuildContext context, String appId) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide a reason for rejection:'),
          const SizedBox(height: 10),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g., Booth already taken',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please provide a reason'),
            backgroundColor: Colors.orange));
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('applications').doc(appId)
          .update({'status': 'rejected', 'rejectionReason': reason});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application rejected'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
    reasonCtrl.dispose();
  }

  Future<void> _cancel(BuildContext context, String appId,
      List booths, String exId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
            'Cancel this approved booking? Booths will be released.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('applications').doc(appId)
          .update({'status': 'rejected',
        'rejectionReason': 'Cancelled by organizer'});

      // Release booths
      for (final b in booths) {
        final bNum = b['boothNumber'] as String?;
        if (bNum == null) continue;
        final bSnap = await FirebaseFirestore.instance
            .collection('booths')
            .where('exhibitionId', isEqualTo: exId)
            .where('boothNumber', isEqualTo: bNum)
            .get();
        for (final bd in bSnap.docs) {
          await bd.reference.update({'status': 'available'});
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data          = doc.data() as Map<String, dynamic>;
    final appId         = doc.id;
    final companyName   = data['companyName']   ?? 'Unknown Company';
    final exName        = data['exhibitionName'] ?? '';
    final companyDesc   = data['companyDescription'] ?? '';
    final exhibitProfile = data['exhibitProfile'] ?? '';
    final booths        = data['booths'] as List? ?? [];
    final addons        = data['addons']  as List? ?? [];
    final totalPrice    = (data['totalPrice'] as num?)?.toDouble() ?? 0;
    final submittedAt   = (data['submittedAt'] as Timestamp?)?.toDate();
    final rejReason     = data['rejectionReason'] as String?;
    final exId          = data['exhibitionId'] as String? ?? '';
    final fmt           = DateFormat('d MMM yyyy, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.business,
                    color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E))),
                  const SizedBox(height: 2),
                  Text(exName, style: const TextStyle(
                      fontSize: 12, color: Color(0xFF78909C))),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _statusColor.withOpacity(0.4)),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _statusColor)),
              ),
            ]),
          ),

          const Divider(height: 1, color: Color(0xFFECEFF1)),

          // ── Details ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Booths
                _infoRow(Icons.event_seat_outlined,
                    booths.map((b) =>
                    '${b['boothNumber']} (${b['type']}, RM${(b['price'] as num).toInt()})'
                    ).join(', ')),
                const SizedBox(height: 6),

                // Total
                _infoRow(Icons.payments_outlined,
                    'Total: RM${totalPrice.toInt()}'),
                const SizedBox(height: 6),

                // Submitted date
                if (submittedAt != null)
                  _infoRow(Icons.schedule_outlined,
                      'Submitted: ${fmt.format(submittedAt)}'),

                // Add-ons
                if (addons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.add_box_outlined,
                      'Add-ons: ${addons.join(', ')}'),
                ],

                // Company description
                if (companyDesc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Company Description',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F))),
                  const SizedBox(height: 4),
                  Text(companyDesc,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF546E7A))),
                ],

                // Exhibit profile
                if (exhibitProfile.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Exhibit Profile',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F))),
                  const SizedBox(height: 4),
                  Text(exhibitProfile,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF546E7A))),
                ],

                // Rejection reason
                if (status == 'rejected' && rejReason != null
                    && rejReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 14,
                          color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Reason: $rejReason',
                          style: TextStyle(fontSize: 12,
                              color: Colors.red.shade700))),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────
          if (status == 'pending') ...[
            const Divider(height: 1, color: Color(0xFFECEFF1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => _approve(context, appId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Approve', style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                        ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => _reject(context, appId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Reject', style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                        ]),
                  ),
                )),
              ]),
            ),
          ] else if (status == 'approved') ...[
            const Divider(height: 1, color: Color(0xFFECEFF1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: GestureDetector(
                onTap: () => _cancel(context, appId, booths, exId),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, size: 16,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text('Cancel Booking',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700)),
                      ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF78909C)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(
            fontSize: 12, color: Color(0xFF546E7A)))),
      ]);
}
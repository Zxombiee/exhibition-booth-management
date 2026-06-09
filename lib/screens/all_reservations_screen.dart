import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllReservationsScreen extends StatefulWidget {
  const AllReservationsScreen({super.key});

  @override
  State<AllReservationsScreen> createState() => _AllReservationsScreenState();
}

class _AllReservationsScreenState extends State<AllReservationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('All Reservations',
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
      body: Column(children: [
        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by company or exhibition...',
              hintStyle: const TextStyle(
                  color: Color(0xFF90A4AE), fontSize: 13),
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
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _ReservationList(status: 'pending',  query: _query),
              _ReservationList(status: 'approved', query: _query),
              _ReservationList(status: 'rejected', query: _query),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESERVATION LIST
// ─────────────────────────────────────────────────────────────
class _ReservationList extends StatelessWidget {
  final String status;
  final String query;

  const _ReservationList({required this.status, required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('status', isEqualTo: status)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: Color(0xFF1565C0)));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        var docs = snap.data?.docs ?? [];

        // Apply search filter
        if (query.isNotEmpty) {
          docs = docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final company = (d['companyName'] ?? '').toString().toLowerCase();
            final exName  = (d['exhibitionName'] ?? '').toString().toLowerCase();
            return company.contains(query) || exName.contains(query);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_emptyIcon(status), size: 56,
                  color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No $status reservations',
                  style: const TextStyle(fontSize: 15,
                      color: Color(0xFF37474F))),
            ],
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              _ReservationCard(doc: docs[i], status: status),
        );
      },
    );
  }

  IconData _emptyIcon(String s) {
    switch (s) {
      case 'approved': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      default:         return Icons.hourglass_empty_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// RESERVATION CARD  (Admin — can edit/cancel any)
// ─────────────────────────────────────────────────────────────
class _ReservationCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String status;

  static const _kBorder = Color(0xFFCDD5E0);

  const _ReservationCard({required this.doc, required this.status});

  Color get _sc {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  Future<void> _approve(BuildContext context, String appId,
      List booths, String exId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Reservation'),
        content: const Text('Approve this application?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('applications').doc(appId)
        .update({'status': 'approved'});

    // Mark booths as booked
    for (final b in booths) {
      final bNum = b['boothNumber'] as String?;
      if (bNum == null) continue;
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
          content: Text('Reservation approved'),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _reject(BuildContext context, String appId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Reservation'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reason for rejection:'),
          const SizedBox(height: 8),
          TextField(controller: ctrl,
              decoration: const InputDecoration(
                  hintText: 'Enter reason',
                  border: OutlineInputBorder()),
              maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = ctrl.text.trim();
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please provide a reason'),
            backgroundColor: Colors.orange));
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('applications').doc(appId)
        .update({'status': 'rejected', 'rejectionReason': reason});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reservation rejected'),
          backgroundColor: Colors.orange));
    }
    ctrl.dispose();
  }

  Future<void> _cancel(BuildContext context, String appId,
      List booths, String exId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
            'Cancel this approved booking? Booths will be released back to available.'),
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

    await FirebaseFirestore.instance
        .collection('applications').doc(appId)
        .update({'status': 'rejected',
      'rejectionReason': 'Cancelled by admin'});

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
          content: Text('Booking cancelled, booths released'),
          backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data        = doc.data() as Map<String, dynamic>;
    final appId       = doc.id;
    final company     = data['companyName']    ?? 'Unknown';
    final exName      = data['exhibitionName'] ?? '';
    final exId        = data['exhibitionId']   ?? '';
    final booths      = data['booths']  as List? ?? [];
    final addons      = data['addons']  as List? ?? [];
    final total       = (data['totalPrice'] as num?)?.toDouble() ?? 0;
    final submitted   = (data['submittedAt'] as Timestamp?)?.toDate();
    final rejReason   = data['rejectionReason'] as String?;
    final compDesc    = data['companyDescription'] ?? '';
    final fmt         = DateFormat('d MMM yyyy, h:mm a');

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: _sc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.business, color: _sc, size: 21)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company, style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E))),
                  const SizedBox(height: 2),
                  Text(exName, style: const TextStyle(fontSize: 12,
                      color: Color(0xFF78909C))),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _sc.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _sc.withOpacity(0.4))),
                child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w700, color: _sc)),
              ),
            ]),
          ),

          const Divider(height: 1, color: Color(0xFFECEFF1)),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.event_seat_outlined,
                    'Booths: ${booths.map((b) =>
                    '${b['boothNumber']} (${b['type']}, RM${(b['price'] as num).toInt()})'
                    ).join(', ')}'),
                const SizedBox(height: 5),
                _row(Icons.payments_outlined,
                    'Total: RM${total.toInt()}'),
                if (submitted != null) ...[
                  const SizedBox(height: 5),
                  _row(Icons.schedule_outlined,
                      'Submitted: ${fmt.format(submitted)}'),
                ],
                if (addons.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _row(Icons.add_box_outlined,
                      'Add-ons: ${addons.join(', ')}'),
                ],
                if (compDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Company Description',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F))),
                  const SizedBox(height: 3),
                  Text(compDesc, style: const TextStyle(fontSize: 12,
                      color: Color(0xFF546E7A))),
                ],
                if (status == 'rejected' && rejReason != null
                    && rejReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200)),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 13,
                          color: Colors.red.shade600),
                      const SizedBox(width: 7),
                      Expanded(child: Text('Reason: $rejReason',
                          style: TextStyle(fontSize: 12,
                              color: Colors.red.shade700))),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          const Divider(height: 1, color: Color(0xFFECEFF1)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              if (status == 'pending') ...[
                Expanded(child: _btn('Approve', Colors.green,
                    Icons.check,
                        () => _approve(context, appId, booths, exId))),
                const SizedBox(width: 10),
                Expanded(child: _btn('Reject', Colors.red,
                    Icons.close,
                        () => _reject(context, appId))),
              ],
              if (status == 'approved')
                Expanded(child: _btn('Cancel Booking', Colors.orange,
                    Icons.cancel_outlined,
                        () => _cancel(context, appId, booths, exId),
                    outlined: true)),
              if (status == 'rejected')
                Expanded(child: _btn('Re-approve', Colors.green,
                    Icons.redo,
                        () => _approve(context, appId, booths, exId))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF78909C)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(
            fontSize: 12, color: Color(0xFF546E7A)))),
      ]);

  Widget _btn(String label, Color color, IconData icon,
      VoidCallback onTap, {bool outlined = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: outlined ? color.withOpacity(0.08) : color,
              borderRadius: BorderRadius.circular(10),
              border: outlined ? Border.all(color: color) : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15,
                    color: outlined ? color : Colors.white),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: outlined ? color : Colors.white)),
              ]),
        ),
      );
}
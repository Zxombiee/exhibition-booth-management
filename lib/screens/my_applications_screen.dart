import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../app_router.dart';

// ─────────────────────────────────────────────────────────────
// MY APPLICATIONS SCREEN  (Exhibitor)
// ─────────────────────────────────────────────────────────────
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen>
    with SingleTickerProviderStateMixin {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final TabController _tabCtrl;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Applications',
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
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _AppList(uid: _uid!, status: 'pending'),
          _AppList(uid: _uid!, status: 'approved'),
          _AppList(uid: _uid!, status: 'rejected'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// APPLICATION LIST
// ─────────────────────────────────────────────────────────────
class _AppList extends StatelessWidget {
  final String uid;
  final String status;

  const _AppList({required this.uid, required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('exhibitorId', isEqualTo: uid)
          .where('status', isEqualTo: status)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: Color(0xFF1565C0)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_emptyIcon(status), size: 56,
                  color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No $status applications',
                  style: const TextStyle(fontSize: 15,
                      color: Color(0xFF37474F))),
              const SizedBox(height: 6),
              if (status == 'pending')
                const Text('Your submitted applications will appear here',
                    style: TextStyle(fontSize: 13,
                        color: Color(0xFF78909C))),
              if (status == 'approved') ...[
                const Text('Approved bookings will appear here',
                    style: TextStyle(fontSize: 13,
                        color: Color(0xFF78909C))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.browseEvents),
                  icon: const Icon(Icons.search),
                  label: const Text('Browse Events'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white),
                ),
              ],
            ],
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              _AppCard(doc: docs[i], status: status),
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

  IconData get _statusIcon {
    switch (status) {
      case 'approved': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      default:         return Icons.hourglass_empty_outlined;
    }
  }

  Future<void> _editApplication(
      BuildContext context, String appId, Map<String, dynamic> data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditApplicationScreen(
          appId: appId,
          data: data,
        ),
      ),
    );
  }

  Future<void> _cancelApplication(
      BuildContext context, String appId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Application'),
        content: const Text(
            'Are you sure you want to cancel this pending application?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('applications').doc(appId)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Application cancelled'),
          backgroundColor: Colors.orange));
    }
  }

  Future<void> _reapply(BuildContext context, Map<String, dynamic> data) async {
    // Navigate to floor plan to re-select booths
    final exId   = data['exhibitionId'] as String?;
    final exName = data['exhibitionName'] as String? ?? '';
    if (exId == null) return;
    context.push(
      AppRoutes.floorPlanPath(exId),
      extra: {'exhibitionName': exName},
    );
  }

  @override
  Widget build(BuildContext context) {
    final data          = doc.data() as Map<String, dynamic>;
    final appId         = doc.id;
    final exName        = data['exhibitionName'] ?? 'Unknown Exhibition';
    final companyName   = data['companyName']    ?? '';
    final booths        = data['booths']  as List? ?? [];
    final addons        = data['addons']  as List? ?? [];
    final totalPrice    = (data['totalPrice'] as num?)?.toDouble() ?? 0;
    final submittedAt   = (data['submittedAt'] as Timestamp?)?.toDate();
    final rejReason     = data['rejectionReason'] as String?;
    final exhibitProfile = data['exhibitProfile'] as String? ?? '';
    final fmt           = DateFormat('d MMM yyyy');

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
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon,
                    color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exName, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E))),
                  if (companyName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(companyName, style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78909C))),
                  ],
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

          // ── Details ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Booths
                _row(Icons.event_seat_outlined,
                    'Booths: ${booths.map((b) =>
                    '${b['boothNumber']} (${b['type']})'
                    ).join(', ')}'),
                const SizedBox(height: 6),

                // Total price
                _row(Icons.payments_outlined,
                    'Total: RM${totalPrice.toInt()}'),
                const SizedBox(height: 6),

                // Submitted date
                if (submittedAt != null)
                  _row(Icons.schedule_outlined,
                      'Submitted: ${fmt.format(submittedAt)}'),

                // Add-ons
                if (addons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _row(Icons.add_box_outlined,
                      'Add-ons: ${addons.join(', ')}'),
                ],

                // Exhibit profile
                if (exhibitProfile.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Your Exhibit Profile',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F))),
                  const SizedBox(height: 4),
                  Text(exhibitProfile,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF546E7A))),
                ],

                // Rejection reason
                if (status == 'rejected' &&
                    rejReason != null && rejReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 14,
                          color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          'Rejection reason: $rejReason',
                          style: TextStyle(fontSize: 12,
                              color: Colors.red.shade700))),
                    ]),
                  ),
                ],

                // Approved perks
                if (status == 'approved') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          'Your booth booking is confirmed. '
                              'Please proceed with payment arrangements.',
                          style: TextStyle(fontSize: 12,
                              color: Colors.green.shade700))),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // ── Action buttons ───────────────────────────────────
          const Divider(height: 1, color: Color(0xFFECEFF1)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              if (status == 'pending') ...[
                // Edit button
                Expanded(child: GestureDetector(
                  onTap: () => _editApplication(context, appId, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1565C0).withOpacity(0.4)),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined, size: 16,
                              color: Color(0xFF1565C0)),
                          SizedBox(width: 6),
                          Text('Edit',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1565C0))),
                        ]),
                  ),
                )),
                const SizedBox(width: 10),
                // Cancel button
                Expanded(child: GestureDetector(
                  onTap: () => _cancelApplication(context, appId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, size: 16,
                              color: Colors.red.shade600),
                          const SizedBox(width: 6),
                          Text('Cancel',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade600)),
                        ]),
                  ),
                )),
              ],

              if (status == 'rejected') ...[
                Expanded(child: GestureDetector(
                  onTap: () => _reapply(context, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 16,
                              color: Colors.white),
                          SizedBox(width: 6),
                          Text('Re-apply',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ]),
                  ),
                )),
              ],

              if (status == 'approved')
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_outlined, size: 16,
                            color: Colors.white),
                        SizedBox(width: 6),
                        Text('Booking Confirmed',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ]),
                )),
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
}

// ─────────────────────────────────────────────────────────────
// EDIT APPLICATION SCREEN  (Pending only)
// ─────────────────────────────────────────────────────────────
class _EditApplicationScreen extends StatefulWidget {
  final String appId;
  final Map<String, dynamic> data;

  const _EditApplicationScreen({
    required this.appId,
    required this.data,
  });

  @override
  State<_EditApplicationScreen> createState() =>
      _EditApplicationScreenState();
}

class _EditApplicationScreenState
    extends State<_EditApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _companyDescCtrl;
  late final TextEditingController _exhibitProfileCtrl;
  List<String> _selectedAddons = [];

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  final List<_AddonOption> _availableAddons = [
    _AddonOption('Extra Furniture',    200, Icons.chair),
    _AddonOption('Promotional Spot',   500, Icons.campaign),
    _AddonOption('Extended WiFi',      150, Icons.wifi),
    _AddonOption('Electricity Supply', 300, Icons.electrical_services),
    _AddonOption('Banner Display',     250, Icons.flag),
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _companyNameCtrl    = TextEditingController(
        text: d['companyName']        ?? '');
    _companyDescCtrl    = TextEditingController(
        text: d['companyDescription'] ?? '');
    _exhibitProfileCtrl = TextEditingController(
        text: d['exhibitProfile']     ?? '');
    _selectedAddons     =
    List<String>.from(d['addons'] as List? ?? []);
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyDescCtrl.dispose();
    _exhibitProfileCtrl.dispose();
    super.dispose();
  }

  double get _addonsTotal => _availableAddons
      .where((a) => _selectedAddons.contains(a.name))
      .fold(0, (s, a) => s + a.price);

  double get _boothsTotal =>
      (widget.data['boothsTotal'] as num?)?.toDouble() ?? 0;

  double get _grandTotal => _boothsTotal + _addonsTotal;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(widget.appId)
          .update({
        'companyName':        _companyNameCtrl.text.trim(),
        'companyDescription': _companyDescCtrl.text.trim(),
        'exhibitProfile':     _exhibitProfileCtrl.text.trim(),
        'addons':             _selectedAddons,
        'addonsTotal':        _addonsTotal,
        'totalPrice':         _grandTotal,
        'updatedAt':          FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Application updated successfully'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booths = widget.data['booths'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Application',
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _isLoading ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                    style: TextStyle(fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Booked booths (read-only) ─────────────────
              _card([
                const _Label('Selected Booths (cannot change)'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6,
                    children: booths.map<Widget>((b) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.blue.shade200)),
                      child: Text(
                          '${b['boothNumber']} · ${b['type']} · RM${(b['price'] as num).toInt()}',
                          style: TextStyle(fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600)),
                    )).toList()),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Booths Total',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xFF546E7A))),
                    Text('RM${_boothsTotal.toInt()}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ]),
              const SizedBox(height: 14),

              // ── Company info (editable) ───────────────────
              _card([
                const _Label('Company Information'),
                const SizedBox(height: 12),
                _field(_companyNameCtrl,    'Company Name *',    Icons.business),
                const SizedBox(height: 12),
                _field(_companyDescCtrl,    'Company Description *',
                    Icons.description_outlined, maxLines: 3),
                const SizedBox(height: 12),
                _field(_exhibitProfileCtrl, 'Exhibit Profile *',
                    Icons.storefront_outlined, maxLines: 3),
              ]),
              const SizedBox(height: 14),

              // ── Add-ons (editable) ────────────────────────
              _card([
                const _Label('Additional Items'),
                const SizedBox(height: 8),
                ..._availableAddons.map((addon) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(addon.name,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('RM${addon.price.toInt()}',
                      style: const TextStyle(fontSize: 11)),
                  secondary: Icon(addon.icon, color: _kBlue, size: 20),
                  value: _selectedAddons.contains(addon.name),
                  activeColor: _kBlue,
                  onChanged: (v) => setState(() {
                    if (v == true) _selectedAddons.add(addon.name);
                    else           _selectedAddons.remove(addon.name);
                  }),
                )),
              ]),
              const SizedBox(height: 14),

              // ── Total ─────────────────────────────────────
              _card([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Booths Total',
                        style: TextStyle(fontSize: 13,
                            color: Color(0xFF546E7A))),
                    Text('RM${_boothsTotal.toInt()}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add-ons Total',
                        style: TextStyle(fontSize: 13,
                            color: Color(0xFF546E7A))),
                    Text('RM${_addonsTotal.toInt()}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFECEFF1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E))),
                    Text('RM${_grandTotal.toInt()}',
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0))),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1}) =>
      TextFormField(
        controller: ctrl, maxLines: maxLines,
        validator: (v) =>
        v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18,
              color: const Color(0xFF90A4AE)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          filled: true, fillColor: const Color(0xFFF5F7FA),
        ),
      );
}

class _AddonOption {
  final String name;
  final double price;
  final IconData icon;
  const _AddonOption(this.name, this.price, this.icon);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w700, color: Color(0xFF37474F)));
}
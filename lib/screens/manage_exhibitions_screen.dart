import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'create_event_screen.dart';

// ─────────────────────────────────────────────────────────────
// MANAGE EXHIBITIONS SCREEN  (Admin — full CRUD)
// ─────────────────────────────────────────────────────────────
class ManageExhibitionsScreen extends StatefulWidget {
  const ManageExhibitionsScreen({super.key});

  @override
  State<ManageExhibitionsScreen> createState() =>
      _ManageExhibitionsScreenState();
}

class _ManageExhibitionsScreenState extends State<ManageExhibitionsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  String _searchQuery   = '';
  String _filterStatus  = 'all';    // all | upcoming | ongoing | completed
  bool   _filterPublished = false;  // false = show all, true = published only

  static const _kBlue    = Color(0xFF1565C0);
  static const _kBg      = Color(0xFFF5F7FA);
  static const _kBorder  = Color(0xFFCDD5E0);
  static const _kCard    = Colors.white;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Firestore helpers ───────────────────────────────────────

  Future<void> _togglePublish(String id, bool current) async {
    await _firestore.collection('exhibitions').doc(id).update({
      'isPublished': !current,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(!current ? 'Exhibition published' : 'Exhibition unpublished'),
        backgroundColor: !current ? Colors.green : Colors.orange,
      ));
    }
  }

  Future<void> _deleteExhibition(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Exhibition'),
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
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                  'This will permanently delete the exhibition. '
                      'Existing booth and application data will remain.',
                  style: TextStyle(fontSize: 12),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _firestore.collection('exhibitions').doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$name" deleted'),
        backgroundColor: Colors.red.shade400,
      ));
    }
  }

  // ── Filtering ───────────────────────────────────────────────

  List<QueryDocumentSnapshot> _applyFilters(
      List<QueryDocumentSnapshot> docs) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return docs.where((doc) {
      final data      = doc.data() as Map<String, dynamic>;
      final name      = (data['name']  ?? '').toString().toLowerCase();
      final venue     = (data['venue'] ?? '').toString().toLowerCase();
      final published = data['isPublished'] == true;

      // Compute status from dates
      final startDate = (data['startDate'] as Timestamp?)?.toDate();
      final endDate   = (data['endDate']   as Timestamp?)?.toDate();
      String status   = 'upcoming';
      if (startDate != null && endDate != null) {
        final s = DateTime(startDate.year, startDate.month, startDate.day);
        final e = DateTime(endDate.year,   endDate.month,   endDate.day);
        if (today.isAfter(e))        status = 'completed';
        else if (!today.isBefore(s)) status = 'ongoing';
      }

      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery) &&
          !venue.contains(_searchQuery)) return false;
      if (_filterStatus != 'all' && status != _filterStatus) return false;
      if (_filterPublished && !published) return false;
      return true;
    }).toList();
  }

  // ── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Manage Exhibitions',
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
          // Create new exhibition
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.createEvent),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Create', style: TextStyle(fontSize: 13,
                      color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        _buildSearchBar(),
        _buildFilterRow(),
        Expanded(child: _buildList()),
      ]),
    );
  }

  // ── Search bar ──────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search exhibitions...',
          hintStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF90A4AE), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(Icons.close, color: Color(0xFF90A4AE), size: 18),
          )
              : null,
          filled: true,
          fillColor: _kBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ── Filter row ──────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Status filters
          ...[
            ('all',       'All'),
            ('upcoming',  'Upcoming'),
            ('ongoing',   'Ongoing'),
            ('completed', 'Completed'),
          ].map((item) {
            final active = _filterStatus == item.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterStatus = item.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? _kBlue : _kBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? _kBlue : _kBorder),
                  ),
                  child: Text(item.$2,
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : const Color(0xFF546E7A))),
                ),
              ),
            );
          }),
          // Published toggle
          GestureDetector(
            onTap: () => setState(() => _filterPublished = !_filterPublished),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _filterPublished ? Colors.green.shade600 : _kBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _filterPublished ? Colors.green.shade600 : _kBorder),
              ),
              child: Row(children: [
                Icon(Icons.visibility, size: 13,
                    color: _filterPublished ? Colors.white : const Color(0xFF546E7A)),
                const SizedBox(width: 5),
                Text('Published',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _filterPublished ? Colors.white : const Color(0xFF546E7A))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Exhibition list ─────────────────────────────────────────
  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('exhibitions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kBlue));
        }

        final all = snapshot.data?.docs ?? [];
        final filtered = _applyFilters(all);

        if (filtered.isEmpty) {
          return _buildEmpty(all.isEmpty);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _buildCard(filtered[i]),
        );
      },
    );
  }

  Widget _buildEmpty(bool noExhibitions) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_outlined, size: 56,
                color: Colors.blue.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            noExhibitions
                ? 'No exhibitions yet'
                : 'No exhibitions match your filter',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: Color(0xFF37474F)),
          ),
          const SizedBox(height: 6),
          Text(
            noExhibitions
                ? 'Tap Create to add your first exhibition'
                : 'Try changing the filters above',
            style: const TextStyle(fontSize: 13, color: Color(0xFF78909C)),
          ),
          if (noExhibitions) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.createEvent),
              icon: const Icon(Icons.add),
              label: const Text('Create Exhibition'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Exhibition card ─────────────────────────────────────────
  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data        = doc.data() as Map<String, dynamic>;
    final id          = doc.id;
    final name        = data['name'] ?? 'Unnamed';
    final venue       = data['venue'] ?? '';
    final isPublished = data['isPublished'] == true;
    final startDate   = (data['startDate'] as Timestamp?)?.toDate();
    final endDate     = (data['endDate']   as Timestamp?)?.toDate();
    final fmt         = DateFormat('d MMM yyyy');

    // Compute status from dates — ignore stored value
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String status = 'upcoming';
    if (startDate != null && endDate != null) {
      final s = DateTime(startDate.year, startDate.month, startDate.day);
      final e = DateTime(endDate.year,   endDate.month,   endDate.day);
      if (today.isAfter(e))        status = 'completed';
      else if (!today.isBefore(s)) status = 'ongoing';
    }

    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Published indicator
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPublished ? Colors.green : Colors.grey.shade400,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A237E))),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 13,
                            color: Color(0xFF78909C)),
                        const SizedBox(width: 3),
                        Expanded(child: Text(venue,
                            style: const TextStyle(fontSize: 12,
                                color: Color(0xFF78909C)),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
          ),

          // ── Dates ───────────────────────────────────────────
          if (startDate != null || endDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 14, 10),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 13,
                    color: Color(0xFF78909C)),
                const SizedBox(width: 5),
                Text(
                    '${startDate != null ? fmt.format(startDate) : '?'}  →  '
                        '${endDate != null ? fmt.format(endDate) : '?'}',
                    style: const TextStyle(fontSize: 12,
                        color: Color(0xFF546E7A))),
              ]),
            ),

          // ── Booth types ──────────────────────────────────────
          if (data['boothTypes'] != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 14, 10),
              child: Wrap(spacing: 6, runSpacing: 4,
                children: (data['boothTypes'] as List).map<Widget>((bt) {
                  final c = Color(bt['color'] as int? ?? Colors.blue.value);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.1),
                      border: Border.all(color: c.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        '${bt['type']}  RM${(bt['price'] as num).toInt()}',
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c)),
                  );
                }).toList(),
              ),
            ),
          ],

          const Divider(height: 1, color: Color(0xFFECEFF1)),

          // ── Action row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              // Publish toggle
              _actionBtn(
                icon: isPublished ? Icons.visibility_off : Icons.visibility,
                label: isPublished ? 'Unpublish' : 'Publish',
                color: isPublished ? Colors.orange : Colors.green,
                onTap: () => _togglePublish(id, isPublished),
              ),
              const SizedBox(width: 6),
              // Edit
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: _kBlue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditExhibitionScreen(exhibitionId: id, data: data))),
              ),
              const Spacer(),
              // Delete
              GestureDetector(
                onTap: () => _deleteExhibition(id, name),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 14,
                        color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text('Delete', style: TextStyle(fontSize: 12,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'upcoming':  return Colors.blue;
      case 'ongoing':   return Colors.green;
      case 'completed': return Colors.grey;
      default:          return Colors.blue;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// EDIT EXHIBITION SCREEN
// ─────────────────────────────────────────────────────────────
class EditExhibitionScreen extends StatefulWidget {
  final String exhibitionId;
  final Map<String, dynamic> data;

  const EditExhibitionScreen({
    super.key,
    required this.exhibitionId,
    required this.data,
  });

  @override
  State<EditExhibitionScreen> createState() => _EditExhibitionScreenState();
}

class _EditExhibitionScreenState extends State<EditExhibitionScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _firestore  = FirebaseFirestore.instance;
  bool _isLoading   = false;

  // Existing URLs from Firestore
  String? _existingImageUrl;
  String? _existingFloorPlanUrl;
  // Newly picked files (override existing)
  File? _venueImageFile;
  File? _floorPlanImageFile;
  final _picker = ImagePicker();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _venueCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  bool   _isPublished  = false;

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl  = TextEditingController(text: d['name'] ?? '');
    _descCtrl  = TextEditingController(text: d['description'] ?? '');
    _venueCtrl = TextEditingController(text: d['venue'] ?? '');
    _startDate   = (d['startDate'] as Timestamp?)?.toDate();
    _endDate     = (d['endDate']   as Timestamp?)?.toDate();
    _isPublished = d['isPublished'] == true;
    _existingImageUrl    = d['imageUrl']     as String?;
    _existingFloorPlanUrl = d['floorPlanUrl'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else         _endDate   = picked;
      });
    }
  }

  Future<void> _pickVenueImage() async {
    final p = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _venueImageFile = File(p.path));
  }

  Future<void> _pickFloorPlanImage() async {
    final p = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p != null) setState(() => _floorPlanImageFile = File(p.path));
  }

  Future<String?> _uploadImage(File file, String folder) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('$folder/${widget.exhibitionId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select start and end dates'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Compute status from dates
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final s     = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final e     = DateTime(_endDate!.year,   _endDate!.month,   _endDate!.day);
      final computedStatus = today.isBefore(s)
          ? 'upcoming' : today.isAfter(e) ? 'completed' : 'ongoing';

      // Upload new images if picked
      String? imageUrl = _existingImageUrl;
      String? floorPlanUrl = _existingFloorPlanUrl;
      if (_venueImageFile != null) {
        imageUrl = await _uploadImage(_venueImageFile!, 'exhibition_images');
      }
      if (_floorPlanImageFile != null) {
        floorPlanUrl = await _uploadImage(_floorPlanImageFile!, 'floor_plans');
      }

      await _firestore.collection('exhibitions').doc(widget.exhibitionId).update({
        'name':         _nameCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'venue':        _venueCtrl.text.trim(),
        'startDate':    Timestamp.fromDate(_startDate!),
        'endDate':      Timestamp.fromDate(_endDate!),
        'status':       computedStatus,
        'isPublished':  _isPublished,
        'imageUrl':     imageUrl,
        'floorPlanUrl': floorPlanUrl,
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Exhibition updated'),
          backgroundColor: Colors.green,
        ));
        context.pop();
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
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Exhibition',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                    style: TextStyle(fontSize: 13, color: Colors.white,
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
          child: Column(children: [
            _card(children: [
              const _SectionLabel('Basic Information'),
              const SizedBox(height: 12),
              _field(_nameCtrl,  'Exhibition Name', Icons.event),
              const SizedBox(height: 12),
              _field(_venueCtrl, 'Venue',           Icons.location_on_outlined),
              const SizedBox(height: 12),
              _field(_descCtrl,  'Description', Icons.description_outlined,
                  maxLines: 3, required: false),
            ]),
            const SizedBox(height: 14),
            _card(children: [
              const _SectionLabel('Dates'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateTile(
                  'Start Date',
                  _startDate != null ? fmt.format(_startDate!) : 'Select',
                      () => _pickDate(true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _dateTile(
                  'End Date',
                  _endDate != null ? fmt.format(_endDate!) : 'Select',
                      () => _pickDate(false),
                )),
              ]),
            ]),
            const SizedBox(height: 14),
            // ── Images ───────────────────────────────────────────
            _card(children: [
              const _SectionLabel('Images'),
              const SizedBox(height: 12),
              _editImagePicker(
                label: 'Venue Photo',
                existingUrl: _existingImageUrl,
                newFile: _venueImageFile,
                onPick: _pickVenueImage,
                onRemove: () => setState(() {
                  _venueImageFile = null;
                  _existingImageUrl = null;
                }),
              ),
              const SizedBox(height: 14),
              _editImagePicker(
                label: 'Floor Plan Image',
                existingUrl: _existingFloorPlanUrl,
                newFile: _floorPlanImageFile,
                onPick: _pickFloorPlanImage,
                onRemove: () => setState(() {
                  _floorPlanImageFile = null;
                  _existingFloorPlanUrl = null;
                }),
              ),
            ]),
            const SizedBox(height: 14),
            _card(children: [
              const _SectionLabel('Settings'),
              const SizedBox(height: 12),
              // Auto status info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Status is computed automatically from your dates. '
                        'Upcoming → Ongoing → Completed.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  )),
                ]),
              ),
              const SizedBox(height: 14),
              // Published toggle
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isPublished
                      ? Colors.green.shade50 : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _isPublished
                          ? Colors.green.shade200 : _kBorder),
                ),
                child: Row(children: [
                  Icon(_isPublished ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                      color: _isPublished ? Colors.green : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isPublished ? 'Published' : 'Unpublished',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: _isPublished ? Colors.green : Colors.grey)),
                      Text(
                          _isPublished
                              ? 'Visible to exhibitors and guests'
                              : 'Hidden from exhibitors and guests',
                          style: const TextStyle(fontSize: 11,
                              color: Color(0xFF90A4AE))),
                    ],
                  )),
                  Switch(
                    value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                    activeColor: Colors.green,
                  ),
                ]),
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
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _field(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        int maxLines = 1,
        bool required = true,
      }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF90A4AE)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11,
              color: Color(0xFF90A4AE))),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: _kBlue),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
          ]),
        ]),
      ),
    );
  }
  Widget _editImagePicker({
    required String label,
    required String? existingUrl,
    required File? newFile,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasImage = newFile != null || existingUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w500, color: Color(0xFF546E7A))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: !hasImage ? onPick : null,
          child: Container(
            height: hasImage ? 150 : 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: hasImage
                  ? Colors.blue.shade300 : const Color(0xFFCDD5E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: hasImage
                ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(fit: StackFit.expand, children: [
                newFile != null
                    ? Image.file(newFile, fit: BoxFit.cover)
                    : Image.network(existingUrl!, fit: BoxFit.cover),
                Positioned(top: 8, right: 8,
                    child: Row(children: [
                      _imgButton(Icons.edit, Colors.blue, onPick),
                      const SizedBox(width: 6),
                      _imgButton(Icons.close, Colors.red, onRemove),
                    ])),
              ]),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 24, color: Colors.grey.shade400),
                const SizedBox(height: 4),
                Text('Tap to add $label',
                    style: TextStyle(fontSize: 11,
                        color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imgButton(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF37474F)));
}
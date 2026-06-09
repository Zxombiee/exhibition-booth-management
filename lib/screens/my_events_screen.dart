import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../app_router.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  String _filter = 'all';

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  String _computeStatus(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return 'upcoming';
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final s = start.toDate(); final sd = DateTime(s.year, s.month, s.day);
    final e = end.toDate();   final ed = DateTime(e.year, e.month, e.day);
    if (t.isBefore(sd)) return 'upcoming';
    if (t.isAfter(ed))  return 'completed';
    return 'ongoing';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ongoing':   return Colors.green;
      case 'completed': return Colors.grey;
      default:          return Colors.blue;
    }
  }

  Future<void> _togglePublish(String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('exhibitions').doc(id)
        .update({'isPublished': !current});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(!current ? 'Event published' : 'Event unpublished'),
        backgroundColor: !current ? Colors.green : Colors.orange,
      ));
    }
  }

  Future<void> _deleteEvent(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "$name"? This cannot be undone.'),
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
        .collection('exhibitions').doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$name" deleted'),
          backgroundColor: Colors.red.shade400));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Events',
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
              onTap: () => context.push(AppRoutes.createEvent),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: _kBlue, borderRadius: BorderRadius.circular(8)),
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
        // Filter row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [('all','All'),('upcoming','Upcoming'),
                ('ongoing','Ongoing'),('completed','Completed')])
                Padding(padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filter == f.$1 ? _kBlue : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _filter == f.$1 ? _kBlue : _kBorder),
                        ),
                        child: Text(f.$2, style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _filter == f.$1 ? Colors.white
                                : const Color(0xFF546E7A))),
                      ),
                    )),
            ]),
          ),
        ),
        // Events list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('exhibitions')
                .where('organizerId', isEqualTo: _uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kBlue));
              }
              final docs = (snapshot.data?.docs ?? []).where((doc) {
                if (_filter == 'all') return true;
                final d = doc.data() as Map<String, dynamic>;
                return _computeStatus(
                    d['startDate'] as Timestamp?,
                    d['endDate']   as Timestamp?) == _filter;
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_outlined, size: 56,
                        color: Colors.blue.shade200),
                    const SizedBox(height: 12),
                    Text(_filter == 'all' ? 'No events yet'
                        : 'No $_filter events',
                        style: const TextStyle(fontSize: 15,
                            color: Color(0xFF37474F))),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.createEvent),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Event'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc  = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final id   = doc.id;
                  final name = data['name'] ?? 'Unnamed';
                  final venue = data['venue'] ?? '';
                  final imageUrl    = data['imageUrl'] as String?;
                  final isPublished = data['isPublished'] == true;
                  final startTs = data['startDate'] as Timestamp?;
                  final endTs   = data['endDate']   as Timestamp?;
                  final status  = _computeStatus(startTs, endTs);
                  final sc      = _statusColor(status);
                  final fmt     = DateFormat('d MMM yyyy');

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        if (imageUrl != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(11)),
                            child: Image.network(imageUrl,
                                height: 130, width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                          )
                        else
                          Container(height: 70,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(11)),
                              ),
                              child: Center(child: Icon(
                                  Icons.event_outlined,
                                  size: 32, color: Colors.blue.shade200))),

                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name + status
                              Row(children: [
                                Container(width: 8, height: 8,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPublished
                                          ? Colors.green : Colors.grey.shade400),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(name,
                                    style: const TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A237E)))),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: sc.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: sc.withOpacity(0.4)),
                                  ),
                                  child: Text(status.toUpperCase(),
                                      style: TextStyle(fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: sc)),
                                ),
                              ]),
                              const SizedBox(height: 8),

                              // Venue
                              Row(children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13, color: Color(0xFF78909C)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(venue,
                                    style: const TextStyle(fontSize: 12,
                                        color: Color(0xFF78909C)),
                                    overflow: TextOverflow.ellipsis)),
                              ]),
                              const SizedBox(height: 4),

                              // Dates
                              Row(children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 13, color: Color(0xFF78909C)),
                                const SizedBox(width: 4),
                                Text(
                                    '${startTs != null ? fmt.format(startTs.toDate()) : '?'}  →  ${endTs != null ? fmt.format(endTs.toDate()) : '?'}',
                                    style: const TextStyle(fontSize: 12,
                                        color: Color(0xFF546E7A))),
                              ]),

                              // Pending badge
                              const SizedBox(height: 8),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('applications')
                                    .where('exhibitionId', isEqualTo: id)
                                    .where('status', isEqualTo: 'pending')
                                    .snapshots(),
                                builder: (_, s) {
                                  final count = s.data?.docs.length ?? 0;
                                  if (count == 0) return const SizedBox.shrink();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.pending_actions,
                                              size: 13, color: Colors.orange.shade700),
                                          const SizedBox(width: 5),
                                          Text('$count pending',
                                              style: TextStyle(fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange.shade700)),
                                        ]),
                                  );
                                },
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFECEFF1)),
                              const SizedBox(height: 10),

                              // Actions
                              Row(children: [
                                _chip(
                                  isPublished
                                      ? Icons.visibility_off : Icons.visibility,
                                  isPublished ? 'Unpublish' : 'Publish',
                                  isPublished ? Colors.orange : Colors.green,
                                      () => _togglePublish(id, isPublished),
                                ),
                                const SizedBox(width: 6),
                                _chip(
                                  Icons.edit_outlined, 'Edit', _kBlue,
                                      () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) =>
                                          _EditEventScreen(
                                              eventId: id, data: data))),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _deleteEvent(id, name),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.delete_outline, size: 14,
                                          color: Colors.red.shade400),
                                      const SizedBox(width: 4),
                                      Text('Delete', style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade400,
                                          fontWeight: FontWeight.w600)),
                                    ]),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
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

// ─────────────────────────────────────────────────────────────
// EDIT EVENT SCREEN
// ─────────────────────────────────────────────────────────────
class _EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  const _EditEventScreen({required this.eventId, required this.data});

  @override
  State<_EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<_EditEventScreen> {
  final _formKey   = GlobalKey<FormState>();
  bool _isLoading  = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _venueCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPublished = false;

  File? _venueImageFile;
  File? _floorImageFile;
  String? _existingImageUrl;
  String? _existingFloorUrl;
  final _picker = ImagePicker();

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl  = TextEditingController(text: d['name']        ?? '');
    _descCtrl  = TextEditingController(text: d['description'] ?? '');
    _venueCtrl = TextEditingController(text: d['venue']       ?? '');
    _startDate = (d['startDate'] as Timestamp?)?.toDate();
    _endDate   = (d['endDate']   as Timestamp?)?.toDate();
    _isPublished       = d['isPublished'] == true;
    _existingImageUrl  = d['imageUrl']     as String?;
    _existingFloorUrl  = d['floorPlanUrl'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImg(bool isVenue) async {
    final p = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;
    setState(() {
      if (isVenue) _venueImageFile = File(p.path);
      else         _floorImageFile = File(p.path);
    });
  }

  Future<String?> _upload(File f, String folder) async {
    final ref = FirebaseStorage.instance.ref()
        .child('$folder/${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(f);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select dates'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final t = DateTime(now.year, now.month, now.day);
      final s = _startDate!; final sd = DateTime(s.year, s.month, s.day);
      final e = _endDate!;   final ed = DateTime(e.year, e.month, e.day);
      final status = t.isBefore(sd) ? 'upcoming'
          : t.isAfter(ed) ? 'completed' : 'ongoing';

      String? imgUrl   = _existingImageUrl;
      String? floorUrl = _existingFloorUrl;
      if (_venueImageFile != null)
        imgUrl   = await _upload(_venueImageFile!, 'exhibition_images');
      if (_floorImageFile != null)
        floorUrl = await _upload(_floorImageFile!, 'floor_plans');

      await FirebaseFirestore.instance
          .collection('exhibitions').doc(widget.eventId).update({
        'name':         _nameCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'venue':        _venueCtrl.text.trim(),
        'startDate':    Timestamp.fromDate(_startDate!),
        'endDate':      Timestamp.fromDate(_endDate!),
        'status':       status,
        'isPublished':  _isPublished,
        'imageUrl':     imgUrl,
        'floorPlanUrl': floorUrl,
        'updatedAt':    FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Event updated'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red));
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
        title: const Text('Edit Event',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0, surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _kBorder)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _isLoading ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(color: _kBlue,
                      borderRadius: BorderRadius.circular(8)),
                  child: _isLoading
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(fontSize: 13,
                      color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              )),
        ],
      ),
      body: Form(key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _card([
              _lbl('Basic Information'), const SizedBox(height: 12),
              _fld(_nameCtrl,  'Exhibition Name *', Icons.event),
              const SizedBox(height: 12),
              _fld(_venueCtrl, 'Venue *', Icons.location_on_outlined),
              const SizedBox(height: 12),
              _fld(_descCtrl,  'Description', Icons.description_outlined,
                  maxLines: 3, req: false),
            ]),
            const SizedBox(height: 14),
            _card([
              _lbl('Dates'), const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateTile('Start Date',
                    _startDate != null ? fmt.format(_startDate!) : 'Select',
                        () async { final p = await showDatePicker(context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (p != null) setState(() => _startDate = p); })),
                const SizedBox(width: 12),
                Expanded(child: _dateTile('End Date',
                    _endDate != null ? fmt.format(_endDate!) : 'Select',
                        () async { final p = await showDatePicker(context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (p != null) setState(() => _endDate = p); })),
              ]),
            ]),
            const SizedBox(height: 14),
            _card([
              _lbl('Images'), const SizedBox(height: 12),
              _imgPicker('Venue Photo', _existingImageUrl, _venueImageFile,
                      () => _pickImg(true),
                      () => setState(() { _venueImageFile = null; _existingImageUrl = null; })),
              const SizedBox(height: 12),
              _imgPicker('Floor Plan Image', _existingFloorUrl, _floorImageFile,
                      () => _pickImg(false),
                      () => setState(() { _floorImageFile = null; _existingFloorUrl = null; })),
            ]),
            const SizedBox(height: 14),
            _card([
              _lbl('Settings'), const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isPublished
                      ? Colors.green.shade50 : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isPublished
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
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isPublished ? Colors.green : Colors.grey)),
                      Text(_isPublished
                          ? 'Visible to exhibitors'
                          : 'Hidden from exhibitors',
                          style: const TextStyle(fontSize: 11,
                              color: Color(0xFF90A4AE))),
                    ],
                  )),
                  Switch(value: _isPublished,
                      onChanged: (v) => setState(() => _isPublished = v),
                      activeColor: Colors.green),
                ]),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w600)),
                )),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _card(List<Widget> c) => Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: c));

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13,
      fontWeight: FontWeight.w700, color: Color(0xFF37474F)));

  Widget _fld(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, bool req = true}) =>
      TextFormField(controller: ctrl, maxLines: maxLines,
          validator: req
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
          decoration: InputDecoration(labelText: label,
              prefixIcon: Icon(icon, size: 18, color: const Color(0xFF90A4AE)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              filled: true, fillColor: const Color(0xFFF5F7FA)));

  Widget _dateTile(String label, String value, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF5F7FA),
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(10)),
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
              ])));

  Widget _imgPicker(String label, String? url, File? file,
      VoidCallback onPick, VoidCallback onRemove) {
    final has = file != null || url != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w500, color: Color(0xFF546E7A))),
      const SizedBox(height: 6),
      GestureDetector(onTap: !has ? onPick : null,
          child: Container(
            height: has ? 130 : 68, width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade50,
                border: Border.all(color: has ? Colors.blue.shade300 : _kBorder),
                borderRadius: BorderRadius.circular(10)),
            child: has
                ? ClipRRect(borderRadius: BorderRadius.circular(9),
                child: Stack(fit: StackFit.expand, children: [
                  file != null
                      ? Image.file(file, fit: BoxFit.cover)
                      : Image.network(url!, fit: BoxFit.cover),
                  Positioned(top: 8, right: 8, child: Row(children: [
                    _ib(Icons.edit,  Colors.blue, onPick),
                    const SizedBox(width: 6),
                    _ib(Icons.close, Colors.red,  onRemove),
                  ])),
                ]))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 20, color: Colors.grey.shade400),
              const SizedBox(height: 4),
              Text('Tap to add', style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
            ]),
          )),
    ]);
  }

  Widget _ib(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: color.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 13, color: Colors.white)));
}
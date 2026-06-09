import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../app_router.dart';
import '../models/exhibition_model.dart';

// ─────────────────────────────────────────────────────────────
// BROWSE EVENTS SCREEN  (Exhibitor)
// ─────────────────────────────────────────────────────────────
class BrowseEventsScreen extends StatefulWidget {
  const BrowseEventsScreen({super.key});

  @override
  State<BrowseEventsScreen> createState() => _BrowseEventsScreenState();
}

class _BrowseEventsScreenState extends State<BrowseEventsScreen> {
  final _searchCtrl = TextEditingController();
  String _query  = '';
  String _filter = 'all';

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _computeStatus(DateTime start, DateTime end) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year,   end.month,   end.day);
    if (t.isBefore(s)) return 'upcoming';
    if (t.isAfter(e))  return 'completed';
    return 'ongoing';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Browse Events',
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
        // ── Search ──────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name or venue...',
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
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: _kBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // ── Filters ─────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [
                ('all', 'All'),
                ('upcoming', 'Upcoming'),
                ('ongoing', 'Ongoing'),
                ('completed', 'Completed'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
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
                            color: _filter == f.$1 ? _kBlue : _kBorder),
                      ),
                      child: Text(f.$2,
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _filter == f.$1
                                  ? Colors.white
                                  : const Color(0xFF546E7A))),
                    ),
                  ),
                ),
            ]),
          ),
        ),

        // ── Events list ─────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('exhibitions')
                .where('isPublished', isEqualTo: true)
                .orderBy('startDate', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kBlue));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              var docs = snapshot.data?.docs ?? [];

              // Filter + search
              final filtered = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ex   = Exhibition.fromMap(doc.id, data);
                final status = _computeStatus(ex.startDate, ex.endDate);

                if (_filter != 'all' && status != _filter) return false;
                if (_query.isNotEmpty) {
                  if (!ex.name.toLowerCase().contains(_query) &&
                      !ex.venue.toLowerCase().contains(_query))
                    return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 56,
                        color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                        _query.isNotEmpty
                            ? 'No results for "$_query"'
                            : 'No $_filter exhibitions available',
                        style: const TextStyle(fontSize: 15,
                            color: Color(0xFF37474F))),
                    if (_query.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() { _query = ''; _filter = 'all'; });
                        },
                        child: const Text('Clear filter'),
                      ),
                    ],
                  ],
                ));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final doc  = filtered[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final ex   = Exhibition.fromMap(doc.id, data);
                  final status = _computeStatus(ex.startDate, ex.endDate);
                  return _EventCard(
                    exhibition: ex,
                    computedStatus: status,
                    onTap: () => context.push(
                        AppRoutes.eventDetailsPath(ex.id)),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EVENT CARD
// ─────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Exhibition exhibition;
  final String computedStatus;
  final VoidCallback onTap;

  static const _kBorder = Color(0xFFCDD5E0);

  const _EventCard({
    required this.exhibition,
    required this.computedStatus,
    required this.onTap,
  });

  Color get _statusColor {
    switch (computedStatus) {
      case 'ongoing':   return Colors.green;
      case 'completed': return Colors.grey;
      default:          return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
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
          // ── Venue image ────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11)),
            child: exhibition.imageUrl != null
                ? CachedNetworkImage(
              imageUrl: exhibition.imageUrl!,
              height: 160, width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  height: 160, color: Colors.blue.shade50,
                  child: const Center(
                      child: CircularProgressIndicator())),
              errorWidget: (_, __, ___) => _placeholder(),
            )
                : _placeholder(),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + status
                Row(children: [
                  Expanded(child: Text(exhibition.name,
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E)))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _statusColor.withOpacity(0.4)),
                    ),
                    child: Text(computedStatus.toUpperCase(),
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor)),
                  ),
                ]),
                const SizedBox(height: 8),

                // Venue
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Color(0xFF78909C)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(exhibition.venue,
                      style: const TextStyle(fontSize: 13,
                          color: Color(0xFF546E7A)),
                      overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 5),

                // Dates
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Color(0xFF78909C)),
                  const SizedBox(width: 5),
                  Text(
                      '${fmt.format(exhibition.startDate)}  →  ${fmt.format(exhibition.endDate)}',
                      style: const TextStyle(fontSize: 13,
                          color: Color(0xFF546E7A))),
                ]),
                const SizedBox(height: 8),

                // Description
                Text(exhibition.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        color: Color(0xFF78909C), height: 1.4)),
                const SizedBox(height: 12),

                // Booth types
                if (exhibition.boothTypes != null &&
                    exhibition.boothTypes!.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6,
                      children: exhibition.boothTypes!.map((bt) {
                        final c = Color(
                            bt['color'] as int? ?? Colors.blue.value);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.1),
                            border: Border.all(
                                color: c.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                              '${bt['type']}  RM${(bt['price'] as num).toInt()}',
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w600, color: c)),
                        );
                      }).toList()),

                const SizedBox(height: 14),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: computedStatus == 'completed'
                          ? Colors.grey : Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                        computedStatus == 'completed'
                            ? 'View Details'
                            : 'View & Book Booth',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 160, width: double.infinity,
    color: Colors.blue.shade50,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_outlined, size: 48, color: Colors.blue.shade200),
    ]),
  );
}
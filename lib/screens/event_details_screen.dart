import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/exhibition_model.dart';

class EventDetailsScreen extends StatefulWidget {
  final String exhibitionId;
  const EventDetailsScreen({super.key, required this.exhibitionId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Future<DocumentSnapshot> _eventFuture;
  bool _isLoggedIn = false;

  static const _kBlue   = Color(0xFF1565C0);
  static const _kBorder = Color(0xFFCDD5E0);

  @override
  void initState() {
    super.initState();
    _eventFuture = FirebaseFirestore.instance
        .collection('exhibitions')
        .doc(widget.exhibitionId)
        .get();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
  }

  void _handleBookBooth(Exhibition exhibition) {
    if (_isLoggedIn) {
      context.push(
        AppRoutes.floorPlanPath(widget.exhibitionId),
        extra: {'exhibitionName': exhibition.name},
      );
    } else {
      _showLoginDialog();
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to book booths.'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { context.pop(); context.push(AppRoutes.login); },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showFloorPlanFullscreen(String imageUrl) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Floor Plan'),
        ),
        body: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.white, size: 64),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FutureBuilder<DocumentSnapshot>(
        future: _eventFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kBlue));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Event not found'));
          }

          final data       = snapshot.data!.data() as Map<String, dynamic>;
          final exhibition = Exhibition.fromMap(snapshot.data!.id, data);
          final imageUrl   = data['imageUrl']     as String?;
          final floorUrl   = data['floorPlanUrl'] as String?;
          final boothTypes = exhibition.boothTypes ?? [
            {'type': 'Standard', 'price': 800,  'color': Colors.blue.value},
            {'type': 'Premium',  'price': 1500, 'color': Colors.amber.value},
          ];
          final fmt = DateFormat('d MMM yyyy');
          final statusColor = exhibition.computedStatus == ExhibitionStatus.upcoming
              ? Colors.blue
              : exhibition.computedStatus == ExhibitionStatus.ongoing
              ? Colors.green
              : Colors.grey;

          return CustomScrollView(
            slivers: [
              // ── Hero image (venue photo) ─────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: imageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.blue.shade200,
                      child: const Center(
                          child: CircularProgressIndicator(color: Colors.white)),
                    ),
                    errorWidget: (_, __, ___) => _VenuePlaceholder(),
                  )
                      : _VenuePlaceholder(),
                  // Gradient overlay so text is readable
                  titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Name + status ────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(exhibition.name,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E))),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              exhibition.computedStatus.name.toUpperCase(),
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Info rows ────────────────────────────
                      _infoRow(Icons.location_on_outlined, exhibition.venue),
                      const SizedBox(height: 8),
                      _infoRow(Icons.calendar_today_outlined,
                          '${fmt.format(exhibition.startDate)}  →  ${fmt.format(exhibition.endDate)}'),
                      const SizedBox(height: 20),

                      // ── About ────────────────────────────────
                      _sectionTitle('About This Event'),
                      const SizedBox(height: 8),
                      Text(exhibition.description,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF546E7A), height: 1.6)),
                      const SizedBox(height: 24),

                      // ── Floor Plan Section ──────────────────
                      _sectionTitle('Floor Plan'),
                      const SizedBox(height: 10),

                      if (_isLoggedIn) ...[
                        // Logged-in: show image only (interactive map
                        // is on the booking screen)
                        if (floorUrl != null)
                          _buildFloorPlanCard(floorUrl)
                        else
                          _buildFloorPlanEmpty(),
                      ] else ...[
                        // Guest: show image + read-only interactive map
                        if (floorUrl != null) ...[
                          _buildFloorPlanCard(floorUrl),
                          const SizedBox(height: 10),
                        ],
                        _buildGuestFloorMap(widget.exhibitionId),
                      ],
                      const SizedBox(height: 24),

                      // ── Booth types ──────────────────────────
                      _sectionTitle('Booth Information'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: boothTypes.map<Widget>((bt) {
                          final color = Color(bt['color'] as int? ??
                              Colors.blue.value);
                          return _BoothTypeCard(
                            type: bt['type'] as String? ?? 'Standard',
                            price: 'RM${(bt['price'] as num?)?.toInt() ?? 0}',
                            color: color,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 30),

                      // ── Book button ──────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _handleBookBooth(exhibition),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoggedIn
                                ? Colors.green.shade700
                                : _kBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _isLoggedIn
                                ? 'View Map & Book Booth'
                                : 'Login to Book a Booth',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Floor plan image card ──────────────────────────────────
  Widget _buildFloorPlanCard(String url) {
    return GestureDetector(
      onTap: () => _showFloorPlanFullscreen(url),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => _buildFloorPlanEmpty(),
              ),
              // Tap to expand hint
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(Icons.zoom_out_map, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Tap to expand',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Guest read-only floor map ──────────────────────────────
  Widget _buildGuestFloorMap(String exhibitionId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                // Read-only map header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  color: Colors.blue.shade50,
                  child: Row(children: [
                    Icon(Icons.map_outlined,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text('Interactive Floor Map (Read-only)',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('View Only',
                          style: TextStyle(fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                // The actual map
                SizedBox(
                  height: 320,
                  child: _ReadOnlyFloorMap(exhibitionId: exhibitionId),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Login prompt
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(children: [
            Icon(Icons.login, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'Login to select and book available booths',
                style: TextStyle(fontSize: 12,
                    color: Colors.green.shade700))),
            GestureDetector(
              onTap: () => context.push(AppRoutes.login),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Login',
                    style: TextStyle(fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildFloorPlanEmpty() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('No floor plan image uploaded yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 4),
          Text('The interactive map is available on the booking screen',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF78909C)),
    const SizedBox(width: 8),
    Expanded(child: Text(text,
        style: const TextStyle(fontSize: 14, color: Color(0xFF546E7A)))),
  ]);

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E)));
}

// ─────────────────────────────────────────────────────────────
// READ-ONLY FLOOR MAP  (Guest — shows booths, no booking)
// ─────────────────────────────────────────────────────────────
class _ReadOnlyFloorMap extends StatefulWidget {
  final String exhibitionId;
  const _ReadOnlyFloorMap({required this.exhibitionId});

  @override
  State<_ReadOnlyFloorMap> createState() => _ReadOnlyFloorMapState();
}

class _ReadOnlyFloorMapState extends State<_ReadOnlyFloorMap> {
  List<Map<String, dynamic>> _booths     = [];
  List<Map<String, dynamic>> _boothTypes = [];
  Map<String, dynamic>? _stage;
  bool _loading = true;
  Size _hallSize = Size.zero;

  static const _kBooked  = Color(0xFFD32F2F);
  static const _kPending = Color(0xFFF57C00);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('exhibitions').doc(widget.exhibitionId).get();
    final data = doc.data() ?? {};

    final raw = data['boothTypes'];
    if (raw is List && raw.isNotEmpty) {
      _boothTypes = List<Map<String, dynamic>>.from(raw);
    } else {
      _boothTypes = [
        {'type': 'Standard', 'color': Colors.blue.value},
        {'type': 'Premium',  'color': Colors.purple.value},
      ];
    }

    final stageRaw = data['stage'];
    if (stageRaw is Map) {
      _stage = Map<String, dynamic>.from(stageRaw);
    }

    final snap = await FirebaseFirestore.instance
        .collection('booths')
        .where('exhibitionId', isEqualTo: widget.exhibitionId)
        .get();

    if (!mounted) return;
    setState(() {
      _booths = snap.docs.map((d) => {
        'boothNumber': d.data()['boothNumber'] ?? '',
        'type':   d.data()['type']   ?? 'Standard',
        'price':  d.data()['price']  ?? 0,
        'status': d.data()['status'] ?? 'available',
        'x':  (d.data()['x']     as num?)?.toDouble() ?? 0.1,
        'y':  (d.data()['y']     as num?)?.toDouble() ?? 0.1,
        'nw': (d.data()['width'] as num?)?.toDouble() ?? 0.12,
        'nh': (d.data()['height'] as num?)?.toDouble() ?? 0.10,
      }).toList();
      _loading = false;
    });
  }

  Color _typeColor(String type) {
    final m = _boothTypes.firstWhere(
            (b) => b['type'] == type,
        orElse: () => {'color': Colors.blue.value});
    return Color(m['color'] as int);
  }

  Color _fillColor(Map b) {
    final s = b['status'] as String;
    if (s == 'booked')  return _kBooked.withOpacity(0.18);
    if (s == 'pending') return _kPending.withOpacity(0.15);
    return _typeColor(b['type'] as String).withOpacity(0.15);
  }

  Color _borderColor(Map b) {
    final s = b['status'] as String;
    if (s == 'booked')  return _kBooked;
    if (s == 'pending') return _kPending;
    return _typeColor(b['type'] as String);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return InteractiveViewer(
      minScale: 0.6, maxScale: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                  color: const Color(0xFFCDD5E0), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: LayoutBuilder(builder: (_, c) {
                final size = c.biggest;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && size != _hallSize)
                    setState(() => _hallSize = size);
                });
                return Stack(children: [
                  Positioned.fill(
                      child: CustomPaint(painter: _GridPainter())),
                  if (_stage != null && _hallSize != Size.zero)
                    _buildStage(),
                  if (_hallSize != Size.zero)
                    ..._booths.map(_buildBooth),
                  // Watermark
                  Center(child: Opacity(opacity: 0.04,
                      child: Text('READ ONLY',
                          style: TextStyle(fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              letterSpacing: 4)))),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    final s  = _stage!;
    final px = (s['x'] as num).toDouble() * _hallSize.width;
    final py = (s['y'] as num).toDouble() * _hallSize.height;
    final pw = (s['w'] as num).toDouble() * _hallSize.width;
    final ph = (s['h'] as num).toDouble() * _hallSize.height;
    return Positioned(left: px, top: py, width: pw, height: ph,
        child: Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Text('STAGE',
                style: TextStyle(fontSize: 10, color: Colors.grey,
                    letterSpacing: 4, fontWeight: FontWeight.bold)))));
  }

  Widget _buildBooth(Map<String, dynamic> b) {
    final px = b['x']  * _hallSize.width;
    final py = b['y']  * _hallSize.height;
    final pw = b['nw'] * _hallSize.width;
    final ph = b['nh'] * _hallSize.height;
    final fs = (pw * 0.18).clamp(7.0, 11.0);
    final bc = _borderColor(b);
    return Positioned(left: px, top: py, width: pw, height: ph,
        child: Tooltip(
          message: '${b['boothNumber']} · ${b['type']} · '
              'RM${(b['price'] as num).toInt()} · '
              '${(b['status'] as String).toUpperCase()}',
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
                color: _fillColor(b),
                border: Border.all(color: bc, width: 1.5),
                borderRadius: BorderRadius.circular(4)),
            child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b['boothNumber'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: fs, color: bc,
                          fontWeight: FontWeight.bold, height: 1.1)),
                  if (ph > 28)
                    Text('RM${(b['price'] as num).toInt()}',
                        style: TextStyle(fontSize: fs * 0.72,
                            color: bc.withOpacity(0.7), height: 1.1)),
                ]),
            ),
          ),
        ));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFE8ECF0)
      ..strokeWidth = 0.5;
    const step = 22.0;
    for (double x = 0; x <= size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y <= size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ── Venue placeholder ──────────────────────────────────────────
class _VenuePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 72, color: Colors.blue.shade300),
          const SizedBox(height: 8),
          Text('No venue photo', style: TextStyle(
              color: Colors.blue.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Booth type card ────────────────────────────────────────────
class _BoothTypeCard extends StatelessWidget {
  final String type;
  final String price;
  final Color color;

  const _BoothTypeCard({
    required this.type, required this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Text(type, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(price, style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
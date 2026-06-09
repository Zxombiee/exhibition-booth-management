import 'dart:math';
import 'package:go_router/go_router.dart';
import '../app_router.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'application_form_screen.dart';

// ─────────────────────────────────────────────────────────────
// BOOTH SHAPE ENUM
// ─────────────────────────────────────────────────────────────
enum BoothShape {
  rectangle, square, circle, ellipse, triangle,
  pentagon, hexagon, octagon, diamond, star, arrow, lShape,
}

extension BoothShapeX on BoothShape {
  String get label {
    switch (this) {
      case BoothShape.rectangle: return 'Rectangle';
      case BoothShape.square:    return 'Square';
      case BoothShape.circle:    return 'Circle';
      case BoothShape.ellipse:   return 'Ellipse';
      case BoothShape.triangle:  return 'Triangle';
      case BoothShape.pentagon:  return 'Pentagon';
      case BoothShape.hexagon:   return 'Hexagon';
      case BoothShape.octagon:   return 'Octagon';
      case BoothShape.diamond:   return 'Diamond';
      case BoothShape.star:      return 'Star';
      case BoothShape.arrow:     return 'Arrow';
      case BoothShape.lShape:    return 'L-Shape';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// BOOTH MODEL
// ─────────────────────────────────────────────────────────────
class Booth {
  final String id;
  final String exhibitionId;
  final String boothNumber;
  final String type;
  final double price;
  final double x;
  final double y;
  final double nw;
  final double nh;
  final BoothShape shape;
  String status;

  Booth({
    required this.id,
    required this.exhibitionId,
    required this.boothNumber,
    required this.type,
    required this.price,
    required this.x,
    required this.y,
    required this.nw,
    required this.nh,
    required this.shape,
    required this.status,
  });

  factory Booth.fromMap(String id, Map<String, dynamic> map) {
    final shape = BoothShape.values.firstWhere(
          (s) => s.name == (map['shape'] ?? 'rectangle'),
      orElse: () => BoothShape.rectangle,
    );
    return Booth(
      id: id,
      exhibitionId: map['exhibitionId'] ?? '',
      boothNumber: map['boothNumber'] ?? '',
      type: map['type'] ?? 'Standard',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      x: (map['x'] as num?)?.toDouble() ?? 0.1,
      y: (map['y'] as num?)?.toDouble() ?? 0.1,
      nw: (map['width'] as num?)?.toDouble() ?? 0.12,
      nh: (map['height'] as num?)?.toDouble() ?? 0.10,
      shape: shape,
      status: map['status'] ?? 'available',
    );
  }

  Rect toRect(Size s) => Rect.fromLTWH(
    x * s.width, y * s.height, nw * s.width, nh * s.height,
  );
}

// ─────────────────────────────────────────────────────────────
// STAGE MODEL  (optional, placed by admin)
// ─────────────────────────────────────────────────────────────
class StageArea {
  final double x, y, w, h;
  const StageArea({required this.x, required this.y, required this.w, required this.h});

  factory StageArea.fromMap(Map<String, dynamic> map) => StageArea(
    x: (map['x'] as num?)?.toDouble() ?? 0.3,
    y: (map['y'] as num?)?.toDouble() ?? 0.85,
    w: (map['w'] as num?)?.toDouble() ?? 0.4,
    h: (map['h'] as num?)?.toDouble() ?? 0.12,
  );

  Rect toRect(Size s) =>
      Rect.fromLTWH(x * s.width, y * s.height, w * s.width, h * s.height);
}

// ─────────────────────────────────────────────────────────────
// LIGHT THEME CONSTANTS
// ─────────────────────────────────────────────────────────────
const _kBg       = Color(0xFFF5F7FA); // light grey screen bg
const _kHallBg   = Color(0xFFFFFFFF); // white hall
const _kTopBar   = Color(0xFFFFFFFF); // white top bar
const _kBorder   = Color(0xFFCDD5E0); // soft grey border
const _kSelected = Color(0xFF1565C0); // strong blue selected
const _kBooked   = Color(0xFFD32F2F); // red booked
const _kPending  = Color(0xFFF57C00); // orange pending

Color _typeColor(String type, List<Map<String, dynamic>> boothTypes) {
  final m = boothTypes.firstWhere(
        (b) => b['type'] == type,
    orElse: () => {'color': const Color(0xFF3A8FD4).value},
  );
  return Color(m['color'] as int);
}

// ─────────────────────────────────────────────────────────────
// GRID PAINTER
// ─────────────────────────────────────────────────────────────
class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFE8ECF0) // very light grey lines
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

// ─────────────────────────────────────────────────────────────
// FLOOR PLAN SCREEN
// ─────────────────────────────────────────────────────────────
class FloorPlanScreen extends StatefulWidget {
  final String exhibitionId;
  final String exhibitionName;

  const FloorPlanScreen({
    super.key,
    required this.exhibitionId,
    required this.exhibitionName,
  });

  @override
  State<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends State<FloorPlanScreen> {
  List<Booth> _booths = [];
  List<Booth> _selected = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _boothTypes = [];
  StageArea? _stage;

  // From Firestore
  String _exName  = '';
  String _exVenue = '';

  Size _hallSize = Size.zero;
  Booth? _tappedBooth;

  @override
  void initState() {
    super.initState();
    _exName = widget.exhibitionName;
    _load();
  }

  // ─────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);

    final doc = await FirebaseFirestore.instance
        .collection('exhibitions').doc(widget.exhibitionId).get();
    final data = doc.data() ?? {};

    // Name + venue from DB
    _exName  = (data['name']  as String?)?.trim().isNotEmpty == true
        ? data['name'] as String : widget.exhibitionName;
    _exVenue = (data['venue'] as String?) ?? '';

    // Booth types
    final raw = data['boothTypes'];
    if (raw is List && raw.isNotEmpty) {
      _boothTypes = List<Map<String, dynamic>>.from(raw.map((e) => {
        'type':  e['type']  ?? 'Standard',
        'price': e['price'] ?? 0,
        'color': e['color'] ?? const Color(0xFF3A8FD4).value,
      }));
    } else {
      _boothTypes = [
        {'type': 'Standard', 'price': 800,  'color': const Color(0xFF3A8FD4).value},
        {'type': 'Premium',  'price': 1500, 'color': const Color(0xFFB060F0).value},
        {'type': 'VIP',      'price': 3000, 'color': const Color(0xFFF0B030).value},
      ];
    }

    // Stage (optional — placed by admin)
    final stageRaw = data['stage'];
    if (stageRaw is Map) {
      _stage = StageArea.fromMap(Map<String, dynamic>.from(stageRaw));
    }

    // Booths
    final snap = await FirebaseFirestore.instance
        .collection('booths')
        .where('exhibitionId', isEqualTo: widget.exhibitionId)
        .get();

    if (!mounted) return;
    setState(() {
      _booths = snap.docs.map((d) => Booth.fromMap(d.id, d.data())).toList();
      _isLoading = false;
    });
  }

  // ─────────────────────────────────────────────────────────
  void _tap(Booth b) {
    if (b.status == 'booked') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${b.boothNumber} is already booked'),
        backgroundColor: _kBooked,
      ));
      return;
    }
    setState(() => _tappedBooth = b);
  }

  void _toggleSelect(Booth b) {
    if (b.status == 'booked') return;
    setState(() {
      if (_selected.contains(b)) _selected.remove(b);
      else _selected.add(b);
    });
  }

  double get _total => _selected.fold(0, (s, b) => s + b.price);

  void _proceed() {
    if (_selected.isEmpty) return;
    if (!mounted) return;
    // Navigator.push used here because selectedBooths is a complex object
    // that cannot be serialised into a URL path parameter
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ApplicationFormScreen(
        exhibitionId: widget.exhibitionId,
        exhibitionName: _exName,
        selectedBooths: _selected,
      ),
    ));
  }

  // ─── Colour helpers ────────────────────────────────────────
  Color _fill(Booth b) {
    if (_selected.contains(b)) return _kSelected.withOpacity(0.15);
    if (b.status == 'booked')  return _kBooked.withOpacity(0.12);
    if (b.status == 'pending') return _kPending.withOpacity(0.12);
    return _typeColor(b.type, _boothTypes).withOpacity(0.15);
  }

  Color _stroke(Booth b) {
    if (_selected.contains(b)) return _kSelected;
    if (b.status == 'booked')  return _kBooked;
    if (b.status == 'pending') return _kPending;
    return _typeColor(b.type, _boothTypes);
  }

  Color _label(Booth b) => _stroke(b);

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kSelected))
          : SafeArea(child: Column(children: [
        _topBar(),
        _legend(),
        Expanded(child: _hallArea()),
        if (_tappedBooth != null) _popup(_tappedBooth!),
        _bottomBar(),
      ])),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────
  Widget _topBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _kTopBar,
        border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF1565C0), size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 6),
          const Text('FLOOR PLAN',
              style: TextStyle(fontSize: 10, color: Color(0xFF1565C0),
                  letterSpacing: 2, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Text(
          _exName,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15, color: Color(0xFF1A237E),
              fontWeight: FontWeight.bold),
        ),
        if (_exVenue.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on, size: 11, color: Color(0xFF78909C)),
            const SizedBox(width: 3),
            Text(_exVenue,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
          ]),
        ],
      ]),
    );
  }

  // ─── Legend ────────────────────────────────────────────────
  Widget _legend() {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ..._boothTypes.map((bt) {
            final c = Color(bt['color'] as int);
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _legBadge(c, c.withOpacity(0.12), bt['type'] as String),
            );
          }),
          _legBadge(_kBooked,  _kBooked.withOpacity(0.1),  'Booked'),
          const SizedBox(width: 10),
          _legBadge(_kPending, _kPending.withOpacity(0.1),  'Pending'),
          const SizedBox(width: 10),
          _legBadge(_kSelected, _kSelected.withOpacity(0.1), 'Selected'),
        ]),
      ),
    );
  }

  Widget _legBadge(Color border, Color fill, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
              color: border, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: border,
              fontWeight: FontWeight.w600,
            )),
      ]),
    );
  }

  // ─── Hall area ─────────────────────────────────────────────
  Widget _hallArea() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: InteractiveViewer(
          minScale: 0.6,
          maxScale: 4.0,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                color: _kHallBg,
                border: Border.all(color: _kBorder, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(children: [
                  // Blueprint grid
                  Positioned.fill(
                    child: CustomPaint(painter: _BlueprintGridPainter()),
                  ),
                  // Corner marks
                  _corner(top: 8,    left: 8,  tl: true),
                  _corner(top: 8,    right: 8, tr: true),
                  _corner(bottom: 8, left: 8,  bl: true),
                  _corner(bottom: 8, right: 8, br: true),
                  // Content (booths + stage)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _tappedBooth = null),
                      behavior: HitTestBehavior.translucent,
                      child: LayoutBuilder(builder: (_, c) {
                        final size = c.biggest;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && size != _hallSize)
                            setState(() => _hallSize = size);
                        });
                        return Stack(children: [
                          if (_stage != null && _hallSize != Size.zero)
                            _stageWidget(_stage!),
                          if (_hallSize != Size.zero)
                            ..._booths.map(_boothWidget),
                        ]);
                      }),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _corner({
    double? top, double? bottom, double? left, double? right,
    bool tl = false, bool tr = false, bool bl = false, bool br = false,
  }) {
    const c = Color(0xFFCDD5E0);
    const w = 1.5;
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 13, height: 13,
        decoration: BoxDecoration(
          border: Border(
            top:    (tl || tr) ? const BorderSide(color: c, width: w) : BorderSide.none,
            bottom: (bl || br) ? const BorderSide(color: c, width: w) : BorderSide.none,
            left:   (tl || bl) ? const BorderSide(color: c, width: w) : BorderSide.none,
            right:  (tr || br) ? const BorderSide(color: c, width: w) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── Stage widget ──────────────────────────────────────────
  Widget _stageWidget(StageArea stage) {
    final r = stage.toRect(_hallSize);
    return Positioned(
      left: r.left, top: r.top, width: r.width, height: r.height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF1),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1,
                decoration: const BoxDecoration(gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFB0BEC5)])))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('STAGE',
                  style: TextStyle(fontSize: 10, color: Color(0xFF78909C),
                      letterSpacing: 4, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Container(height: 1,
                decoration: const BoxDecoration(gradient: LinearGradient(
                    colors: [Color(0xFFB0BEC5), Colors.transparent])))),
          ],
        ),
      ),
    );
  }

  // ─── Booth widget ──────────────────────────────────────────
  Widget _boothWidget(Booth b) {
    final r   = b.toRect(_hallSize);
    final sel = _selected.contains(b);
    final fs  = (r.width * 0.18).clamp(7.0, 11.0);

    return Positioned(
      left: r.left, top: r.top, width: r.width, height: r.height,
      child: GestureDetector(
        onTap: () => _tap(b),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: _fill(b),
            border: Border.all(color: _stroke(b), width: sel ? 2.0 : 1.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: sel
                ? [BoxShadow(color: _kSelected.withOpacity(0.3), blurRadius: 8)]
                : null,
          ),
          child: Stack(children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b.boothNumber,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: fs, color: _label(b),
                          fontWeight: FontWeight.bold,
                          height: 1.1)),
                  if (r.height > 28)
                    Text('RM${b.price.toInt()}',
                        style: TextStyle(
                            fontSize: fs * 0.72,
                            color: _label(b).withOpacity(0.7),
                            height: 1.1)),
                ],
              ),
            ),
            if (sel)
              Positioned(top: 3, right: 3,
                  child: Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: _kSelected),
                  )),
          ]),
        ),
      ),
    );
  }

  // ─── Popup ─────────────────────────────────────────────────
  Widget _popup(Booth b) {
    final sel    = _selected.contains(b);
    final canAct = b.status == 'available';
    final strokeC = _stroke(b);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: strokeC.withOpacity(0.4), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: strokeC.withOpacity(0.12),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        // Colour indicator
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: strokeC.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: strokeC.withOpacity(0.4), width: 1.5),
          ),
          child: Center(child: Text(
            b.boothNumber.split('-').first,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: strokeC),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.boothNumber,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const SizedBox(height: 3),
            Text('${b.type}  ·  RM${b.price.toInt()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: strokeC.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(b.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: strokeC)),
            ),
          ],
        )),
        if (canAct)
          GestureDetector(
            onTap: () => _toggleSelect(b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kBooked : _kSelected,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(sel ? 'Remove' : 'Select',
                  style: const TextStyle(fontSize: 13, color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }

  // ─── Bottom bar ────────────────────────────────────────────
  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _kBorder, width: 1)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, -3))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selected Booths',
                style: TextStyle(fontSize: 11, color: Color(0xFF78909C),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
                '${_selected.length} booth${_selected.length != 1 ? "s" : ""}  ·  RM${_total.toInt()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0))),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 4,
                  children: _selected.map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.08),
                      border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(b.boothNumber,
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600)),
                  )).toList()),
            ],
          ],
        )),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _selected.isEmpty ? null : _proceed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _selected.isEmpty
                  ? const Color(0xFFECEFF1)
                  : const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Continue',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: _selected.isEmpty
                      ? const Color(0xFFB0BEC5)
                      : Colors.white,
                )),
          ),
        ),
      ]),
    );
  }
}
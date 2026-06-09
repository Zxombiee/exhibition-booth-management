import 'dart:io';
import 'package:go_router/go_router.dart';
import '../app_router.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
// BOOTH SHAPE ENUM
// ─────────────────────────────────────────────
enum BoothShape {
  rectangle,
  square,
  circle,
  ellipse,
  triangle,
  pentagon,
  hexagon,
  octagon,
  diamond,
  star,
  arrow,
  lShape,
}

extension BoothShapeExt on BoothShape {
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

  IconData get icon {
    switch (this) {
      case BoothShape.circle:   return Icons.circle_outlined;
      case BoothShape.triangle: return Icons.change_history;
      case BoothShape.diamond:  return Icons.diamond_outlined;
      case BoothShape.star:     return Icons.star_outline;
      default:                  return Icons.crop_square;
    }
  }

  // Default size for each shape when first placed
  Size get defaultSize {
    switch (this) {
      case BoothShape.square:   return const Size(60, 60);
      case BoothShape.circle:   return const Size(60, 60);
      case BoothShape.ellipse:  return const Size(80, 50);
      case BoothShape.triangle: return const Size(70, 60);
      case BoothShape.diamond:  return const Size(60, 60);
      case BoothShape.pentagon: return const Size(65, 65);
      case BoothShape.hexagon:  return const Size(65, 65);
      case BoothShape.octagon:  return const Size(65, 65);
      case BoothShape.star:     return const Size(65, 65);
      case BoothShape.arrow:    return const Size(70, 60);
      case BoothShape.lShape:   return const Size(70, 70);
      default:                  return const Size(70, 50); // rectangle
    }
  }
}

// ─────────────────────────────────────────────
// BOOTH DATA MODEL (in-memory)
// ─────────────────────────────────────────────
class BoothPin {
  String? firestoreId;      // null = not yet saved
  String boothNumber;
  String type;
  double price;
  String status;
  BoothShape shape;

  // Position: normalized 0–1 relative to image widget size
  double nx; // left edge
  double ny; // top edge

  // Size: normalized 0–1 relative to image widget size
  double nw;
  double nh;

  bool isSelected;

  BoothPin({
    this.firestoreId,
    required this.boothNumber,
    required this.type,
    required this.price,
    required this.status,
    required this.shape,
    required this.nx,
    required this.ny,
    required this.nw,
    required this.nh,
    this.isSelected = false,
  });

  factory BoothPin.fromFirestore(String id, Map<String, dynamic> data, Size imageSize) {
    final shape = BoothShape.values.firstWhere(
          (s) => s.name == (data['shape'] ?? 'rectangle'),
      orElse: () => BoothShape.rectangle,
    );
    return BoothPin(
      firestoreId: id,
      boothNumber: data['boothNumber'] ?? '',
      type: data['type'] ?? 'Standard',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      status: data['status'] ?? 'available',
      shape: shape,
      nx: (data['x'] as num?)?.toDouble() ?? 0.1,
      ny: (data['y'] as num?)?.toDouble() ?? 0.1,
      nw: (data['width'] as num?)?.toDouble() ?? (shape.defaultSize.width / imageSize.width),
      nh: (data['height'] as num?)?.toDouble() ?? (shape.defaultSize.height / imageSize.height),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'boothNumber': boothNumber,
    'type': type,
    'price': price,
    'status': status,
    'shape': shape.name,
    'x': nx,
    'y': ny,
    'width': nw,
    'height': nh,
  };

  // Pixel rect given container size
  Rect toRect(Size containerSize) => Rect.fromLTWH(
    nx * containerSize.width,
    ny * containerSize.height,
    nw * containerSize.width,
    nh * containerSize.height,
  );
}

// ─────────────────────────────────────────────
// BOOTH PAINTER (draws the shape)
// ─────────────────────────────────────────────
class BoothPainter extends CustomPainter {
  final BoothPin booth;
  final Color fillColor;
  final Color borderColor;
  final bool showHandles;

  BoothPainter({
    required this.booth,
    required this.fillColor,
    required this.borderColor,
    required this.showHandles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = fillColor;
    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final handlePaint = Paint()..color = Colors.blue.shade700;
    final handleStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    Path path = _buildPath(booth.shape, w, h, cx, cy);

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // Label
    final fontSize = (min(w, h) / 4).clamp(8.0, 13.0);
    final tp = TextPainter(
      text: TextSpan(
        text: booth.boothNumber,
        style: TextStyle(
          color: borderColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Resize handles at 4 corners
    if (showHandles) {
      for (final corner in [
        Offset(0, 0), Offset(w, 0), Offset(0, h), Offset(w, h),
      ]) {
        canvas.drawRect(
          Rect.fromCenter(center: corner, width: 10, height: 10),
          handlePaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: corner, width: 10, height: 10),
          handleStroke,
        );
      }
    }
  }

  Path _buildPath(BoothShape shape, double w, double h, double cx, double cy) {
    switch (shape) {
      case BoothShape.rectangle:
      case BoothShape.square:
        return Path()..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(1.5, 1.5, w - 3, h - 3),
          const Radius.circular(6),
        ));

      case BoothShape.circle:
      case BoothShape.ellipse:
        return Path()..addOval(Rect.fromLTWH(1.5, 1.5, w - 3, h - 3));

      case BoothShape.triangle:
        return Path()
          ..moveTo(cx, 2)
          ..lineTo(w - 2, h - 2)
          ..lineTo(2, h - 2)
          ..close();

      case BoothShape.diamond:
        return Path()
          ..moveTo(cx, 2)
          ..lineTo(w - 2, cy)
          ..lineTo(cx, h - 2)
          ..lineTo(2, cy)
          ..close();

      case BoothShape.pentagon:
        return _polygon(cx, cy, min(cx, cy) - 2, 5, -90);

      case BoothShape.hexagon:
        return _polygon(cx, cy, min(cx, cy) - 2, 6, 0);

      case BoothShape.octagon:
        return _polygon(cx, cy, min(cx, cy) - 2, 8, -22.5);

      case BoothShape.star:
        return _star(cx, cy, min(cx, cy) - 2, (min(cx, cy) - 2) * 0.45);

      case BoothShape.arrow:
        final sw = w * 0.35;
        final ah = h * 0.45;
        return Path()
          ..moveTo(sw, 0)
          ..lineTo(w, ah)
          ..lineTo(w * 0.65, ah)
          ..lineTo(w * 0.65, h)
          ..lineTo(sw * 0.7, h)
          ..lineTo(sw * 0.7, ah)
          ..lineTo(0, ah)
          ..close();

      case BoothShape.lShape:
        final vw = w * 0.42;
        final bh = h * 0.38;
        return Path()
          ..moveTo(0, 0)
          ..lineTo(vw, 0)
          ..lineTo(vw, h - bh)
          ..lineTo(w, h - bh)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    }
  }

  Path _polygon(double cx, double cy, double r, int sides, double startAngle) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (pi / 180) * (360 / sides * i + startAngle);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    return path..close();
  }

  Path _star(double cx, double cy, double outerR, double innerR) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (pi / 180) * (36 * i - 90);
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant BoothPainter old) => true;
}

// ─────────────────────────────────────────────
// COLOUR HELPERS — resolved at call site using boothTypes list
// ─────────────────────────────────────────────
Color _fillForType(String type, List<Map<String, dynamic>> boothTypes) {
  final match = boothTypes.firstWhere(
        (b) => b['type'] == type,
    orElse: () => {'color': Colors.green.value},
  );
  return Color(match['color'] as int).withOpacity(0.25);
}

Color _borderForType(String type, List<Map<String, dynamic>> boothTypes) {
  final match = boothTypes.firstWhere(
        (b) => b['type'] == type,
    orElse: () => {'color': Colors.green.value},
  );
  return Color(match['color'] as int);
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class AdminFloorPlanScreen extends StatefulWidget {
  final String exhibitionId;
  final String exhibitionName;

  const AdminFloorPlanScreen({
    super.key,
    required this.exhibitionId,
    required this.exhibitionName,
  });

  @override
  State<AdminFloorPlanScreen> createState() => _AdminFloorPlanScreenState();
}

// Must be top-level — Dart does not allow enums inside classes
enum _EditMode { add, move, resize }

class _AdminFloorPlanScreenState extends State<AdminFloorPlanScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _floorPlanUrl;
  List<BoothPin> _booths = [];
  bool _isLoading = true;
  bool _isMappingMode    = false;
  bool _showCoordPanel   = false; // manual coordinate panel toggle
  bool _showBottomPanel  = true;  // bottom booth list minimize toggle

  // Booth types loaded from the exhibition doc
  List<Map<String, dynamic>> _boothTypes = [];

  // Stage (optional coordinate area)
  Map<String, double>? _stageData; // {x, y, w, h} normalized
  bool _stageMode = false;         // when true, tapping sets stage position

  _EditMode _editMode = _EditMode.add;

  BoothPin? _selectedBooth;
  BoothShape _currentShape = BoothShape.rectangle;
  String _currentType = 'Standard';

  // Drag/resize tracking
  Offset? _dragStart;
  BoothPin? _draggingBooth;
  double _dragStartNx = 0, _dragStartNy = 0;
  double _dragStartNw = 0, _dragStartNh = 0;
  String _resizeCorner = ''; // 'tl','tr','bl','br'

  // Stage drag tracking
  bool _draggingStage = false;
  double _stageDragStartX = 0, _stageDragStartY = 0;

  // Image container size
  Size _containerSize = Size.zero;
  final GlobalKey _containerKey = GlobalKey();
  Offset? _hoverPosition; // tracks finger position for coordinate display
  double _hoverXPct = 10.0; // synced percentage values for manual input
  double _hoverYPct = 10.0;

  // Width/height slider values (pixel, for display)
  double _sliderW = 70;
  double _sliderH = 50;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  // ── Firestore ──────────────────────────────

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);

    final exhibitionDoc =
    await _firestore.collection('exhibitions').doc(widget.exhibitionId).get();
    if (exhibitionDoc.exists) {
      final data = exhibitionDoc.data()!;
      _floorPlanUrl = data['floorPlanUrl'];

      // Load stage if set
      final stageRaw = data['stage'];
      if (stageRaw is Map) {
        _stageData = {
          'x': (stageRaw['x'] as num?)?.toDouble() ?? 0.3,
          'y': (stageRaw['y'] as num?)?.toDouble() ?? 0.85,
          'w': (stageRaw['w'] as num?)?.toDouble() ?? 0.4,
          'h': (stageRaw['h'] as num?)?.toDouble() ?? 0.12,
        };
      }

      // Load booth types defined by organizer in create_event_screen
      final raw = data['boothTypes'];
      if (raw != null && raw is List && raw.isNotEmpty) {
        _boothTypes = List<Map<String, dynamic>>.from(raw.map((e) => {
          'type':  e['type']  ?? 'Standard',
          'price': e['price'] ?? 0,
          'color': e['color'] ?? Colors.blue.value,
        }));
      } else {
        // Fallback defaults
        _boothTypes = [
          {'type': 'Standard', 'price': 800,  'color': Colors.green.value},
          {'type': 'Premium',  'price': 1500, 'color': Colors.blue.value},
          {'type': 'VIP',      'price': 3000, 'color': Colors.amber.value},
        ];
      }
      // Set current type to first available
      _currentType = _boothTypes.first['type'];
    }

    final boothsSnapshot = await _firestore
        .collection('booths')
        .where('exhibitionId', isEqualTo: widget.exhibitionId)
        .get();

    final cs = _containerSize == Size.zero ? const Size(400, 300) : _containerSize;

    setState(() {
      _booths = boothsSnapshot.docs.map((doc) {
        return BoothPin.fromFirestore(doc.id, doc.data(), cs);
      }).toList();
      _isLoading = false;
    });
  }

  // Save booth types back to Firestore (called from Add Type dialog)
  Future<void> _saveBoothTypesToFirestore() async {
    await _firestore.collection('exhibitions').doc(widget.exhibitionId).update({
      'boothTypes': _boothTypes.map((b) => {
        'type':  b['type'],
        'price': b['price'],
        'color': b['color'],
      }).toList(),
    });
  }

  // ── Stage ───────────────────────────────────────────────────
  Future<void> _saveStage() async {
    if (_stageData == null) return;
    await _firestore.collection('exhibitions').doc(widget.exhibitionId).update({
      'stage': _stageData,
    });
  }

  Future<void> _removeStage() async {
    await _firestore.collection('exhibitions').doc(widget.exhibitionId).update({
      'stage': FieldValue.delete(),
    });
    setState(() { _stageData = null; _stageMode = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stage removed')));
  }

  void _placeStageAt(Offset point) {
    if (_containerSize == Size.zero) return;
    const sw = 0.4, sh = 0.10;
    final nx = (point.dx / _containerSize.width  - sw / 2).clamp(0.0, 1 - sw);
    final ny = (point.dy / _containerSize.height - sh / 2).clamp(0.0, 1 - sh);
    setState(() {
      _stageData = {'x': nx, 'y': ny, 'w': sw, 'h': sh};
      _stageMode = false;
    });
    _saveStage();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stage placed! Long-press to remove.')));
  }

  // Place booth at manually entered coordinates (normalized 0-1)
  void _placeBoothAtCoords(double nx, double ny, double nw, double nh) {
    if (_boothTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a booth type first'),
          backgroundColor: Colors.orange));
      return;
    }
    final type  = _currentType;
    final price = (_boothTypes.firstWhere(
          (b) => b['type'] == type,
      orElse: () => {'price': 0},
    )['price'] as num).toDouble();

    // Auto-generate booth number
    String boothNumber = _generateNextBoothNumber();

    final newBooth = BoothPin(
      boothNumber: boothNumber,
      type: type,
      price: price,
      status: 'available',
      nx: nx, ny: ny, nw: nw, nh: nh,
      shape: _currentShape,
    );
    setState(() => _booths.add(newBooth));
    _saveBooth(newBooth);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Booth $boothNumber placed at '
          'X:${(nx*100).toStringAsFixed(1)}% '
          'Y:${(ny*100).toStringAsFixed(1)}%'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _saveBooth(BoothPin booth) async {
    final data = {
      ...booth.toFirestore(),
      'exhibitionId': widget.exhibitionId,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (booth.firestoreId == null) {
      final ref = await _firestore.collection('booths').add(data);
      booth.firestoreId = ref.id;
    } else {
      await _firestore.collection('booths').doc(booth.firestoreId).update(booth.toFirestore());
    }
  }

  Future<void> _deleteBooth(BoothPin booth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Booth'),
        content: Text('Delete booth ${booth.boothNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (booth.firestoreId != null) {
        await _firestore.collection('booths').doc(booth.firestoreId).delete();
      }
      setState(() {
        _booths.remove(booth);
        if (_selectedBooth == booth) _selectedBooth = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booth ${booth.boothNumber} deleted')),
        );
      }
    }
  }

  // ── Image upload ───────────────────────────

  Future<void> _uploadFloorPlan() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _isLoading = true);
    final file = File(image.path);
    final ref = _storage.ref().child(
        'floorplans/${widget.exhibitionId}_${DateTime.now().millisecondsSinceEpoch}.png');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _firestore
        .collection('exhibitions')
        .doc(widget.exhibitionId)
        .update({'floorPlanUrl': url});
    setState(() {
      _floorPlanUrl = url;
      _isLoading = false;
      _isMappingMode = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Floor plan uploaded! Tap map to add booths.')),
      );
    }
  }

  // ── Container size helper ──────────────────

  void _updateContainerSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.size != _containerSize) {
        setState(() => _containerSize = box.size);
      }
    });
  }

  // ── Hit testing ────────────────────────────

  BoothPin? _boothAtPoint(Offset point) {
    for (final b in _booths.reversed) {
      final r = b.toRect(_containerSize);
      if (r.contains(point)) return b;
    }
    return null;
  }

  String _cornerAt(BoothPin booth, Offset point) {
    final r = booth.toRect(_containerSize);
    const hs = 14.0; // hit size
    if ((point - r.topLeft).distance < hs)     return 'tl';
    if ((point - r.topRight).distance < hs)    return 'tr';
    if ((point - r.bottomLeft).distance < hs)  return 'bl';
    if ((point - r.bottomRight).distance < hs) return 'br';
    return '';
  }

  // ── Gesture handlers ───────────────────────

  void _onTapDown(TapDownDetails details) {
    if (!_isMappingMode) return;
    final point = details.localPosition;

    // Check if tapping on an existing booth
    final hitBooth = _boothAtPoint(point);
    final hittingBooth = hitBooth != null;

    // Only update hover/coord display when NOT hitting a booth
    // so selecting a booth doesn't reset the manual input values
    if (!hittingBooth && _containerSize != Size.zero) {
      setState(() {
        _hoverPosition = point;
        _hoverXPct = (point.dx / _containerSize.width  * 100).clamp(0.0, 99.0);
        _hoverYPct = (point.dy / _containerSize.height * 100).clamp(0.0, 99.0);
      });
    } else if (_containerSize != Size.zero) {
      setState(() => _hoverPosition = point);
    }

    // Stage placement mode takes priority
    if (_stageMode) {
      _placeStageAt(point);
      return;
    }

    if (_editMode == _EditMode.add) {
      _placeBoothAt(point);
    } else {
      // Select booth
      final hit = _boothAtPoint(point);
      setState(() {
        for (final b in _booths) b.isSelected = false;
        if (hit != null) {
          hit.isSelected = true;
          _selectedBooth = hit;
          _sliderW = hit.nw * _containerSize.width;
          _sliderH = hit.nh * _containerSize.height;
        } else {
          _selectedBooth = null;
        }
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!_isMappingMode) return;
    final point = details.localPosition;

    if (_editMode == _EditMode.move) {
      // Check stage first
      if (_stageData != null && _stageHitTest(point)) {
        _draggingStage = true;
        _dragStart = point;
        _stageDragStartX = _stageData!['x']!;
        _stageDragStartY = _stageData!['y']!;
        return;
      }
      // Then booths
      final hit = _boothAtPoint(point);
      if (hit != null) {
        _draggingBooth = hit;
        _dragStart = point;
        _dragStartNx = hit.nx;
        _dragStartNy = hit.ny;
      }
    } else if (_editMode == _EditMode.resize && _selectedBooth != null) {
      final corner = _cornerAt(_selectedBooth!, point);
      if (corner.isNotEmpty) {
        _draggingBooth = _selectedBooth;
        _dragStart = point;
        _dragStartNx = _selectedBooth!.nx;
        _dragStartNy = _selectedBooth!.ny;
        _dragStartNw = _selectedBooth!.nw;
        _dragStartNh = _selectedBooth!.nh;
        _resizeCorner = corner;
      }
    }
  }

  bool _stageHitTest(Offset point) {
    if (_stageData == null || _containerSize == Size.zero) return false;
    final s = _stageData!;
    final r = Rect.fromLTWH(
      s['x']! * _containerSize.width,
      s['y']! * _containerSize.height,
      s['w']! * _containerSize.width,
      s['h']! * _containerSize.height,
    );
    return r.contains(point);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStart == null) return;
    final pos = details.localPosition;
    if (_isMappingMode && _containerSize != Size.zero) {
      setState(() {
        _hoverPosition = pos;
        _hoverXPct = (pos.dx / _containerSize.width  * 100).clamp(0.0, 99.0);
        _hoverYPct = (pos.dy / _containerSize.height * 100).clamp(0.0, 99.0);
      });
    }
    final delta = details.localPosition - _dragStart!;
    final dnx = delta.dx / _containerSize.width;
    final dny = delta.dy / _containerSize.height;

    // Stage drag
    if (_draggingStage && _stageData != null) {
      setState(() {
        _stageData!['x'] = (_stageDragStartX + dnx)
            .clamp(0.0, 1.0 - _stageData!['w']!);
        _stageData!['y'] = (_stageDragStartY + dny)
            .clamp(0.0, 1.0 - _stageData!['h']!);
      });
      return;
    }

    if (_draggingBooth == null) return;
    setState(() {
      final b = _draggingBooth!;
      const minNW = 0.04, minNH = 0.03;

      if (_editMode == _EditMode.move) {
        b.nx = (_dragStartNx + dnx).clamp(0, 1 - b.nw);
        b.ny = (_dragStartNy + dny).clamp(0, 1 - b.nh);
      } else if (_editMode == _EditMode.resize) {
        switch (_resizeCorner) {
          case 'br':
            b.nw = (_dragStartNw + dnx).clamp(minNW, 1 - b.nx);
            b.nh = (_dragStartNh + dny).clamp(minNH, 1 - b.ny);
          case 'bl':
            final newW = (_dragStartNw - dnx).clamp(minNW, 1.0);
            b.nx = _dragStartNx + (_dragStartNw - newW);
            b.nw = newW;
            b.nh = (_dragStartNh + dny).clamp(minNH, 1 - b.ny);
          case 'tr':
            b.nw = (_dragStartNw + dnx).clamp(minNW, 1 - b.nx);
            final newH = (_dragStartNh - dny).clamp(minNH, 1.0);
            b.ny = _dragStartNy + (_dragStartNh - newH);
            b.nh = newH;
          case 'tl':
            final newW = (_dragStartNw - dnx).clamp(minNW, 1.0);
            b.nx = _dragStartNx + (_dragStartNw - newW);
            b.nw = newW;
            final newH = (_dragStartNh - dny).clamp(minNH, 1.0);
            b.ny = _dragStartNy + (_dragStartNh - newH);
            b.nh = newH;
        }
        _sliderW = b.nw * _containerSize.width;
        _sliderH = b.nh * _containerSize.height;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draggingStage) {
      _saveStage();
    } else if (_draggingBooth != null) {
      _saveBooth(_draggingBooth!);
    }
    _draggingBooth = null;
    _draggingStage = false;
    _dragStart = null;
    _resizeCorner = '';
    // Clear coordinate display after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hoverPosition = null);
    });
  }

  // ── Place new booth ────────────────────────

  Future<void> _placeBoothAt(Offset point) async {
    if (_containerSize == Size.zero) return;

    final defaultSz = _currentShape.defaultSize;
    final nw = defaultSz.width / _containerSize.width;
    final nh = defaultSz.height / _containerSize.height;
    final nx = (point.dx / _containerSize.width - nw / 2).clamp(0.0, 1 - nw);
    final ny = (point.dy / _containerSize.height - nh / 2).clamp(0.0, 1 - nh);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddBoothDialog(
        boothNumber: _generateNextBoothNumber(),
        defaultType: _currentType,
        boothTypes: _boothTypes,
      ),
    );
    if (result == null || !mounted) return;

    final booth = BoothPin(
      boothNumber: result['boothNumber'],
      type: result['type'],
      price: result['price'],
      status: 'available',
      shape: _currentShape,
      nx: nx,
      ny: ny,
      nw: nw,
      nh: nh,
    );

    await _saveBooth(booth);
    setState(() => _booths.add(booth));
  }

  String _generateNextBoothNumber() {
    final existing = _booths.map((b) => b.boothNumber).toSet();
    for (final row in ['A', 'B', 'C', 'D']) {
      for (int i = 1; i <= 20; i++) {
        final n = '$row-${i.toString().padLeft(2, '0')}';
        if (!existing.contains(n)) return n;
      }
    }
    return 'Z-01';
  }

  // ── Slider resize ──────────────────────────

  void _applySliderResize(double w, double h) {
    if (_selectedBooth == null || _containerSize == Size.zero) return;
    setState(() {
      _selectedBooth!.nw = (w / _containerSize.width).clamp(0.04, 1.0);
      _selectedBooth!.nh = (h / _containerSize.height).clamp(0.03, 1.0);
    });
    _saveBooth(_selectedBooth!);
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Floor Plan — ${widget.exhibitionName}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFCDD5E0)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildMapArea()),
          if (_isMappingMode) _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: Icon(Icons.map_outlined, size: 64, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 20),
          const Text('No floor plan uploaded yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: Color(0xFF37474F))),
          const SizedBox(height: 6),
          Text('Upload an image to start mapping booths',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _uploadFloorPlan,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Floor Plan Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFCDD5E0), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Row 1: Mode buttons + Edit toggle ──────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              const Text('Mode:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: Color(0xFF546E7A))),
              const SizedBox(width: 8),
              _modeBtn(_EditMode.add,    Icons.add_location_alt,        'Add Booth'),
              const SizedBox(width: 6),
              _modeBtn(_EditMode.move,   Icons.open_with,               'Move'),
              const SizedBox(width: 6),
              _modeBtn(_EditMode.resize, Icons.photo_size_select_small, 'Resize'),
              const SizedBox(width: 6),
              _stageModeBtn(),
              const SizedBox(width: 12),
              if (!_isMappingMode)
                GestureDetector(
                  onTap: () => setState(() => _isMappingMode = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.edit, size: 13, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Edit Map', style: TextStyle(fontSize: 12,
                          color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => setState(() => _isMappingMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCDD5E0)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.check, size: 13, color: Color(0xFF546E7A)),
                      SizedBox(width: 5),
                      Text('Done', style: TextStyle(fontSize: 12,
                          color: Color(0xFF546E7A), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),

          // ── Row 2: Type + Shape (Add mode only) ────────────
          if (_isMappingMode && _editMode == _EditMode.add) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                const Text('Type:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF546E7A))),
                const SizedBox(width: 8),
                ..._boothTypes.map((bt) {
                  final name   = bt['type'] as String;
                  final color  = Color(bt['color'] as int);
                  final active = _currentType == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _currentType = name),
                      onLongPress: () => _confirmRemoveType(name),
                      child: Container(
                        padding: const EdgeInsets.only(
                            left: 12, right: 6, top: 5, bottom: 5),
                        decoration: BoxDecoration(
                          color: active ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color, width: active ? 0 : 1.5),
                        ),
                        child: Row(children: [
                          Text(name,
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : color)),
                          const SizedBox(width: 4),
                          // × remove button
                          GestureDetector(
                            onTap: () => _confirmRemoveType(name),
                            child: Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white.withOpacity(0.25)
                                    : color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 10,
                                  color: active ? Colors.white : color),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: _showAddTypeDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCDD5E0)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add, size: 13, color: Color(0xFF90A4AE)),
                      const SizedBox(width: 4),
                      Text('Add Type',
                          style: TextStyle(fontSize: 12,
                              color: Colors.grey.shade500)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            // Shape row
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: BoothShape.values.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _shapeBtn(s),
                )).toList(),
              ),
            ),
          ],

          // ── Row 3: Booth resize sliders ─────────────────────
          if (_isMappingMode && _editMode == _EditMode.resize &&
              _selectedBooth != null) ...[
            const SizedBox(height: 8),
            _sliderRow('W', _sliderW, 20, 200, (v) {
              setState(() {
                _sliderW = v;
                _selectedBooth!.nw = v / _containerSize.width;
              });
            }, () => _saveBooth(_selectedBooth!)),
            _sliderRow('H', _sliderH, 20, 150, (v) {
              setState(() {
                _sliderH = v;
                _selectedBooth!.nh = v / _containerSize.height;
              });
            }, () => _saveBooth(_selectedBooth!)),
          ],

          // ── Row 4: Stage resize sliders ─────────────────────
          if (_isMappingMode && _stageMode == false &&
              _stageData != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFECEFF1)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.theater_comedy, size: 13, color: Color(0xFF7B1FA2)),
              const SizedBox(width: 5),
              const Text('Stage size:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: Color(0xFF7B1FA2))),
              const Spacer(),
              GestureDetector(
                onTap: _removeStage,
                child: Text('Remove',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade400,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
            _sliderRow('W', (_stageData!['w']! * _containerSize.width).clamp(40, 400),
                40, 400, (v) {
                  setState(() => _stageData!['w'] = v / _containerSize.width);
                }, _saveStage,
                color: Colors.purple),
            _sliderRow('H', (_stageData!['h']! * _containerSize.height).clamp(20, 150),
                20, 150, (v) {
                  setState(() => _stageData!['h'] = v / _containerSize.height);
                }, _saveStage,
                color: Colors.purple),
          ],

          // ── Row 5: Manual coordinate — collapsible (Move mode only) ─
          if (_isMappingMode &&
              _editMode == _EditMode.move &&
              _selectedBooth != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFECEFF1)),
            const SizedBox(height: 6),
            // Toggle button
            GestureDetector(
              onTap: () => setState(() => _showCoordPanel = !_showCoordPanel),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _showCoordPanel
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF1565C0).withOpacity(0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.my_location, size: 13,
                      color: _showCoordPanel
                          ? Colors.white : const Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  Text('Manual Coordinates',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showCoordPanel
                              ? Colors.white : const Color(0xFF1565C0))),
                  const Spacer(),
                  Icon(
                      _showCoordPanel
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: _showCoordPanel
                          ? Colors.white : const Color(0xFF1565C0)),
                ]),
              ),
            ),
            // Collapsible content
            if (_showCoordPanel) ...[
              const SizedBox(height: 6),
              _ManualCoordInput(
                key: ValueKey('move_${_hoverXPct.toStringAsFixed(1)}_${_hoverYPct.toStringAsFixed(1)}'),
                initialX: _hoverXPct,
                initialY: _hoverYPct,
                onApply: (x, y) {
                  final nx = (x / 100).clamp(0.0, 0.95);
                  final ny = (y / 100).clamp(0.0, 0.95);
                  if (_editMode == _EditMode.add) {
                    _placeBoothAtCoords(nx, ny, 0.12, 0.10);
                  } else if (_selectedBooth != null) {
                    setState(() {
                      _selectedBooth!.nx = nx;
                      _selectedBooth!.ny = ny;
                    });
                    _saveBooth(_selectedBooth!);
                  }
                  setState(() => _showCoordPanel = false);
                },
              ),
            ],
          ],

        ],
      ),
    );
  }

  // Stage mode button
  Widget _stageModeBtn() {
    final hasStage = _stageData != null;
    final active   = _stageMode;
    return GestureDetector(
      onTap: () {
        if (hasStage) return; // already placed — use sliders to resize
        setState(() => _stageMode = !_stageMode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? Colors.purple.shade600
              : hasStage
              ? Colors.purple.shade50
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: hasStage || active
                  ? Colors.purple.shade300
                  : const Color(0xFFCDD5E0)),
        ),
        child: Row(children: [
          Icon(Icons.theater_comedy, size: 13,
              color: active
                  ? Colors.white
                  : hasStage
                  ? Colors.purple.shade600
                  : Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
              hasStage ? 'Stage ✓' : (active ? 'Tap map...' : 'Stage'),
              style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : hasStage
                      ? Colors.purple.shade600
                      : Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // Reusable slider row with manual text input
  Widget _sliderRow(
      String label,
      double value,
      double min,
      double max,
      ValueChanged<double> onChanged,
      VoidCallback onEnd, {
        Color color = const Color(0xFF1565C0),
      }) {
    final ctrl = TextEditingController(text: value.round().toString());
    return Row(children: [
      SizedBox(width: 16,
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: color))),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withOpacity(0.15),
            overlayColor: color.withOpacity(0.1),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min, max: max,
            onChanged: onChanged,
            onChangeEnd: (_) => onEnd(),
          ),
        ),
      ),
      // Manual text input for exact value
      SizedBox(
        width: 48,
        height: 28,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: color,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: color.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: color.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            filled: true,
            fillColor: color.withOpacity(0.05),
            suffix: Text('px',
                style: TextStyle(fontSize: 8, color: color.withOpacity(0.6))),
          ),
          onSubmitted: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) {
              onChanged(parsed.clamp(min, max));
              onEnd();
            }
          },
        ),
      ),
    ]);
  }

  Widget _modeBtn(_EditMode mode, IconData icon, String label) {
    final active = _editMode == mode && _isMappingMode;
    return GestureDetector(
      onTap: () => setState(() {
        _editMode = mode;
        _stageMode = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? const Color(0xFF1565C0) : const Color(0xFFCDD5E0)),
        ),
        child: Row(children: [
          Icon(icon, size: 13,
              color: active ? Colors.white : const Color(0xFF546E7A)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF546E7A))),
        ]),
      ),
    );
  }

  // Add a new booth type to the exhibition
  Future<void> _confirmRemoveType(String typeName) async {
    // Check if any placed booths are using this type
    final inUse = _booths.any((b) => b.type == typeName);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Booth Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove "$typeName"?'),
            if (inUse) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber, size: 16,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Some booths on the map are using this type. '
                        'They will keep the type label but lose the colour.',
                    style: TextStyle(fontSize: 12,
                        color: Colors.orange.shade800),
                  )),
                ]),
              ),
            ],
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _boothTypes.removeWhere((b) => b['type'] == typeName);
      // If removed type was selected, switch to first available
      if (_currentType == typeName) {
        _currentType = _boothTypes.isNotEmpty
            ? _boothTypes.first['type'] as String
            : '';
      }
    });
    _saveBoothTypesToFirestore();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$typeName" type removed'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Future<void> _showAddTypeDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddTypeDialog(),
    );
    if (result == null) return;
    setState(() {
      _boothTypes.add(result);
      _currentType = result['type'] as String;
    });
    _saveBoothTypesToFirestore();
  }

  Widget _shapeBtn(BoothShape shape) {
    final active = _currentShape == shape;
    return GestureDetector(
      onTap: () => setState(() => _currentShape = shape),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF1565C0) : const Color(0xFFCDD5E0),
              width: active ? 1.5 : 1),
        ),
        child: Text(shape.label,
            style: TextStyle(fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? const Color(0xFF1565C0) : const Color(0xFF546E7A))),
      ),
    );
  }

  Widget _buildMapArea() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCDD5E0), width: 1.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: GestureDetector(
                onTapDown: _onTapDown,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: LayoutBuilder(builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_containerSize != constraints.biggest) {
                      setState(() => _containerSize = constraints.biggest);
                    }
                  });
                  return Stack(
                    key: _containerKey,
                    children: [
                      // Light grid
                      Positioned.fill(
                        child: CustomPaint(painter: _AdminGridPainter()),
                      ),
                      // Corner marks
                      _adminCorner(top: 8,    left: 8,  tl: true),
                      _adminCorner(top: 8,    right: 8, tr: true),
                      _adminCorner(bottom: 8, left: 8,  bl: true),
                      _adminCorner(bottom: 8, right: 8, br: true),
                      // Booths
                      if (_containerSize != Size.zero)
                        ..._booths.map((b) => _buildBoothWidget(b)),
                      // Stage
                      if (_stageData != null && _containerSize != Size.zero)
                        _buildStageWidget(),
                      // Live coordinate indicator
                      if (_isMappingMode && _hoverPosition != null &&
                          _containerSize != Size.zero)
                        _buildCoordIndicator(_hoverPosition!),
                      // Hint banner
                      if (_isMappingMode)
                        Positioned(
                          bottom: 10, left: 10, right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _stageMode
                                  ? Colors.purple.withOpacity(0.9)
                                  : const Color(0xFF1565C0).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Icon(
                                  _stageMode
                                      ? Icons.theater_comedy
                                      : Icons.touch_app,
                                  color: Colors.white, size: 15),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                _stageMode
                                    ? 'Tap to place stage · Resize using sliders above'
                                    : _editMode == _EditMode.add
                                    ? 'Tap to place a booth'
                                    : _editMode == _EditMode.move
                                    ? 'Drag any booth to move'
                                    : 'Select a booth · drag corners or use sliders',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              )),
                            ]),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _adminCorner({
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

  Widget _buildStageWidget() {
    final s  = _stageData!;
    final px = s['x']! * _containerSize.width;
    final py = s['y']! * _containerSize.height;
    final pw = s['w']! * _containerSize.width;
    final ph = s['h']! * _containerSize.height;
    final isMoveable = _isMappingMode && _editMode == _EditMode.move;

    return Positioned(
      left: px, top: py, width: pw, height: ph,
      child: Container(
        decoration: BoxDecoration(
          color: isMoveable
              ? Colors.purple.shade50.withOpacity(0.95)
              : Colors.purple.shade50,
          border: Border.all(
              color: isMoveable
                  ? Colors.purple.shade400
                  : Colors.purple.shade300,
              width: isMoveable ? 2.0 : 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: OverflowBox(
          maxWidth: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMoveable)
                Icon(Icons.open_with, size: 12, color: Colors.purple.shade300),
              Flexible(child: Container(height: 1,
                  decoration: BoxDecoration(gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.purple.shade200])))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('STAGE',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: Colors.purple.shade400,
                        letterSpacing: 2, fontWeight: FontWeight.bold)),
              ),
              Flexible(child: Container(height: 1,
                  decoration: BoxDecoration(gradient: LinearGradient(
                      colors: [Colors.purple.shade200, Colors.transparent])))),
              if (isMoveable)
                Icon(Icons.open_with, size: 12, color: Colors.purple.shade300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordIndicator(Offset pos) {
    if (_containerSize == Size.zero) return const SizedBox.shrink();
    final xPct = (pos.dx / _containerSize.width  * 100).clamp(0.0, 99.0);
    final yPct = (pos.dy / _containerSize.height * 100).clamp(0.0, 99.0);
    final left = (pos.dx + 10).clamp(0.0, _containerSize.width  - 120);
    final top  = (pos.dy - 28).clamp(4.0, _containerSize.height - 24);

    return Positioned(
      left: left, top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withOpacity(0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'X:${xPct.toStringAsFixed(1)}%  Y:${yPct.toStringAsFixed(1)}%',
          style: const TextStyle(
              fontSize: 10, color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildBoothWidget(BoothPin booth) {
    final rect = booth.toRect(_containerSize);
    final selected = booth.isSelected;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onLongPress: _isMappingMode ? () => _deleteBooth(booth) : null,
        child: CustomPaint(
          painter: BoothPainter(
            booth: booth,
            fillColor: _fillForType(booth.type, _boothTypes),
            borderColor: selected
                ? Colors.blue.shade900
                : _borderForType(booth.type, _boothTypes),
            showHandles: selected && _isMappingMode && _editMode == _EditMode.resize,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      constraints: BoxConstraints(maxHeight: _showBottomPanel ? 200 : 44),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFCDD5E0), width: 1)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          // Header with minimize button
          GestureDetector(
            onTap: () => setState(() => _showBottomPanel = !_showBottomPanel),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(children: [
                Text('Booths (${_booths.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 13, color: Color(0xFF37474F))),
                const Spacer(),
                ..._boothTypes.map((bt) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _legendDot(
                    Color(bt['color'] as int).withOpacity(0.15),
                    Color(bt['color'] as int),
                    bt['type'] as String,
                  ),
                )),
                const SizedBox(width: 8),
                // Minimize / expand icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCDD5E0)),
                  ),
                  child: Icon(
                    _showBottomPanel
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 16,
                    color: const Color(0xFF546E7A),
                  ),
                ),
              ]),
            ),
          ),
          // Only show list when not minimized
          if (_showBottomPanel) ...[
            const Divider(height: 1, color: Color(0xFFECEFF1)),
            Expanded(
              child: _booths.isEmpty
                  ? Center(child: Text('No booths yet · tap the map to add',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _booths.length,
                itemBuilder: (_, i) {
                  final b = _booths[i];
                  final borderColor = _borderForType(b.type, _boothTypes);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 0),
                    leading: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.12),
                        border: Border.all(color: borderColor, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: Text(
                          b.boothNumber.split('-').first,
                          style: TextStyle(fontSize: 10,
                              color: borderColor, fontWeight: FontWeight.bold))),
                    ),
                    title: Text(b.boothNumber,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: Color(0xFF263238))),
                    subtitle: Text('${b.type} · RM${b.price.toInt()} · ${b.shape.label}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                    trailing: _isMappingMode
                        ? IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red.shade300),
                      onPressed: () => _deleteBooth(b),
                    )
                        : null,
                    onTap: () => setState(() {
                      for (final x in _booths) x.isSelected = false;
                      b.isSelected = true;
                      _selectedBooth = b;
                      _sliderW = b.nw * _containerSize.width;
                      _sliderH = b.nh * _containerSize.height;
                    }),
                  );
                },
              ),
            ),
          ], // end if (_showBottomPanel)
        ],
      ),
    );
  }

  Widget _legendDot(Color fill, Color border, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: border, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────
// GRID PAINTER (light theme — same as floor_plan_screen)
// ─────────────────────────────────────────────
class _AdminGridPainter extends CustomPainter {
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

// ─────────────────────────────────────────────────────────────
// MANUAL COORDINATE INPUT WIDGET  (compact)
// ─────────────────────────────────────────────────────────────
class _ManualCoordInput extends StatefulWidget {
  final double initialX, initialY;
  final void Function(double x, double y) onApply;

  const _ManualCoordInput({
    super.key,
    required this.initialX, required this.initialY,
    required this.onApply,
  });

  @override
  State<_ManualCoordInput> createState() => _ManualCoordInputState();
}

class _ManualCoordInputState extends State<_ManualCoordInput> {
  late final TextEditingController _xCtrl;
  late final TextEditingController _yCtrl;

  @override
  void initState() {
    super.initState();
    _xCtrl = TextEditingController(text: widget.initialX.toStringAsFixed(1));
    _yCtrl = TextEditingController(text: widget.initialY.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final x = (double.tryParse(_xCtrl.text) ?? 10.0).clamp(0.0, 95.0);
    final y = (double.tryParse(_yCtrl.text) ?? 10.0).clamp(0.0, 95.0);
    // Only pass X and Y — W and H handled by resize sliders
    widget.onApply(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(children: [
        _field('X  (%)', _xCtrl),
        const SizedBox(width: 6),
        _field('Y  (%)', _yCtrl),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _apply,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Apply',
                style: TextStyle(fontSize: 12,
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: Color(0xFF546E7A))),
          const SizedBox(height: 3),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCDD5E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCDD5E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                    color: Color(0xFF1565C0), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADD TYPE DIALOG — owns controllers, disposes safely in dispose()
// ─────────────────────────────────────────────────────────────
class _AddTypeDialog extends StatefulWidget {
  const _AddTypeDialog();

  @override
  State<_AddTypeDialog> createState() => _AddTypeDialogState();
}

class _AddTypeDialogState extends State<_AddTypeDialog> {
  final _nameCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  Color _picked    = Colors.teal;

  static const _palette = [
    Colors.red, Colors.pink, Colors.purple, Colors.indigo,
    Colors.blue, Colors.teal, Colors.green, Colors.lime,
    Colors.amber, Colors.orange, Colors.brown, Colors.grey,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Booth Type',
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Type Name (e.g. Gold)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (RM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Colour',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _palette.map((c) => GestureDetector(
                onTap: () => setState(() => _picked = c),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _picked == c
                          ? Colors.black : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final name  = _nameCtrl.text.trim();
                    final price =
                        double.tryParse(_priceCtrl.text) ?? 0;
                    if (name.isEmpty || price <= 0) return;
                    Navigator.pop(context, {
                      'type':  name,
                      'price': price,
                      'color': _picked.value,
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD BOOTH DIALOG
// ─────────────────────────────────────────────
class _AddBoothDialog extends StatefulWidget {
  final String boothNumber;
  final String defaultType;
  final List<Map<String, dynamic>> boothTypes;

  const _AddBoothDialog({
    required this.boothNumber,
    required this.defaultType,
    required this.boothTypes,
  });

  @override
  State<_AddBoothDialog> createState() => _AddBoothDialogState();
}

class _AddBoothDialogState extends State<_AddBoothDialog> {
  late final TextEditingController _numCtrl;
  late final TextEditingController _priceCtrl;
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    _numCtrl  = TextEditingController(text: widget.boothNumber);
    // Pre-fill price from boothTypes
    final match = widget.boothTypes.firstWhere(
          (b) => b['type'] == _type,
      orElse: () => {'price': 0},
    );
    _priceCtrl = TextEditingController(text: (match['price'] as num).toInt().toString());
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _type = newType;
      final match = widget.boothTypes.firstWhere(
            (b) => b['type'] == newType,
        orElse: () => {'price': 0},
      );
      _priceCtrl.text = (match['price'] as num).toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Booth'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _numCtrl,
            decoration: const InputDecoration(
              labelText: 'Booth Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: widget.boothTypes.map((bt) {
              final name  = bt['type'] as String;
              final color = Color(bt['color'] as int);
              return DropdownMenuItem(
                value: name,
                child: Row(children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(name),
                ]),
              );
            }).toList(),
            onChanged: (v) { if (v != null) _onTypeChanged(v); },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(
              labelText: 'Price (RM)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'boothNumber': _numCtrl.text.trim().toUpperCase(),
            'type':  _type,
            'price': double.tryParse(_priceCtrl.text) ?? 0,
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import '../services/document_service.dart';

class DocumentScanPage extends StatefulWidget {
  const DocumentScanPage({super.key});
  @override
  State<DocumentScanPage> createState() => _DocumentScanPageState();
}

enum _ScanStep { camera, adjustCorners, filter, uploading, done }

class _DocumentScanPageState extends State<DocumentScanPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _cameraReady = false;
  _ScanStep _step = _ScanStep.camera;
  String? _error;

  // Image data
  Uint8List? _originalBytes;
  int _imgWidth = 0;
  int _imgHeight = 0;

  // Corners (normalized 0-1)
  Offset _tl = const Offset(0.05, 0.05);
  Offset _tr = const Offset(0.95, 0.05);
  Offset _bl = const Offset(0.05, 0.95);
  Offset _br = const Offset(0.95, 0.95);

  // Filter
  DocFilter _selectedFilter = DocFilter.original;
  Uint8List? _croppedBytes;
  Uint8List? _filteredBytes;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { setState(() => _error = 'Nema kamere'); return; }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Greska kamere: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_cameraReady || _processing) return;
    setState(() => _processing = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();

      // Get image dimensions
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Ne mogu da procitam sliku');

      _originalBytes = bytes;
      _imgWidth = decoded.width;
      _imgHeight = decoded.height;

      setState(() { _step = _ScanStep.adjustCorners; _processing = false; _error = null; });

      // AI edge detection in background
      _detectEdges(bytes);
    } catch (e) {
      setState(() { _processing = false; _error = e.toString(); });
    }
  }

  Future<void> _detectEdges(Uint8List bytes) async {
    setState(() => _processing = true);
    try {
      final corners = await DocumentService.detectEdges(bytes);
      if (mounted && _step == _ScanStep.adjustCorners) {
        setState(() {
          _tl = Offset(corners.topLeft.dx / _imgWidth, corners.topLeft.dy / _imgHeight);
          _tr = Offset(corners.topRight.dx / _imgWidth, corners.topRight.dy / _imgHeight);
          _bl = Offset(corners.bottomLeft.dx / _imgWidth, corners.bottomLeft.dy / _imgHeight);
          _br = Offset(corners.bottomRight.dx / _imgWidth, corners.bottomRight.dy / _imgHeight);
          _processing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cropAndProceed() async {
    if (_originalBytes == null) return;
    setState(() { _processing = true; _error = null; });
    try {
      final corners = DocCorners(
        topLeft: Offset(_tl.dx * _imgWidth, _tl.dy * _imgHeight),
        topRight: Offset(_tr.dx * _imgWidth, _tr.dy * _imgHeight),
        bottomLeft: Offset(_bl.dx * _imgWidth, _bl.dy * _imgHeight),
        bottomRight: Offset(_br.dx * _imgWidth, _br.dy * _imgHeight),
      );
      _croppedBytes = DocumentService.perspectiveCrop(_originalBytes!, corners);
      _filteredBytes = _croppedBytes;
      _selectedFilter = DocFilter.original;
      setState(() { _step = _ScanStep.filter; _processing = false; });
    } catch (e) {
      setState(() { _processing = false; _error = e.toString(); });
    }
  }

  void _onFilterChanged(DocFilter filter) {
    if (_croppedBytes == null || filter == _selectedFilter) return;
    setState(() { _selectedFilter = filter; _processing = true; });
    Future.microtask(() {
      final filtered = DocumentService.applyFilter(_croppedBytes!, filter);
      if (mounted) setState(() { _filteredBytes = filtered; _processing = false; });
    });
  }

  Future<void> _uploadDocument() async {
    if (_filteredBytes == null) return;
    setState(() { _step = _ScanStep.uploading; _error = null; });
    try {
      await DocumentService.generateAndUpload(_filteredBytes!);
      setState(() => _step = _ScanStep.done);
    } catch (e) {
      setState(() { _step = _ScanStep.filter; _error = e.toString(); });
    }
  }

  void _retake() {
    setState(() {
      _step = _ScanStep.camera;
      _originalBytes = null;
      _croppedBytes = null;
      _filteredBytes = null;
      _error = null;
      _processing = false;
      _selectedFilter = DocFilter.original;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _ScanStep.camera:
        return _buildCamera();
      case _ScanStep.adjustCorners:
        return _buildCornerAdjust();
      case _ScanStep.filter:
        return _buildFilterScreen();
      case _ScanStep.uploading:
        return _buildUploading();
      case _ScanStep.done:
        return _buildDone();
    }
  }

  // ==================== CAMERA ====================
  Widget _buildCamera() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_cameraReady && _controller != null)
              Positioned.fill(child: CameraPreview(_controller!))
            else
              const Center(child: CircularProgressIndicator(color: Color(0xFF6FDDCE))),

            if (_cameraReady) Positioned.fill(child: CustomPaint(painter: _DocOverlayPainter())),

            Positioned(top: 0, left: 0, right: 0,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => context.go('/home')),
                  const Spacer(),
                  const Text('Postavite dokument u okvir', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(), const SizedBox(width: 48),
                ]),
              ),
            ),

            Positioned(bottom: 40, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _processing ? null : _capture,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _processing ? Colors.grey : Colors.white,
                      border: Border.all(color: const Color(0xFF6FDDCE), width: 4),
                    ),
                    child: _processing
                      ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: Color(0xFF6FDDCE), strokeWidth: 3))
                      : const Icon(Icons.camera_alt, size: 36, color: Colors.black),
                  ),
                ),
              ),
            ),

            if (_error != null) _buildError(),
          ],
        ),
      ),
    );
  }

  // ==================== CORNER ADJUST ====================
  Widget _buildCornerAdjust() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _retake),
                const Spacer(),
                if (_processing)
                  const Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF6FDDCE), strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('AI detektuje ivice...', style: TextStyle(color: Color(0xFF6FDDCE), fontSize: 13)),
                  ])
                else
                  const Text('Pomerite uglove po potrebi', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(), const SizedBox(width: 48),
              ]),
            ),

            // Image with draggable corners
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, constraints) {
                  if (_originalBytes == null) return const SizedBox();

                  // Calculate image display rect
                  final imgAspect = _imgWidth / _imgHeight;
                  final boxAspect = constraints.maxWidth / constraints.maxHeight;
                  double displayW, displayH, offsetX, offsetY;

                  if (imgAspect > boxAspect) {
                    displayW = constraints.maxWidth;
                    displayH = displayW / imgAspect;
                    offsetX = 0;
                    offsetY = (constraints.maxHeight - displayH) / 2;
                  } else {
                    displayH = constraints.maxHeight;
                    displayW = displayH * imgAspect;
                    offsetX = (constraints.maxWidth - displayW) / 2;
                    offsetY = 0;
                  }

                  return Stack(
                    children: [
                      // Image
                      Positioned(
                        left: offsetX, top: offsetY,
                        width: displayW, height: displayH,
                        child: Image.memory(_originalBytes!, fit: BoxFit.fill),
                      ),

                      // Corner overlay
                      Positioned(
                        left: offsetX, top: offsetY,
                        width: displayW, height: displayH,
                        child: CustomPaint(
                          painter: _CornerOverlayPainter(
                            tl: _tl, tr: _tr, bl: _bl, br: _br,
                          ),
                        ),
                      ),

                      // Draggable corners
                      _buildDragCorner('tl', _tl, offsetX, offsetY, displayW, displayH),
                      _buildDragCorner('tr', _tr, offsetX, offsetY, displayW, displayH),
                      _buildDragCorner('bl', _bl, offsetX, offsetY, displayW, displayH),
                      _buildDragCorner('br', _br, offsetX, offsetY, displayW, displayH),
                    ],
                  );
                }),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _retake,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                      child: const Text('PONOVO', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _processing ? null : _cropAndProceed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _processing ? Colors.grey : const Color(0xFF6FDDCE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('ISECI', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragCorner(String id, Offset pos, double ox, double oy, double dw, double dh) {
    const radius = 20.0;
    final cx = ox + pos.dx * dw;
    final cy = oy + pos.dy * dh;

    return Positioned(
      left: cx - radius,
      top: cy - radius,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newX = ((cx + details.delta.dx - ox) / dw).clamp(0.0, 1.0);
          final newY = ((cy + details.delta.dy - oy) / dh).clamp(0.0, 1.0);
          setState(() {
            switch (id) {
              case 'tl': _tl = Offset(newX, newY); break;
              case 'tr': _tr = Offset(newX, newY); break;
              case 'bl': _bl = Offset(newX, newY); break;
              case 'br': _br = Offset(newX, newY); break;
            }
          });
        },
        child: Container(
          width: radius * 2, height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6FDDCE),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      ),
    );
  }

  // ==================== FILTER ====================
  Widget _buildFilterScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() => _step = _ScanStep.adjustCorners)),
                const Spacer(),
                const Text('Izaberite filter', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(), const SizedBox(width: 48),
              ]),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    if (_filteredBytes != null)
                      Center(child: Image.memory(_filteredBytes!, fit: BoxFit.contain)),
                    if (_processing)
                      const Center(child: CircularProgressIndicator(color: Color(0xFF6FDDCE))),
                  ],
                ),
              ),
            ),

            // Filter options
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterOption(DocFilter.original, Icons.image, 'Original'),
                  _buildFilterOption(DocFilter.blackWhite, Icons.contrast, 'B&W'),
                  _buildFilterOption(DocFilter.highContrast, Icons.brightness_high, 'Kontrast'),
                  _buildFilterOption(DocFilter.sharp, Icons.auto_fix_high, 'Ostro'),
                ],
              ),
            ),

            // Upload button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _retake,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                      child: const Text('PONOVO', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _uploadDocument,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                      child: const Text('SACUVAJ', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ]),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(DocFilter filter, IconData icon, String label) {
    final selected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => _onFilterChanged(filter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? const Color(0xFF6FDDCE) : const Color(0xFF2C2C2E),
              border: selected ? Border.all(color: const Color(0xFF6FDDCE), width: 2) : null,
            ),
            child: Icon(icon, color: selected ? Colors.black : Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: selected ? const Color(0xFF6FDDCE) : Colors.grey,
            fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  // ==================== UPLOADING ====================
  Widget _buildUploading() {
    return const Scaffold(
      backgroundColor: Color(0xFF1C1C1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6FDDCE)),
            SizedBox(height: 24),
            Text('Generisem PDF i cuvam...', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ==================== DONE ====================
  Widget _buildDone() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF6FDDCE), size: 80),
              const SizedBox(height: 16),
              const Text('Dokument sacuvan!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _retake,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF6FDDCE)), borderRadius: BorderRadius.circular(12)),
                  child: const Text('SKENIRAJ JOS', style: TextStyle(color: Color(0xFF6FDDCE), fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                  child: const Text('GOTOVO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Positioned(
      bottom: 130, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
        child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}

// ==================== PAINTERS ====================
class _DocOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.4);
    final double padH = size.width * 0.06;
    final double padV = size.height * 0.12;
    final rect = Rect.fromLTRB(padH, padV, size.width - padH, size.height - padV);

    canvas.drawPath(
      Path.combine(PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ), paint,
    );

    final borderPaint = Paint()..color = const Color(0xFF6FDDCE)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerOverlayPainter extends CustomPainter {
  final Offset tl, tr, bl, br;
  _CornerOverlayPainter({required this.tl, required this.tr, required this.bl, required this.br});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(tl.dx * size.width, tl.dy * size.height),
      Offset(tr.dx * size.width, tr.dy * size.height),
      Offset(br.dx * size.width, br.dy * size.height),
      Offset(bl.dx * size.width, bl.dy * size.height),
    ];

    // Semi-transparent fill
    final fillPaint = Paint()..color = const Color(0xFF6FDDCE).withOpacity(0.15)..style = PaintingStyle.fill;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    path.close();
    canvas.drawPath(path, fillPaint);

    // Border lines
    final linePaint = Paint()..color = const Color(0xFF6FDDCE)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CornerOverlayPainter old) =>
    old.tl != tl || old.tr != tr || old.bl != bl || old.br != br;
}

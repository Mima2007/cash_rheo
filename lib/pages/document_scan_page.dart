import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import '../services/document_service.dart';

class DocumentScanPage extends StatefulWidget {
  const DocumentScanPage({super.key});
  @override
  State<DocumentScanPage> createState() => _DocumentScanPageState();
}

class _DocumentScanPageState extends State<DocumentScanPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initialized = false;
  bool _capturing = false;
  bool _processing = false;
  bool _done = false;
  String? _error;
  Uint8List? _capturedBytes;

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
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Greska kamere: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_initialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      setState(() { _capturedBytes = bytes; _capturing = false; });
    } catch (e) {
      setState(() { _capturing = false; _error = e.toString(); });
    }
  }

  Future<void> _process() async {
    if (_capturedBytes == null) return;
    setState(() { _processing = true; _error = null; });
    try {
      await DocumentService.scanAndUpload(_capturedBytes!);
      setState(() { _processing = false; _done = true; });
    } catch (e) {
      setState(() { _processing = false; _error = e.toString(); });
    }
  }

  void _retake() {
    setState(() { _capturedBytes = null; _done = false; _error = null; });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedBytes != null) return _buildPreview();
    return _buildCamera();
  }

  Widget _buildCamera() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Kamera fullscreen
            if (_initialized && _controller != null)
              Positioned.fill(
                child: CameraPreview(_controller!),
              )
            else
              const Center(child: CircularProgressIndicator(color: Color(0xFF6FDDCE))),

            // Overlay sa okvirom dokumenta
            if (_initialized)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DocumentOverlayPainter(),
                ),
              ),

            // Gornji bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => context.go('/home'),
                    ),
                    const Spacer(),
                    const Text('Postavite dokument u okvir',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Dugme za slikanje
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _capturing ? null : _capture,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _capturing ? Colors.grey : Colors.white,
                      border: Border.all(color: const Color(0xFF6FDDCE), width: 4),
                    ),
                    child: _capturing
                      ? const CircularProgressIndicator(color: Color(0xFF6FDDCE))
                      : const Icon(Icons.camera_alt, size: 36, color: Colors.black),
                  ),
                ),
              ),
            ),

            if (_error != null)
              Positioned(
                bottom: 130, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(_capturedBytes!, fit: BoxFit.contain),
                  ),
                  if (_processing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF6FDDCE)),
                            SizedBox(height: 20),
                            Text('AI obradjuje dokument...', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  if (_done)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF6FDDCE), size: 80),
                            SizedBox(height: 16),
                            Text('Dokument sacuvan!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.withOpacity(0.2),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1C1C1E),
              child: _done
                ? GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                      child: const Text('GOTOVO', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _processing ? null : _retake,
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
                          onTap: _processing ? null : _process,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _processing ? Colors.grey : const Color(0xFF6FDDCE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _processing ? 'OBRADJUJEM...' : 'OBRADI I SACUVAJ',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5);
    final double padH = size.width * 0.06;
    final double padV = size.height * 0.15;
    final rect = Rect.fromLTRB(padH, padV, size.width - padH, size.height - padV);

    // Tamni overlay oko dokumenta
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      paint,
    );

    // Zeleni okvir
    final borderPaint = Paint()
      ..color = const Color(0xFF6FDDCE)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);

    // Ugaoni markeri
    final cornerPaint = Paint()
      ..color = const Color(0xFF6FDDCE)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cornerLen = 28.0;

    // Gornji levi
    canvas.drawLine(Offset(rect.left, rect.top + cornerLen), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), cornerPaint);
    // Gornji desni
    canvas.drawLine(Offset(rect.right - cornerLen, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), cornerPaint);
    // Donji levi
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLen), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), cornerPaint);
    // Donji desni
    canvas.drawLine(Offset(rect.right - cornerLen, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

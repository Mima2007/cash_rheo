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

enum _Step { camera, processing, done, error }

class _DocumentScanPageState extends State<DocumentScanPage> {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _capturing = false;
  _Step _step = _Step.camera;
  String _statusMsg = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { setState(() { _step = _Step.error; _error = 'Nema kamere'; }); return; }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() { _step = _Step.error; _error = 'Greska kamere: $e'; });
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_cameraReady || _capturing) return;
    setState(() => _capturing = true);

    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      _controller?.dispose();
      _controller = null;

      setState(() { _step = _Step.processing; _statusMsg = 'AI analizira dokument...'; });

      // Everything is automatic from here
      setState(() => _statusMsg = 'Isecam i cistim dokument...');
      await DocumentService.scanAndUpload(bytes);

      setState(() => _step = _Step.done);
    } catch (e) {
      setState(() { _step = _Step.error; _error = e.toString(); });
    }
  }

  void _retake() {
    setState(() {
      _step = _Step.camera;
      _error = null;
      _capturing = false;
      _cameraReady = false;
    });
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.camera: return _buildCamera();
      case _Step.processing: return _buildProcessing();
      case _Step.done: return _buildDone();
      case _Step.error: return _buildError();
    }
  }

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

            // Top bar
            Positioned(top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent]),
                ),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => context.go('/home')),
                  const Spacer(),
                  const Text('Postavite dokument u okvir', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(), const SizedBox(width: 48),
                ]),
              ),
            ),

            // Capture button
            Positioned(bottom: 40, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _capturing ? null : _capture,
                  child: Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _capturing ? Colors.grey : Colors.white,
                      border: Border.all(color: const Color(0xFF6FDDCE), width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
                    ),
                    child: _capturing
                      ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF6FDDCE), strokeWidth: 3))
                      : const Icon(Icons.camera_alt, size: 36, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(color: Color(0xFF6FDDCE), strokeWidth: 3),
            ),
            const SizedBox(height: 32),
            Text(_statusMsg, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Ovo moze potrajati nekoliko sekundi', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

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
              const Text('Dokument sacuvan!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('PDF generisan i uploadovan', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _retake,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF6FDDCE)), borderRadius: BorderRadius.circular(12)),
                  child: const Text('SKENIRAJ JOS', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6FDDCE), fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                  child: const Text('GOTOVO', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(_error ?? 'Nepoznata greska', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 15)),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _retake,
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                    child: const Text('POKUSAJ PONOVO', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: const Text('Nazad', style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.35);
    final padH = size.width * 0.05;
    final padV = size.height * 0.10;
    final rect = Rect.fromLTRB(padH, padV, size.width - padH, size.height - padV);

    canvas.drawPath(
      Path.combine(PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ), paint,
    );

    final borderPaint = Paint()..color = const Color(0xFF6FDDCE)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);

    // Corner accents
    final cp = Paint()..color = const Color(0xFF6FDDCE)..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const cl = 24.0;
    // TL
    canvas.drawLine(Offset(rect.left, rect.top + cl), Offset(rect.left, rect.top), cp);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cl, rect.top), cp);
    // TR
    canvas.drawLine(Offset(rect.right - cl, rect.top), Offset(rect.right, rect.top), cp);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cl), cp);
    // BL
    canvas.drawLine(Offset(rect.left, rect.bottom - cl), Offset(rect.left, rect.bottom), cp);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cl, rect.bottom), cp);
    // BR
    canvas.drawLine(Offset(rect.right - cl, rect.bottom), Offset(rect.right, rect.bottom), cp);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cl), cp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

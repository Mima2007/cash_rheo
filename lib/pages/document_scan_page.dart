import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'dart:typed_data';
import '../services/document_service.dart';

class DocumentScanPage extends StatefulWidget {
  const DocumentScanPage({super.key});
  @override
  State<DocumentScanPage> createState() => _DocumentScanPageState();
}

enum _Step { scanning, preview, uploading, done, error }

class _DocumentScanPageState extends State<DocumentScanPage> {
  _Step _step = _Step.scanning;
  List<String> _scannedPaths = [];
  int _currentPage = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScanner();
  }

  Future<void> _startScanner() async {
    try {
      final images = await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        isGalleryImportAllowed: true,
      ) ?? [];

      if (images.isEmpty) {
        if (mounted) context.go('/home');
        return;
      }

      setState(() {
        _scannedPaths = images;
        _step = _Step.preview;
      });
    } catch (e) {
      if (mounted) setState(() { _step = _Step.error; _error = e.toString(); });
    }
  }

  Future<void> _upload() async {
    setState(() { _step = _Step.uploading; _error = null; });
    try {
      for (final path in _scannedPaths) {
        final bytes = await File(path).readAsBytes();
        await DocumentService.scanAndUpload(bytes);
      }
      setState(() => _step = _Step.done);
    } catch (e) {
      setState(() { _step = _Step.error; _error = e.toString(); });
    }
  }

  void _scanMore() {
    setState(() => _step = _Step.scanning);
    _startScanner();
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.scanning:
        return const Scaffold(
          backgroundColor: Color(0xFF1C1C1E),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF6FDDCE))),
        );
      case _Step.preview: return _buildPreview();
      case _Step.uploading: return _buildUploading();
      case _Step.done: return _buildDone();
      case _Step.error: return _buildError();
    }
  }

  Widget _buildPreview() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => context.go('/home'),
                  ),
                  const Spacer(),
                  Text(
                    '${_scannedPaths.length} ${_scannedPaths.length == 1 ? 'stranica' : 'stranice'}',
                    style: const TextStyle(color: Color(0xFF6FDDCE), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Add more pages
                  IconButton(
                    icon: const Icon(Icons.add_a_photo, color: Color(0xFF6FDDCE), size: 26),
                    onPressed: () async {
                      final more = await CunningDocumentScanner.getPictures(
                        noOfPages: 10,
                        isGalleryImportAllowed: true,
                      ) ?? [];
                      if (more.isNotEmpty) {
                        setState(() => _scannedPaths.addAll(more));
                      }
                    },
                  ),
                ],
              ),
            ),

            // Page indicator
            if (_scannedPaths.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_currentPage + 1} / ${_scannedPaths.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

            // Image preview
            Expanded(
              child: PageView.builder(
                itemCount: _scannedPaths.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_scannedPaths[index]),
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Delete current page
            if (_scannedPaths.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _scannedPaths.removeAt(_currentPage);
                      if (_currentPage >= _scannedPaths.length) {
                        _currentPage = _scannedPaths.length - 1;
                      }
                    });
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 4),
                      Text('Obriši ovu stranicu', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ),
                ),
              ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _scanMore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF6FDDCE)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('PONOVO', textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6FDDCE), fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _upload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6FDDCE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('SAČUVAJ', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildUploading() {
    return const Scaffold(
      backgroundColor: Color(0xFF1C1C1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 60, height: 60,
              child: CircularProgressIndicator(color: Color(0xFF6FDDCE), strokeWidth: 3)),
            SizedBox(height: 32),
            Text('Generišem PDF i čuvam...', style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 12),
            Text('Ovo može potrajati nekoliko sekundi', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
              const Text('Dokument sačuvan!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${_scannedPaths.length} ${_scannedPaths.length == 1 ? 'stranica' : 'stranice'} uploadovano',
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () { _scannedPaths = []; _currentPage = 0; _scanMore(); },
                child: Container(
                  width: 220, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF6FDDCE)), borderRadius: BorderRadius.circular(12)),
                  child: const Text('SKENIRAJ JOŠ', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6FDDCE), fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  width: 220, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                  child: const Text('GOTOVO', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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
                Text(_error ?? 'Nepoznata greška', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 15)),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _scanMore,
                  child: Container(
                    width: 220, padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                    child: const Text('POKUŠAJ PONOVO', textAlign: TextAlign.center,
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

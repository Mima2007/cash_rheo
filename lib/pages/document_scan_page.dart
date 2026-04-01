import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/document_service.dart';

class DocumentScanPage extends StatefulWidget {
  const DocumentScanPage({super.key});
  @override
  State<DocumentScanPage> createState() => _DocumentScanPageState();
}

class _DocumentScanPageState extends State<DocumentScanPage> {
  Uint8List? _imageBytes;
  bool _processing = false;
  bool _done = false;
  String? _error;
  final _picker = ImagePicker();

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _done = false;
        _error = null;
      });
    }
  }

  Future<void> _process() async {
    if (_imageBytes == null) return;
    setState(() { _processing = true; _error = null; });
    try {
      await DocumentService.scanAndUpload(_imageBytes!, 1200, 1600);
      setState(() { _processing = false; _done = true; });
    } catch (e) {
      setState(() { _processing = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Skeniraj dokument', style: TextStyle(color: Colors.white)),
      ),
      body: _imageBytes == null ? _buildCamera() : _buildPreview(),
    );
  }

  Widget _buildCamera() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 260,
            height: 360,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF6FDDCE), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.document_scanner_outlined, size: 72, color: Color(0xFF6FDDCE)),
                SizedBox(height: 16),
                Text('Postavite dokument\nu okvir', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF6FDDCE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: Colors.black),
                  SizedBox(width: 10),
                  Text('SLIKAJ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black,
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
              if (_processing)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
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
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF6FDDCE), size: 72),
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
                      onTap: _processing ? null : () => setState(() { _imageBytes = null; _error = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('PONOVO', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
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
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';

class DocumentScanPage extends StatefulWidget {
  const DocumentScanPage({super.key});
  @override
  State<DocumentScanPage> createState() => _DocumentScanPageState();
}

class _DocumentScanPageState extends State<DocumentScanPage> {
  bool _processing = false;
  bool _done = false;
  String? _error;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    // Odmah otvori scanner
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    setState(() { _processing = false; _done = false; _error = null; });

    try {
      final images = await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        isGalleryImportAllowed: false,
      ) ?? [];

      if (images.isEmpty) {
        if (mounted) context.go('/home');
        return;
      }

      // Odmah obradi i pošalji — bez preview-a, bez filtera
      setState(() { _processing = true; _pageCount = images.length; });

      for (final path in images) {
        final bytes = await File(path).readAsBytes();
        if (AuthService.isB2C) { await DocumentService.shareViaMail(bytes, AuthService.userEmail ?? ""); } else { await DocumentService.uploadDirect(bytes); }
      }

      setState(() { _processing = false; _done = true; });
    } catch (e) {
      setState(() { _processing = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDone();
    if (_error != null) return _buildError();
    if (_processing) return _buildProcessing();

    // Scanner je otvoren, prikazujemo loading dok se ne vrati
    return const Scaffold(
      backgroundColor: Color(0xFF1C1C1E),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF6FDDCE))),
    );
  }

  Widget _buildProcessing() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 56, height: 56,
              child: CircularProgressIndicator(color: Color(0xFF6FDDCE), strokeWidth: 3)),
            const SizedBox(height: 28),
            Text('Čuvam $_pageCount ${_pageCount == 1 ? 'stranicu' : 'stranice'}...',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
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
              Text(AuthService.isB2C ? 'Poslato' : 'Sačuvano!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _scan,
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
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 14)),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _scan,
                  child: Container(
                    width: 220, padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                    child: const Text('PONOVO', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

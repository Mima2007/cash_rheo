import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});
  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _loading = false;
  bool _scanned = false;
  Map<String, dynamic>? _receiptData;
  String? _error;

  Future<void> _processQR(String url) async {
    if (_loading || _scanned) return;
    setState(() { _loading = true; _scanned = true; _error = null; });
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() { _receiptData = data; _loading = false; });
      } else {
        setState(() { _error = 'Greska: ${response.statusCode}'; _loading = false; _scanned = false; });
      }
    } catch (e) {
      setState(() { _error = 'Nije moguce povezati se sa serverom'; _loading = false; _scanned = false; });
    }
  }

  void _reset() {
    setState(() { _scanned = false; _receiptData = null; _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skeniraj QR'),
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
      ),
      body: _receiptData != null ? _buildReceipt() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null && barcode!.rawValue!.contains('suf.purs.gov.rs')) {
              _processQR(barcode.rawValue!);
            }
          },
        ),
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF6FDDCE), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFF6FDDCE))),
        if (_error != null) Positioned(
          bottom: 100,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Text('Usmerite kameru na QR kod fiskalnog racuna', style: TextStyle(color: Colors.grey[400], fontSize: 14), textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildReceipt() {
    final journal = _receiptData!['journal'] as String? ?? '';
    final invoiceResult = _receiptData!['invoiceResult'] as Map<String, dynamic>?;
    final pfrNumber = invoiceResult?['invoiceNumber'] ?? 'nepoznat';
    final isValid = _receiptData!['isValid'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isValid ? Icons.check_circle : Icons.error, color: isValid ? const Color(0xFF6FDDCE) : Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(isValid ? 'Racun je ispravan' : 'Racun nije ispravan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isValid ? const Color(0xFF6FDDCE) : Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Text('PFR: $pfrNumber', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3C)),
              ),
              child: SingleChildScrollView(
                child: Text(journal, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white, height: 1.4)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('PONOVO'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, side: const BorderSide(color: Colors.grey), padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: sacuvaj u Supabase
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Racun sacuvan!')));
                    context.go('/home');
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('POSALJI'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

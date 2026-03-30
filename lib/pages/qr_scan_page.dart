import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../services/receipt_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});
  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController? _controller;
  bool _loading = false;
  bool _torchOn = false;
  bool _serialMode = false;
  final List<Map<String, dynamic>> _receipts = [];
  final Set<String> _scannedUrls = {};
  bool _showResults = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _onQRDetected(String url) {
    if (_loading || _scannedUrls.contains(url)) return;
    if (!url.contains('suf.purs.gov.rs')) return;
    _scannedUrls.add(url);
    _fetchReceipt(url);
  }

  Future<void> _fetchReceipt(String url) async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        data['_qrUrl'] = url;
        setState(() {
          _receipts.add(data);
          _loading = false;
        });
        if (!_serialMode) {
          _controller?.stop();
          setState(() => _showResults = true);
        }
      } else {
        _scannedUrls.remove(url);
        setState(() => _loading = false);
      }
    } catch (e) {
      _scannedUrls.remove(url);
      setState(() => _loading = false);
    }
  }

  Future<void> _takePhoto() async {
    _controller?.stop();
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      final receipt = <String, dynamic>{
        '_isPhoto': true,
        '_photoBytes': bytes,
        'journal': '',
        'isValid': null,
      };
      setState(() {
        _receipts.add(receipt);
        if (!_serialMode) {
          _showResults = true;
        } else {
          _controller?.start();
        }
      });
    } else {
      _controller?.start();
    }
  }

  void _finishSerial() {
    _controller?.stop();
    setState(() => _showResults = true);
  }

  void _resetAll() {
    setState(() {
      _receipts.clear();
      _scannedUrls.clear();
      _showResults = false;
      _loading = false;
    });
    _controller?.start();
  }

  Future<void> _saveReceipts() async {
    setState(() => _loading = true);
    try {
      await ReceiptService.saveReceipts(_receipts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_receipts.length} racuna sacuvano!'), backgroundColor: const Color(0xFF6FDDCE)));
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greska: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _showResults ? _buildResults() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.78;
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              if (barcode.rawValue != null) _onQRDetected(barcode.rawValue!);
            }
          },
        ),
        CustomPaint(
          painter: _ScanOverlayPainter(scanArea: scanSize),
          child: const SizedBox.expand(),
        ),
        Center(
          child: Container(
            width: scanSize,
            height: scanSize,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF6FDDCE), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => context.go('/home')),
                    IconButton(
                      icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: _torchOn ? const Color(0xFF6FDDCE) : Colors.white, size: 28),
                      onPressed: () {
                        _controller?.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _serialMode = !_serialMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _serialMode ? const Color(0xFF6FDDCE) : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, size: 18, color: _serialMode ? Colors.black : Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _serialMode ? 'SERIJSKI MOD' : 'Pojedinacno',
                          style: TextStyle(color: _serialMode ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading) Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
            child: const CircularProgressIndicator(color: Color(0xFF6FDDCE)),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 24,
          right: 24,
          child: Column(
            children: [
              if (_serialMode && _receipts.isNotEmpty) ...[
                Text('Skenirano: ${_receipts.length}', style: const TextStyle(color: Color(0xFF6FDDCE), fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _finishSerial,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF6FDDCE), borderRadius: BorderRadius.circular(12)),
                    child: Text('GOTOVO (${_receipts.length})', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Ne cita QR? Uslikaj racun', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1C1C1E),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/home')),
                const SizedBox(width: 8),
                Text('${_receipts.length} ${_receipts.length == 1 ? 'racun' : 'racuna'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF6FDDCE))),
                const Spacer(),
                if (_receipts.length > 1) Text('Prevucite levo/desno', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              itemCount: _receipts.length,
              itemBuilder: (context, index) {
                final receipt = _receipts[index];
                final isPhoto = receipt['_isPhoto'] == true;
                if (isPhoto) {
                  return Container(
                    color: Colors.white,
                    child: Center(child: Image.memory(receipt['_photoBytes'] as Uint8List, fit: BoxFit.contain)),
                  );
                }
                final journal = receipt['journal'] as String? ?? '';
                final qrUrl = receipt['_qrUrl'] as String? ?? '';
                final isValid = receipt['isValid'] as bool? ?? false;
                final invoiceResult = receipt['invoiceResult'] as Map<String, dynamic>?;
                final pfrNumber = invoiceResult?['invoiceNumber'] ?? '';

                final lines = journal.split('\n');
                int krajIndex = -1;
                for (int i = lines.length - 1; i >= 0; i--) {
                  if (lines[i].contains('KRAJ') || lines[i].contains('\u041A\u0420\u0410\u0408')) {
                    krajIndex = i;
                    break;
                  }
                }
                final beforeKraj = krajIndex >= 0 ? lines.sublist(0, krajIndex).join('\n') : journal;
                final krajLine = krajIndex >= 0 ? lines[krajIndex] : '';

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isValid ? const Color(0xFF6FDDCE).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      child: Row(
                        children: [
                          Icon(isValid ? Icons.check_circle : Icons.error, color: isValid ? const Color(0xFF6FDDCE) : Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text('${index + 1}/${_receipts.length}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(pfrNumber, style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topLeft,
                                child: Text(beforeKraj, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.black, height: 1.3)),
                              ),
                              if (qrUrl.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                LayoutBuilder(builder: (context, constraints) {
                                  final qrSize = constraints.maxWidth * 0.80;
                                  return Center(child: SizedBox(width: qrSize, height: qrSize, child: QrImageView(data: qrUrl, version: QrVersions.auto, size: qrSize, backgroundColor: Colors.white)));
                                }),
                                const SizedBox(height: 16),
                              ],
                              if (krajLine.isNotEmpty)
                                FittedBox(
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topLeft,
                                  child: Text(krajLine, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.black, height: 1.3)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1C1C1E),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('PONOVO'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, side: const BorderSide(color: Colors.grey), padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _saveReceipts,
                    icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                    label: Text(_loading ? 'CUVAM...' : 'POSALJI'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final double scanArea;
  _ScanOverlayPainter({required this.scanArea});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.6);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: scanArea, height: scanArea);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  final AppUser doctor;
  const QrScannerScreen({super.key, required this.doctor});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);
    _scannerCtrl.stop();

    try {
      final Map<String, dynamic> data = jsonDecode(raw);
      final uid   = data['uid']   as String?;
      final name  = data['name']  as String?;

      if (uid == null || uid.isEmpty) {
        _showError('Invalid QR code');
        return;
      }

      // Verify the UID exists as a patient in Firestore
      final patient = await EmailPasswordAuthService.fetchUserById(uid);
      if (patient == null || !patient.isPatient) {
        _showError('Patient not found');
        return;
      }

      // Link patient to doctor (deduplication handled by doc ID)
      await EmailPasswordAuthService.linkPatientToDoctor(
        doctorId:    widget.doctor.id,
        patientId:   patient.id,
        patientName: patient.name,
      );

      if (mounted) {
        Navigator.of(context).pop(patient);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${name ?? patient.name} linked successfully'),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FormatException {
      _showError('Invalid QR code format');
    } catch (e) {
      _showError('Something went wrong');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() => _processing = false);
    _scannerCtrl.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Patient QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_processing)
                  const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 16),
                Text(
                  _processing ? 'Linking patient…' : 'Point camera at patient\'s QR code',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

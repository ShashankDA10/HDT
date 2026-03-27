import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/app_user.dart';
import '../../widgets/app_scaffold.dart';

class PatientQrScreen extends StatelessWidget {
  final AppUser patient;
  const PatientQrScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'uid':   patient.id,
      'phone': patient.phone,
      'name':  patient.name,
    });

    return AppScaffold(
      appBar: AppBar(
        title: const Text('My QR Code'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Show this to your doctor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'They can scan it to link your profile instantly',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                patient.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (patient.phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  patient.phone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

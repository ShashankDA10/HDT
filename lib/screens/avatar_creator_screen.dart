import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../widgets/avatar_file_loader_stub.dart'
    if (dart.library.io) '../widgets/avatar_file_loader_io.dart';

class AvatarCreatorScreen extends StatefulWidget {
  const AvatarCreatorScreen({super.key});

  @override
  State<AvatarCreatorScreen> createState() => _AvatarCreatorScreenState();
}

class _AvatarCreatorScreenState extends State<AvatarCreatorScreen> {
  bool _isSaving = false;

  Future<void> _pickAndSaveAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true, // Required on Android 13+ and web
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      if (!platformFile.name.toLowerCase().endsWith('.glb')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid file. Please select a .glb 3D avatar file!')),
          );
        }
        return;
      }

      setState(() => _isSaving = true);

      final user = await EmailPasswordAuthService.currentAppUser();
      if (user == null) {
        setState(() => _isSaving = false);
        return;
      }

      final ref = await saveAvatarBytesAndGetRef(
        platformFile.bytes,
        platformFile.path,
        user.id,
      );

      if (ref == null) {
        throw Exception(
          'Could not save avatar. On web, try a smaller file (under 3 MB). '
          'On mobile, try moving the .glb to your Downloads folder first.',
        );
      }

      // Save the ref (local path on mobile, web_local:userId on web) to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set({'avatarUrl': ref}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar saved successfully!')),
        );
        Navigator.pop(context, ref);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1323),
      appBar: AppBar(
        title: const Text('Upload Custom Avatar', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_upload_rounded, color: Colors.blueAccent, size: 72),
            const SizedBox(height: 24),
            const Text(
              'Upload your 3D Avatar',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Design your avatar at avaturn.me, download the .glb file, then upload it here. '
              'On mobile it is saved to your device. On web it is stored in your browser.',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Open Chrome and design at avaturn.me',
                      style: TextStyle(color: Colors.white, fontSize: 15, height: 1.6)),
                  SizedBox(height: 12),
                  Text('2. Download the final .glb avatar file.',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.6)),
                  SizedBox(height: 12),
                  Text('3. Tap the button below to select and save it.',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 16, height: 1.6, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  Text('⚠ Web tip: keep the file under 3 MB for best results.',
                      style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.file_upload_outlined, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
              ),
              onPressed: _isSaving ? null : _pickAndSaveAvatar,
              label: _isSaving
                  ? const Text('SAVING AVATAR...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))
                  : const Text('SELECT .GLB FILE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}

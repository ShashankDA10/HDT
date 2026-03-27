import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class UploadResult {
  final String name;
  final String url;
  const UploadResult({required this.name, required this.url});
}

class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Pick a file and upload to Firebase Storage.
  /// Returns [UploadResult] with the file name and download URL, or null if cancelled.
  static Future<UploadResult?> pickAndUpload({required String reportId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: false,
      withData: true, // load bytes on all platforms — avoids dart:io on web
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    if (file.bytes == null) return null;

    final fileName = file.name;
    final ref = _storage.ref('reports/$reportId/$fileName');

    await ref.putData(
      file.bytes!,
      SettableMetadata(contentType: _mimeType(fileName)),
    );

    final url = await ref.getDownloadURL();
    return UploadResult(name: fileName, url: url);
  }

  static String _mimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'doc':  return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:     return 'application/octet-stream';
    }
  }
}

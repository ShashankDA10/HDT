import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Save avatar bytes to the local filesystem and return the file path.
Future<String?> saveAvatarBytesAndGetRef(
    Uint8List? bytes, String? filePath, String userId) async {
  try {
    final data = (bytes != null && bytes.isNotEmpty)
        ? bytes
        : await File(filePath!).readAsBytes();
    if (data.isEmpty) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/user_avatar_$userId.glb');
    await file.writeAsBytes(data, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// Read a local file path and return a base64 data URI for ModelViewer.
Future<String?> readLocalGlbAsDataUri(String ref) async {
  if (!ref.startsWith('/')) return null;
  try {
    final file = File(ref);
    if (!await file.exists()) return null;
    return 'data:model/gltf-binary;base64,${base64Encode(await file.readAsBytes())}';
  } catch (_) {
    return null;
  }
}

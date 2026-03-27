// Web implementation (loaded on web builds where dart:io is unavailable)
import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Save avatar bytes to browser localStorage and return a lookup ref.
/// Returns null if the file is too large for localStorage (~5 MB limit).
Future<String?> saveAvatarBytesAndGetRef(
    Uint8List? bytes, String? filePath, String userId) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    final dataUri = 'data:model/gltf-binary;base64,${base64Encode(bytes)}';
    web.window.localStorage.setItem('avatar_$userId', dataUri);
    return 'web_local:$userId';
  } catch (_) {
    return null; // Quota exceeded — file too large for localStorage
  }
}

/// Resolve a stored ref to a displayable data URI.
Future<String?> readLocalGlbAsDataUri(String ref) async {
  if (ref.startsWith('web_local:')) {
    final userId = ref.substring('web_local:'.length);
    return web.window.localStorage.getItem('avatar_$userId');
  }
  return null;
}

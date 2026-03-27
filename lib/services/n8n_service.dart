import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode;

class N8nService {
  // Update this to your n8n webhook URL
  static const String n8nWebhookUrl = 'http://localhost:5678/webhook/medical-report';
  
  /// Send transcript to n8n for AI structuring
  Future<Map<String, dynamic>> structureMedicalReport(String transcript) async {
    try {
      final response = await http.post(
        Uri.parse(n8nWebhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'transcript': transcript,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        if (kDebugMode) {
          print('N8N Error: ${response.statusCode} - ${response.body}');
        }
        throw Exception('Failed to structure report: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('N8N Service Error: $e');
      }
      rethrow;
    }
  }
}


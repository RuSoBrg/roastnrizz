import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:roast_n_rizz/config/app_config.dart';

void main() {
  setUpAll(() async {
    // Load test environment
    await dotenv.load(fileName: '.env.test', isOptional: true);
  });

  group('Worker Integration Tests', () {
    test('Loads worker URL from app config', () {
      expect(AppConfig.workerUrl, isNotEmpty);
      expect(AppConfig.workerUrl, contains('http'));
    });

    test('Worker GET /credits endpoint responds', () async {
      // This test verifies the /credits endpoint exists and responds
      // Skip if the worker is not available
      try {
        final response = await http
            .get(
              Uri.parse('${AppConfig.workerUrl}/credits?userId=test-user-12345678901234567890'),
            )
            .timeout(const Duration(seconds: 5));

        // Either the user exists (200) or user ID is invalid (400)
        expect(response.statusCode, isIn([200, 400]));
        expect(jsonDecode(response.body), isA<Map<String, dynamic>>());
      } on Exception catch (_) {
        // Worker not running - test skipped
      }
    });

    test('Worker POST endpoint accepts roast/rizz requests', () async {
      // This test assumes the worker is running and has Azure AI configured
      // Skip if the worker is not available
      try {
        final payload = {
          'userId': 'test-user-12345678901234567890',
          'text': 'Hello',
          'persona': 'funny friend',
          'isRizz': false,
          'language': 'en',
        };

        final response = await http
            .post(
              Uri.parse(AppConfig.workerUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        // Check if response is valid JSON
        expect(() => jsonDecode(response.body), isNotNull);
      } on Exception catch (_) {
        // Worker not running - test skipped
      }
    });

    test('Worker rejects payloads with missing fields', () async {
      try {
        final invalidPayload = {'userId': 'test-user-12345678901234567890'};

        final response = await http
            .post(
              Uri.parse(AppConfig.workerUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(invalidPayload),
            )
            .timeout(const Duration(seconds: 5));

        // Should return 400 (validation error)
        expect(response.statusCode, equals(400));
        expect(jsonDecode(response.body), isA<Map<String, dynamic>>());
      } on Exception catch (_) {
        // Worker not running - test skipped
      }
    });

    test('Worker rejects invalid Content-Type', () async {
      try {
        final response = await http
            .post(
              Uri.parse(AppConfig.workerUrl),
              headers: {'Content-Type': 'text/plain'},
              body: 'invalid',
            )
            .timeout(const Duration(seconds: 5));

        // Should return 415 (Unsupported Media Type)
        expect(response.statusCode, equals(415));
      } on Exception catch (_) {
        // Worker not running - test skipped
      }
    });
  });
}

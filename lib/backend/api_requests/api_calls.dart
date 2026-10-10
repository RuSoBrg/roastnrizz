import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:roast_n_rizz/config/app_config.dart';

/// Normalized result returned by the roast service client.
class ApiCallResponse {
  const ApiCallResponse({
    required this.statusCode,
    required this.bodyText,
    this.jsonBody,
  });

  final int statusCode;
  final String bodyText;
  final Map<String, dynamic>? jsonBody;

  bool get succeeded => statusCode >= 200 && statusCode < 300;
}

/// HTTP client for the Cloudflare Worker roast service.
class GetRoastCall {
  const GetRoastCall._();

  static const _requestTimeout = Duration(seconds: 30);
  static const _maxPersonaLength = 80;

  static final http.Client _client = http.Client();

  /// Submits a photo to the AI service with automatic retry on transient failures.
  static Future<ApiCallResponse> call({
    required String photoBase64,
    required String authToken,
    String? language,
    String? persona,
    String? appCheckToken,
    bool isRizz = false,
  }) async {
    return _withRetry(() async {
      final uri = Uri.tryParse(AppConfig.workerUrl);
      if (uri == null || !_isAllowedWorkerUri(uri)) {
        return const ApiCallResponse(statusCode: 503, bodyText: 'Service not configured.');
      }

      final safePersona = (persona ?? 'stand-up comedian').trim();
      if (safePersona.length > _maxPersonaLength) {
        return const ApiCallResponse(statusCode: 400, bodyText: 'Persona too long.');
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'photoBase64': photoBase64,
          'language': language ?? '',
          'persona': safePersona,
          'isRizz': isRizz,
        }),
      ).timeout(_requestTimeout);

      return ApiCallResponse(
        statusCode: response.statusCode,
        bodyText: response.body,
        jsonBody: _safeDecode(response.body),
      );
    });
  }

  /// Syncs credits from the server.
  static Future<ApiCallResponse> syncCredits({
    required String authToken,
    String? appCheckToken,
  }) async {
    return _withRetry(() async {
      final uri = Uri.parse('${AppConfig.workerUrl}/sync-credits');
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
        },
      ).timeout(_requestTimeout);

      return ApiCallResponse(
        statusCode: response.statusCode,
        bodyText: response.body,
        jsonBody: _safeDecode(response.body),
      );
    });
  }

  /// Claims reward credits explicitly (fallback for when SSV is not configured/available).
  static Future<ApiCallResponse> claimReward({
    required String authToken,
    String? appCheckToken,
  }) async {
    return _withRetry(() async {
      final uri = Uri.parse('${AppConfig.workerUrl}/claim-reward');
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
        },
      ).timeout(_requestTimeout);

      return ApiCallResponse(
        statusCode: response.statusCode,
        bodyText: response.body,
        jsonBody: _safeDecode(response.body),
      );
    });
  }

  /// Helper for safe JSON decoding.
  static Map<String, dynamic>? _safeDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Simple retry logic for transient network or server errors.
  static Future<ApiCallResponse> _withRetry(Future<ApiCallResponse> Function() action) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        final res = await action();
        // Retry on 5xx or specific transient codes, but only once
        if (attempts < 2 && (res.statusCode >= 500 || res.statusCode == 429)) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return res;
      } catch (e) {
        if (attempts < 2 && (e is TimeoutException || e is SocketException)) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return ApiCallResponse(statusCode: 500, bodyText: e.toString());
      }
    }
  }

  static bool _isAllowedWorkerUri(Uri uri) {
    final isLocal = uri.scheme == 'http' && (uri.host == 'localhost' || uri.host == '127.0.0.1');
    return uri.host.isNotEmpty && (uri.scheme == 'https' || isLocal);
  }

  static String roastText(Map<String, dynamic>? jsonBody, String bodyText) {
    String clean(String s) => s.trim().replaceAll(RegExp('(^["\u201c\u201d\']+|["\u201c\u201d\']+\$)'), '');
    if (jsonBody != null) {
      final text = jsonBody['result'] ?? jsonBody['text'] ?? jsonBody['message'];
      if (text is String && text.isNotEmpty) return clean(text);
    }
    return bodyText.isNotEmpty ? clean(bodyText) : 'No response generated.';
  }
}

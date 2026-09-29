import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Live Backend Base URL
/// (Switch or change this URL when working locally vs on live server)
// const String _apiBase = 'https://advtapp.com';
// const String _apiBase = 'https://apps.plestarinc.com:3009';
const String _apiBase = 'http://10.0.2.2:5000'; // Android Emulator Local
// const String _apiBase = 'http://localhost:5000'; // iOS Simulator / Web Local

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  String _baseUrl = _apiBase.trim().replaceAll(RegExp(r'/+$'), '');
  String? _authToken;
  String? _currentUserId;
  String? _currentUserEmail;

  String get baseUrl => _baseUrl.replaceAll(RegExp(r'/+$'), '');

  void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setCurrentUser({String? userId, String? email}) {
    if (userId != null) _currentUserId = userId;
    if (email != null) _currentUserEmail = email;
  }

  void clearSession() {
    _authToken = null;
    _currentUserId = null;
    _currentUserEmail = null;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    String cleanPath = path.startsWith('/') ? path : '/$path';
    String fullUrl = '$baseUrl$cleanPath';

    final parsed = Uri.parse(fullUrl);
    if (query != null && query.isNotEmpty) {
      final queryParams = <String, String>{};
      query.forEach((k, v) {
        if (v != null) queryParams[k] = v.toString();
      });
      return parsed.replace(queryParameters: queryParams);
    }
    return parsed;
  }

  Map<String, String> _buildHeaders([Map<String, String>? additionalHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      headers['x-user-id'] = _currentUserId!;
    }
    if (_currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      headers['x-user-email'] = _currentUserEmail!;
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  // ==========================================
  // HTTP GET
  // ==========================================
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _uri(path, query);
    // debugPrint('[API] GET $uri');
    final resp = await _client
        .get(uri, headers: _buildHeaders(headers))
        .timeout(timeout ?? const Duration(seconds: 25));
    // debugPrint('[API] GET $path -> Status: ${resp.statusCode}');

    return _processResponse(resp);
  }

  // ==========================================
  // HTTP POST
  // ==========================================
  Future<dynamic> post(
    String path,
    dynamic payload, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _uri(path);
    final body = payload is String ? payload : jsonEncode(payload);

    // debugPrint('[API] POST $uri -> Body: $body');
    final resp = await _client
        .post(uri, headers: _buildHeaders(headers), body: body)
        .timeout(timeout ?? const Duration(seconds: 25));
    // debugPrint('[API] POST $path -> Status: ${resp.statusCode}');

    return _processResponse(resp);
  }

  // ==========================================
  // HTTP PUT
  // ==========================================
  Future<dynamic> put(
    String path,
    dynamic payload, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _uri(path);
    final body = payload is String ? payload : jsonEncode(payload);

    // debugPrint('[API] PUT $uri -> Body: $body');
    final resp = await _client
        .put(uri, headers: _buildHeaders(headers), body: body)
        .timeout(timeout ?? const Duration(seconds: 25));
    // debugPrint('[API] PUT $path -> Status: ${resp.statusCode}');

    return _processResponse(resp);
  }

  // ==========================================
  // HTTP DELETE
  // ==========================================
  Future<dynamic> delete(
    String path, [
    dynamic bodyPayload,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
  ]) async {
    final uri = _uri(path, query);
    final req = http.Request('DELETE', uri);
    req.headers.addAll(_buildHeaders(headers));

    if (bodyPayload != null) {
      req.body = bodyPayload is String ? bodyPayload : jsonEncode(bodyPayload);
    }

    final streamedResp = await _client.send(req).timeout(timeout ?? const Duration(seconds: 25));
    final resp = await http.Response.fromStream(streamedResp);
    // debugPrint('[API] DELETE $path -> Status: ${resp.statusCode}');

    return _processResponse(resp);
  }

  dynamic _processResponse(http.Response resp) {
    if (resp.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(resp.body);
      return decoded;
    } catch (_) {
      return resp.body;
    }
  }
}

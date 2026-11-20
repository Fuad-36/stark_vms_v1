import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_error.dart';
import 'token_storage.dart';

typedef AuthInvalidationCallback = void Function();

/// Centralized HTTP client managing requests, headers, tokens, and errors.
class ApiClient {
  final http.Client _httpClient;
  final TokenStorage _tokenStorage;
  final AuthInvalidationCallback? onAuthenticationExpired;

  bool _isInvalidatingAuth = false;

  ApiClient({
    http.Client? httpClient,
    TokenStorage? tokenStorage,
    this.onAuthenticationExpired,
  })  : _httpClient = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// Constructs a consistent [Uri] given a relative endpoint [path] or full URL.
  Uri buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '${ApiConfig.baseUrl}$cleanPath';

    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  /// Sends an HTTP GET request.
  Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    return _sendRequest(
      'GET',
      path,
      headers: headers,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  /// Sends an HTTP POST request.
  Future<dynamic> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
    bool authenticated = true,
  }) async {
    return _sendRequest(
      'POST',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
      authenticated: authenticated,
    );
  }

  /// Sends an HTTP PUT request.
  Future<dynamic> put(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
    bool authenticated = true,
  }) async {
    return _sendRequest(
      'PUT',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
      authenticated: authenticated,
    );
  }

  /// Sends an HTTP DELETE request.
  Future<dynamic> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
    bool authenticated = true,
  }) async {
    return _sendRequest(
      'DELETE',
      path,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<dynamic> _sendRequest(
    String method,
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
    required bool authenticated,
  }) async {
    final uri = buildUri(path, queryParameters);
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await _tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }
    }

    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    String? encodedBody;
    if (body != null) {
      if (body is String) {
        encodedBody = body;
      } else {
        try {
          encodedBody = jsonEncode(body);
        } catch (e) {
          throw ApiException(
            statusCode: 400,
            message: 'Failed to encode request body: $e',
            error: 'SerializationError',
          );
        }
      }
    }

    http.Response response;
    try {
      final request = http.Request(method, uri);
      request.headers.addAll(requestHeaders);
      if (encodedBody != null) {
        request.body = encodedBody;
      }

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(ApiConfig.requestTimeout);
      response = await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException catch (e) {
      throw ApiException.networkError(e.message);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError(e.toString());
    }

    return _handleResponse(response, authenticated, path);
  }

  dynamic _handleResponse(
    http.Response response,
    bool authenticated,
    String path,
  ) {
    final statusCode = response.statusCode;
    final isSuccess = statusCode >= 200 && statusCode < 300;

    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        if (!isSuccess) {
          throw ApiException(
            statusCode: statusCode,
            message: response.body.isNotEmpty ? response.body : 'HTTP Error $statusCode',
          );
        }
        throw ApiException.malformedResponse(
          'Received non-JSON response from server (HTTP $statusCode)',
        );
      }
    }

    if (isSuccess) {
      return decodedBody;
    }

    // 401 Unauthorized handling:
    // Protected API requests receiving 401 trigger centralized authentication invalidation.
    // Public requests (like login) or requests to loginPath must NOT trigger global invalidation.
    // 403 responses must NOT invalidate authentication.
    final isLoginEndpoint = path.contains(ApiConfig.loginPath);
    if (statusCode == 401 && authenticated && !isLoginEndpoint) {
      _triggerAuthenticationInvalidation();
    }

    throw ApiException.fromResponse(statusCode, decodedBody);
  }

  void _triggerAuthenticationInvalidation() {
    if (_isInvalidatingAuth) {
      return; // Prevent duplicate invalidation during concurrent 401 responses
    }
    _isInvalidatingAuth = true;
    try {
      onAuthenticationExpired?.call();
    } finally {
      Future.microtask(() => _isInvalidatingAuth = false);
    }
  }

  void close() {
    _httpClient.close();
  }
}

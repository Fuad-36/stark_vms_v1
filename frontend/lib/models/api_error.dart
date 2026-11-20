/// Represents the standard backend error response payload.
class ApiErrorResponse {
  final String? timestamp;
  final int status;
  final String error;
  final String message;
  final Map<String, String> fieldErrors;

  const ApiErrorResponse({
    this.timestamp,
    required this.status,
    required this.error,
    required this.message,
    this.fieldErrors = const {},
  });

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    final rawFieldErrors = json['fieldErrors'];
    final Map<String, String> parsedFieldErrors = {};

    if (rawFieldErrors is Map) {
      rawFieldErrors.forEach((key, value) {
        if (key != null && value != null) {
          parsedFieldErrors[key.toString()] = value.toString();
        }
      });
    }

    return ApiErrorResponse(
      timestamp: json['timestamp'] as String?,
      status: json['status'] is int ? json['status'] as int : 0,
      error: json['error'] as String? ?? '',
      message: json['message'] as String? ?? 'An unexpected error occurred',
      fieldErrors: parsedFieldErrors,
    );
  }
}

/// Custom exception thrown when API communication or backend operations fail.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String error;
  final Map<String, String> fieldErrors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.error = '',
    this.fieldErrors = const {},
  });

  /// Factory for parsing backend error response bodies.
  factory ApiException.fromResponse(int statusCode, dynamic decodedBody) {
    if (decodedBody is Map<String, dynamic>) {
      final errorResponse = ApiErrorResponse.fromJson(decodedBody);
      return ApiException(
        statusCode: errorResponse.status != 0 ? errorResponse.status : statusCode,
        message: errorResponse.message.isNotEmpty
            ? errorResponse.message
            : _defaultMessageForStatus(statusCode),
        error: errorResponse.error,
        fieldErrors: errorResponse.fieldErrors,
      );
    }

    return ApiException(
      statusCode: statusCode,
      message: _defaultMessageForStatus(statusCode),
    );
  }

  /// Factory for client-side connection/network errors.
  factory ApiException.networkError([String? details]) {
    return ApiException(
      statusCode: 0,
      message: details ?? 'Unable to connect to the server. Please check your network connection.',
      error: 'NetworkError',
    );
  }

  /// Factory for request timeout.
  factory ApiException.timeout() {
    return const ApiException(
      statusCode: 408,
      message: 'Request timed out. Please try again.',
      error: 'Timeout',
    );
  }

  /// Factory for malformed or unparseable responses.
  factory ApiException.malformedResponse([String? details]) {
    return ApiException(
      statusCode: -1,
      message: details ?? 'Received an invalid response from the server.',
      error: 'MalformedResponse',
    );
  }

  static String _defaultMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request parameters.';
      case 401:
        return 'Invalid username or password.';
      case 403:
        return 'Access is denied.';
      case 404:
        return 'Requested resource was not found.';
      case 409:
        return 'A conflict occurred with existing data.';
      case 500:
        return 'An internal server error occurred. Please try again later.';
      default:
        return 'An unexpected error occurred (HTTP $statusCode).';
    }
  }

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message, error: $error, fieldErrors: $fieldErrors)';
}

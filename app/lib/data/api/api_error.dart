// Errors from /v1 (CONTRACTS 3.5, docs/schemas/error.schema.json). Every
// non-2xx response except 304 carries {"error": {code, message,
// retry_after_s, details}}; the app shows its own copy keyed by `code`.
import 'dart:convert';

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.status,
    this.message = '',
    this.retryAfterS,
    this.details,
  });

  /// No usable response: no network, server down, DNS, timeout.
  static const offline = 'offline';

  /// A response that is neither JSON in the contract shape nor a known
  /// status (a proxy page, a 304 to a request without an ETag).
  static const badResponse = 'bad_response';

  /// An `error.schema.json` code (`title_not_found`, `rate_limited`, ...),
  /// or [offline] / [badResponse].
  final String code;

  /// HTTP status; null when nothing came back.
  final int? status;
  final String message;
  final int? retryAfterS;
  final Map<String, dynamic>? details;

  bool get isOffline => code == offline;

  /// Builds the exception from a non-2xx, non-304 response. A body that is
  /// not the contract shape falls back to a code from the status, and
  /// `Retry-After` fills [retryAfterS] when the body has none.
  factory ApiException.fromResponse(
    int status,
    String? body, {
    String? retryAfterHeader,
  }) {
    Map<String, dynamic>? error;
    try {
      final json = jsonDecode(body ?? '');
      if (json is Map<String, dynamic> && json['error'] is Map) {
        error = (json['error'] as Map).cast<String, dynamic>();
      }
    } on FormatException {
      error = null;
    }
    final code = error?['code'];
    final retry = error?['retry_after_s'];
    final details = error?['details'];
    return ApiException(
      code: code is String && code.isNotEmpty ? code : _codeFor(status),
      status: status,
      message: error?['message'] is String ? error!['message'] as String : '',
      retryAfterS: retry is int ? retry : int.tryParse(retryAfterHeader ?? ''),
      details: details is Map ? details.cast<String, dynamic>() : null,
    );
  }

  /// No response at all (connection refused, timeout, no route, cancelled):
  /// offline. A response that dio rejected goes through [fromResponse].
  factory ApiException.fromDio(DioException e) {
    // The auth interceptor rejects with the refresh call's own error.
    if (e.error is ApiException) return e.error! as ApiException;
    final r = e.response;
    if (r != null && r.statusCode != null) {
      return ApiException.fromResponse(
        r.statusCode!,
        r.data is String ? r.data as String : null,
        retryAfterHeader: r.headers.value('retry-after'),
      );
    }
    return ApiException(code: offline, message: e.message ?? e.type.name);
  }

  static String _codeFor(int status) => switch (status) {
    400 => 'bad_request',
    404 || 405 => 'not_found',
    422 => 'validation_error',
    429 => 'rate_limited',
    >= 500 => 'internal_error',
    _ => badResponse,
  };

  @override
  String toString() =>
      'ApiException($code${status == null ? '' : ', $status'}'
      '${message.isEmpty ? '' : ': $message'})';
}

/// True when [error] means "no connection", so screens show the offline
/// wording and icon instead of the generic one.
bool isOfflineError(Object? error) => error is ApiException && error.isOffline;

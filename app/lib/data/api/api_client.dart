// The /v1 HTTP client (CONTRACTS 3, 8.1): dio, base URL from the build,
// conditional GETs with If-None-Match, error bodies mapped to ApiException.
// It holds no keys: the base URL is the only compiled-in value (11).
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'api_error.dart';

/// Build-time base URL. Dev default is the host machine as the Android
/// emulator sees it; release builds pass
/// `--dart-define=API_BASE_URL=https://...`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// Result of a GET: a body, or "not modified" when the ETag still matches.
sealed class ApiResult {
  const ApiResult();
}

@immutable
class ApiBody extends ApiResult {
  const ApiBody(this.body, this.etag);

  /// Raw JSON text, stored as is in the drift cache.
  final String body;

  /// The response `ETag`, null when the endpoint sends none (feed).
  final String? etag;
}

class ApiNotModified extends ApiResult {
  const ApiNotModified();
}

class ApiClient {
  ApiClient({Dio? dio, String baseUrl = apiBaseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ) {
    // Bodies stay text so the cache keeps exactly what the server sent;
    // every status reaches us so the 304 and error mapping happen here.
    _dio.options
      ..responseType = ResponseType.plain
      ..validateStatus = ((_) => true)
      ..headers['Accept'] = 'application/json';
  }

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  /// GET [path]. With [etag], sends `If-None-Match` and returns
  /// [ApiNotModified] on 304. Throws [ApiException] for anything else
  /// that is not a 200.
  Future<ApiResult> get(
    String path, {
    Map<String, String>? query,
    String? etag,
  }) async {
    final Response<String> r;
    try {
      r = await _dio.get<String>(
        path,
        queryParameters: query,
        options: Options(headers: {'If-None-Match': ?etag}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    final status = r.statusCode ?? 0;
    if (status == 200) return ApiBody(r.data ?? '', r.headers.value('etag'));
    if (status == 304) {
      if (etag == null) {
        throw const ApiException(
          code: ApiException.badResponse,
          status: 304,
          message: '304 without If-None-Match',
        );
      }
      return const ApiNotModified();
    }
    throw ApiException.fromResponse(
      status,
      r.data,
      retryAfterHeader: r.headers.value('retry-after'),
    );
  }
}

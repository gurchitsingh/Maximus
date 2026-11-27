import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/api/api_client.dart';

void main() {
  void check(String url, {required bool isRelease}) =>
      requireHttpsInRelease('API_BASE_URL', url, isRelease: isRelease);

  group('release', () {
    test('accepts https', () {
      check('https://api.example.com', isRelease: true);
    });

    for (final url in [
      'http://api.example.com',
      'http://10.0.2.2:8000',
      '',
      'api.example.com',
      'https://',
    ]) {
      test('rejects "$url" and names the define', () {
        expect(
          () => check(url, isRelease: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('API_BASE_URL'), contains('https://')),
            ),
          ),
        );
      });
    }
  });

  group('debug', () {
    for (final url in ['https://api.example.com', 'http://10.0.2.2:8000', '']) {
      test('accepts "$url"', () {
        check(url, isRelease: false);
      });
    }
  });
}

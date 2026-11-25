// Validator for app/assets/posters (CONTRACTS 21). Fails when a poster breaks
// the artboard rules or the manifest and the files disagree.
import 'dart:convert';
import 'dart:io';

import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Directory('assets/posters');
  final manifest = jsonDecode(
    File('assets/posters/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final svgs = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.svg'))
      .toList();

  String name(File f) => f.uri.pathSegments.last;

  test('manifest entries are well formed', () {
    expect(manifest, isNotEmpty);
    final hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    manifest.forEach((id, v) {
      final m = v as Map<String, dynamic>;
      expect(['pair', 'wash', 'single'], contains(m['mode']), reason: id);
      expect(m['bg'], matches(hex), reason: id);
      expect(m['tint'], matches(hex), reason: id);
      expect(m['lettering'], isA<String>(), reason: id);
      final lines = m['lines'] as List<dynamic>;
      expect(lines.length, inInclusiveRange(1, 2), reason: id);
      for (final l in lines) {
        expect((l as String).length, lessThanOrEqualTo(24), reason: id);
      }
    });
  });

  test('manifest lists no missing file and every file is listed', () {
    final expected = <String>{};
    manifest.forEach((id, v) {
      final mode = (v as Map<String, dynamic>)['mode'];
      if (mode == 'pair') {
        expected
          ..add('$id.day.svg')
          ..add('$id.evening.svg');
      } else {
        expected.add('$id.svg');
      }
    });
    final actual = svgs.map(name).toSet();
    expect(expected.difference(actual), isEmpty, reason: 'missing files');
    expect(actual.difference(expected), isEmpty, reason: 'unlisted files');
  });

  test('every poster follows the artboard rules', () {
    expect(svgs, isNotEmpty);
    final banned = RegExp(
      r'<\s*(text|tspan|image|filter|script|style|foreignObject|use|defs|'
      r'linearGradient|radialGradient|pattern|mask|clipPath)\b|'
      r'\bfilter\s*[:=]|\bon\w+\s*=|href\s*=|url\(|@font-face',
      caseSensitive: false,
    );
    for (final f in svgs) {
      final s = f.readAsStringSync();
      final n = name(f);
      expect(f.lengthSync(), lessThanOrEqualTo(40 * 1024), reason: '$n size');
      expect(s, contains('viewBox="0 0 200 300"'), reason: '$n viewBox');
      expect(banned.hasMatch(s), isFalse, reason: '$n uses a banned feature');
      expect(
        RegExp(r'(?:data:|https?:)')
            .hasMatch(s.replaceAll('http://www.w3.org/2000/svg', '')),
        isFalse,
        reason: '$n has external or embedded data',
      );
    }
  });
  testWidgets('every poster parses with flutter_svg', (tester) async {
    await tester.runAsync(() async {
      for (final f in svgs) {
        final loader = SvgBytesLoader(Uint8List.fromList(f.readAsBytesSync()));
        final info = await vg.loadPicture(loader, null);
        expect(info.size, const Size(200, 300), reason: name(f));
        info.picture.dispose();
      }
    });
  });
}

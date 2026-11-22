// markdown_lite (CONTRACTS 2.2, D21): each construct, rejects nothing,
// unknown lines are paragraphs (section 10).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/domain/markdown_lite.dart';

String flat(List<MdSpan> s) => s.map((x) => x.text).join();

void main() {
  test('paragraphs split on blank lines; lines inside join with a space', () {
    final b = parseMarkdownLite('One\ntwo\n\nThree');
    expect(b, hasLength(2));
    expect(flat((b[0] as MdParagraph).spans), 'One two');
    expect(flat((b[1] as MdParagraph).spans), 'Three');
  });

  test('## sub-heading', () {
    final b = parseMarkdownLite('## The Republic\nText');
    expect(flat((b[0] as MdHeading).spans), 'The Republic');
    expect(b[1], isA<MdParagraph>());
  });

  test('consecutive bullets form one list', () {
    final b = parseMarkdownLite('- a\n- **b**\n\n- c');
    expect(b, hasLength(2));
    final l = b[0] as MdBullets;
    expect(l.items.map(flat), ['a', 'b']);
    expect(l.items[1].single.bold, isTrue);
  });

  test('> quote lines form one quote', () {
    final b = parseMarkdownLite('> Veni,\n> vidi');
    expect(flat((b.single as MdQuote).spans), 'Veni, vidi');
  });

  test('image line', () {
    final b = parseMarkdownLite('Text\n![](roman-history.i02)\nMore');
    expect(b, hasLength(3));
    expect((b[1] as MdImage).imageId, 'roman-history.i02');
  });

  test('inline bold and italic, nested italic in bold', () {
    final s = parseInline('a **b *c*** and *d*');
    expect(s.map((x) => (x.text, x.bold, x.italic)).toList(), [
      ('a ', false, false),
      ('b ', true, false),
      ('c', true, true),
      (' and ', false, false),
      ('d', false, true),
    ]);
  });

  test('unclosed markers stay literal', () {
    expect(flat(parseInline('5 * 3 and **open')), '5 * 3 and **open');
    expect(parseInline('5 * 3').single.italic, isFalse);
  });

  test('disallowed constructs render as plain paragraphs', () {
    final b = parseMarkdownLite('# H1\n\n### H3\n\n1. First\n\n| a | b |');
    expect(b, hasLength(4));
    expect(b.every((x) => x is MdParagraph), isTrue);
    expect(flat((b[0] as MdParagraph).spans), '# H1');
    expect(flat((b[2] as MdParagraph).spans), '1. First');
  });

  test('CRLF line endings and trailing spaces', () {
    final b = parseMarkdownLite('## Head  \r\n\r\nBody\r\n');
    expect(flat((b[0] as MdHeading).spans), 'Head');
    expect(flat((b[1] as MdParagraph).spans), 'Body');
  });

  test('plainText strips markup and skips images', () {
    final b = parseMarkdownLite(
      '## Head\n*Soft* **loud**\n![](x.i01)\n- one\n- two\n> quote',
    );
    expect(plainText(b), 'Head.\nSoft loud\none.\ntwo.\nquote');
  });

  test('every sample lesson parses into non-empty blocks', () {
    for (final id in ['roman-history', 'shivaji-maharaj', 'chanakya']) {
      final t = jsonDecode(
        File('../backend/data/samples/$id.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final l in (t['lessons'] as List).cast<Map<String, dynamic>>()) {
        final b = parseMarkdownLite(l['body'] as String);
        expect(b, isNotEmpty, reason: l['id'] as String);
        for (final img in b.whereType<MdImage>()) {
          expect((l['image_ids'] as List).skip(1), contains(img.imageId));
        }
      }
    }
  });
}

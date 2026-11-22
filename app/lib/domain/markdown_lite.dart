// The lesson markdown subset (CONTRACTS 2.2, DECISIONS D21). Pure Dart.
// One construct per line: blank = paragraph break, `## ` sub-heading,
// `- ` bullet, `> ` quote, `![](image_id)` image, anything else paragraph
// text. Inline: `**bold**` and `*italic*`. The parser rejects nothing:
// lines outside the subset render as plain paragraph text.
import 'package:meta/meta.dart';

@immutable
class MdSpan {
  const MdSpan(this.text, {this.bold = false, this.italic = false});
  final String text;
  final bool bold;
  final bool italic;
}

sealed class MdBlock {
  const MdBlock();
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);
  final List<MdSpan> spans;
}

class MdHeading extends MdBlock {
  const MdHeading(this.spans);
  final List<MdSpan> spans;
}

class MdBullets extends MdBlock {
  const MdBullets(this.items);
  final List<List<MdSpan>> items;
}

class MdQuote extends MdBlock {
  const MdQuote(this.spans);
  final List<MdSpan> spans;
}

class MdImage extends MdBlock {
  const MdImage(this.imageId);
  final String imageId;
}

final _image = RegExp(r'^!\[\]\(([^)\s]+)\)$');

List<MdBlock> parseMarkdownLite(String body) {
  final blocks = <MdBlock>[];
  final para = <String>[];
  final quote = <String>[];
  final bullets = <String>[];

  void flush() {
    if (para.isNotEmpty) {
      blocks.add(MdParagraph(parseInline(para.join(' '))));
      para.clear();
    }
    if (quote.isNotEmpty) {
      blocks.add(MdQuote(parseInline(quote.join(' '))));
      quote.clear();
    }
    if (bullets.isNotEmpty) {
      blocks.add(MdBullets([for (final b in bullets) parseInline(b)]));
      bullets.clear();
    }
  }

  for (final raw in body.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    final img = _image.firstMatch(line.trim());
    if (img != null) {
      flush();
      blocks.add(MdImage(img.group(1)!));
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(MdHeading(parseInline(line.substring(3).trim())));
    } else if (line.startsWith('- ')) {
      if (para.isNotEmpty || quote.isNotEmpty) flush();
      bullets.add(line.substring(2).trim());
    } else if (line.startsWith('> ') || line == '>') {
      if (para.isNotEmpty || bullets.isNotEmpty) flush();
      quote.add(line.length > 1 ? line.substring(2).trim() : '');
    } else {
      if (quote.isNotEmpty || bullets.isNotEmpty) flush();
      para.add(line.trim());
    }
  }
  flush();
  return blocks;
}

/// `**bold**` and `*italic*`; unclosed markers are kept as literal text.
List<MdSpan> parseInline(String s, {bool bold = false, bool italic = false}) {
  final out = <MdSpan>[];
  final buf = StringBuffer();
  void emit() {
    if (buf.isNotEmpty) {
      out.add(MdSpan(buf.toString(), bold: bold, italic: italic));
      buf.clear();
    }
  }

  var i = 0;
  while (i < s.length) {
    if (s.startsWith('**', i)) {
      final end = _closing(s, i + 2, '**');
      if (end > i + 2) {
        emit();
        out.addAll(
          parseInline(s.substring(i + 2, end), bold: true, italic: italic),
        );
        i = end + 2;
        continue;
      }
    } else if (s[i] == '*') {
      final end = _closing(s, i + 1, '*');
      if (end > i + 1) {
        emit();
        out.addAll(
          parseInline(s.substring(i + 1, end), bold: bold, italic: true),
        );
        i = end + 1;
        continue;
      }
    }
    buf.write(s[i]);
    i++;
  }
  emit();
  return out;
}

/// Index of the closing [marker] at or after [from], or -1. A single `*`
/// never closes on the first star of a `**` pair, so `*a **b** c*` works.
/// The content must not start with a space ("5 * 3" is not italic).
int _closing(String s, int from, String marker) {
  if (from >= s.length || s[from] == ' ') return -1;
  var j = from;
  while (j < s.length) {
    if (marker == '**') {
      if (s.startsWith('**', j)) {
        // Prefer the last star of a run, so "***" closes "*c*" first.
        if (j + 2 < s.length && s[j + 2] == '*') {
          j++;
          continue;
        }
        return j;
      }
    } else {
      if (s.startsWith('**', j)) {
        final inner = _closing(s, j + 2, '**');
        if (inner < 0) return -1;
        j = inner + 2;
        continue;
      }
      if (s[j] == '*') return s[j - 1] == ' ' ? -1 : j;
    }
    j++;
  }
  return -1;
}

/// Plain text for read-aloud (CONTRACTS 2.2 `read_aloud_text` null): markup
/// stripped, image lines skipped, headings and bullets end with a full stop
/// so the voice pauses.
String plainText(List<MdBlock> blocks) {
  String t(List<MdSpan> s) => s.map((x) => x.text).join().trim();
  String stop(String x) =>
      x.isEmpty || '.!?:;'.contains(x[x.length - 1]) ? x : '$x.';
  final lines = <String>[];
  for (final b in blocks) {
    switch (b) {
      case MdParagraph(:final spans):
        lines.add(t(spans));
      case MdHeading(:final spans):
        lines.add(stop(t(spans)));
      case MdBullets(:final items):
        lines.addAll(items.map((i) => stop(t(i))));
      case MdQuote(:final spans):
        lines.add(t(spans));
      case MdImage():
        break;
    }
  }
  return lines.where((l) => l.isNotEmpty).join('\n');
}

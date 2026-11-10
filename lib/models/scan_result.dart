/// نموذج نتيجة المسح: مستند مكوّن من فقرات وعناوين وقوائم ومعادلات وجداول.
library;

enum BlockType {
  heading1,
  heading2,
  heading3,
  paragraph,
  bullet,
  numbered,
  displayEquation,
  table
}

class ScanRun {
  /// نص عادي، أو LaTeX إذا كان النوع معادلة.
  final String text;
  final bool isEquation;

  const ScanRun({required this.text, this.isEquation = false});

  factory ScanRun.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? 'text').toString().toLowerCase();
    final isEq = type == 'equation' || type == 'math' || type == 'latex';
    return ScanRun(
      text: (j['latex'] ?? j['text'] ?? '').toString(),
      isEquation: isEq,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': isEquation ? 'equation' : 'text',
        if (isEquation) 'latex': text,
        if (!isEquation) 'text': text,
      };
}

class ScanBlock {
  final BlockType type;
  final List<ScanRun> runs;

  /// معادلة مستقلة (display_equation).
  final String latex;

  /// جداول: صفوف من خلايا، كل خلية قائمة runs.
  final List<List<ScanRun>> rows;

  const ScanBlock(
      {required this.type,
      this.runs = const [],
      this.latex = '',
      this.rows = const []});
}

class ScanDocument {
  final String title;
  final List<ScanBlock> blocks;

  const ScanDocument({this.title = '', this.blocks = const []});

  static BlockType _type(String t) {
    switch (t.toLowerCase()) {
      case 'heading1':
      case 'h1':
      case 'heading_1':
        return BlockType.heading1;
      case 'heading2':
      case 'h2':
      case 'heading_2':
        return BlockType.heading2;
      case 'heading3':
      case 'h3':
      case 'heading_3':
        return BlockType.heading3;
      case 'bullet':
      case 'bullet_list':
      case 'unordered_list_item':
        return BlockType.bullet;
      case 'numbered':
      case 'numbered_list':
      case 'ordered_list_item':
        return BlockType.numbered;
      case 'display_equation':
      case 'displayequation':
      case 'equation':
      case 'block_equation':
        return BlockType.displayEquation;
      case 'table':
        return BlockType.table;
      default:
        return BlockType.paragraph;
    }
  }

  /// تنظيف LaTeX من محددات Markdown التي قد يتسللها النموذج.
  static String cleanLatex(String s) {
    var t = s.trim();
    // محددات '\\(' و '\\' و '$'
    if (t.startsWith('\\(')) t = t.substring(2).trim();
    if (t.startsWith('\\[')) t = t.substring(2).trim();
    if (t.endsWith('\\\\')) t = t.substring(0, t.length - 2).trim();
    if (t.endsWith('\\)')) t = t.substring(0, t.length - 2).trim();
    if (t.endsWith('\\]')) t = t.substring(0, t.length - 2).trim();
    if (t.startsWith('\$') && t.endsWith('\$') && t.length > 2) {
      t = t.substring(1, t.length - 1).trim();
    }
    if (t.startsWith('\$\$') && t.endsWith('\$\$') && t.length > 4) {
      t = t.substring(2, t.length - 2).trim();
    }
    return t;
  }

  static List<ScanRun> _runs(dynamic raw) {
    final out = <ScanRun>[];
    if (raw is List) {
      for (final r in raw) {
        if (r is Map) out.add(ScanRun.fromJson(Map<String, dynamic>.from(r)));
      }
    } else if (raw is String) {
      out.add(ScanRun(text: raw));
    }
    return out;
  }

  static ScanDocument fromJson(Map<String, dynamic> j) {
    final doc = (j['document'] is Map)
        ? Map<String, dynamic>.from(j['document'] as Map)
        : j;
    final blocks = <ScanBlock>[];
    final rawBlocks = doc['blocks'] ?? doc['content'] ?? const [];
    if (rawBlocks is List) {
      for (final b in rawBlocks) {
        if (b is! Map) continue;
        final type = _type((b['type'] ?? 'paragraph').toString());
        final latex =
            cleanLatex((b['latex'] ?? b['equation'] ?? '').toString());
        final runs = _runs(b['runs']);
        final rows = <List<ScanRun>>[];
        if (b['rows'] is List) {
          for (final row in (b['rows'] as List)) {
            if (row is List) {
              rows.add(row.map((c) {
                if (c is Map)
                  return ScanRun.fromJson(Map<String, dynamic>.from(c));
                return ScanRun(text: c.toString());
              }).toList());
            } else if (row is Map && row['runs'] is List) {
              rows.add(_runs(row['runs']));
            } else {
              rows.add([ScanRun(text: row.toString())]);
            }
          }
        }
        final block =
            ScanBlock(type: type, runs: runs, latex: latex, rows: rows);
        final empty = (type == BlockType.displayEquation && latex.isEmpty) ||
            (type == BlockType.table && rows.isEmpty) ||
            (runs.isEmpty && latex.isEmpty && rows.isEmpty);
        if (!empty) blocks.add(block);
      }
    }
    return ScanDocument(
        title: (doc['title'] ?? doc['document_title'] ?? '').toString(),
        blocks: blocks);
  }
}

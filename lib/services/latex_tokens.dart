/// طبقة الترميز (Tokenizer) لـ LaTeX إلى رونز.
library;

class Tok {
  final String type; // cmd | char | groupOpen | groupClose | sup | sub | prime | amp | rowsep
  final String text;
  const Tok(this.type, this.text);
}

final _letterR = RegExp(r'[A-Za-z]');

List<Tok> tokenize(String src) {
  final t = <Tok>[];
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    switch (c) {
      case '{':
        t.add(const Tok('groupOpen', '{')); i++; continue;
      case '}':
        t.add(const Tok('groupClose', '}')); i++; continue;
      case '^':
        t.add(const Tok('sup', '^')); i++; continue;
      case '_':
        t.add(const Tok('sub', '_')); i++; continue;
      case '&':
        t.add(const Tok('amp', '&')); i++; continue;
      case "'":
        t.add(const Tok('prime', "'")); i++; continue;
      case '\\':
        if (i + 1 >= src.length) { i++; continue; }
        final n = src[i + 1];
        if (n == '\\') {
          t.add(const Tok('rowsep', '\\\\')); i += 2; continue;
        }
        if (_letterR.hasMatch(n)) {
          var j = i + 1;
          while (j < src.length && _letterR.hasMatch(src[j])) { j++; }
          t.add(Tok('cmd', src.substring(i + 1, j)));
          i = j;
        } else {
          t.add(Tok('cmd', n)); i += 2;
        }
        continue;
      default:
        t.add(Tok('char', c)); i++;
    }
  }
  return t;
}

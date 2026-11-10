/// نواة المحلل: تسلسل، ذرات، أسس، أقواس، بيئات.
library;

import 'math_nodes.dart';
import 'latex_tokens.dart';

class TexParser {
  final List<Tok> toks;
  int pos = 0;
  TexParser(this.toks);

  Tok? peek() => pos < toks.length ? toks[pos] : null;
  Tok? next() => pos < toks.length ? toks[pos++] : null;
  bool get eof => pos >= toks.length;

  static final _lowerR = RegExp(r'[a-z]');
  static final _digitR = RegExp(r'[0-9]');

  /// أنواع الإيقاف: brace | amp | rowsep | rbrack | right | end
  ({List<MNode> nodes, String stop}) seq(List<String> stops) {
    final out = <MNode>[];
    while (!eof) {
      final t = peek()!;
      final stop = stopKind(t, stops);
      if (stop != null) return (nodes: out, stop: stop);
      switch (t.type) {
        case 'groupOpen':
          next();
          final inner = seq(['brace']);
          if (peek()?.type == 'groupClose') next();
          pushAndAttach(out, MGrp(inner.nodes));
          continue;
        case 'cmd':
          if (t.text == 'right' && stops.contains('right'))
            return (nodes: out, stop: 'right');
          if (t.text == 'end' && stops.contains('end'))
            return (nodes: out, stop: 'end');
          next();
          handleCmd(t.text, out);
          continue;
        case 'char':
          next();
          final c = t.text;
          if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
          if (c == '~') {
            pushRun(out, MRun('\u00A0'));
            continue;
          }
          if (c == ']') {
            out.add(MRun(']', 'p'));
            continue;
          }
          pushRun(out, MRun(c));
          attachScriptsIfAny(out);
          continue;
        case 'sup':
        case 'sub':
        case 'prime':
          applyScripts(out);
          continue;
        default:
          next();
      }
    }
    return (nodes: out, stop: 'eof');
  }

  String? stopKind(Tok t, List<String> stops) {
    if (t.type == 'groupClose' && stops.contains('brace')) return 'brace';
    if (t.type == 'amp' && stops.contains('amp')) return 'amp';
    if (t.type == 'rowsep' && stops.contains('rowsep')) return 'rowsep';
    if (t.type == 'char' && t.text == ']' && stops.contains('rbrack'))
      return 'rbrack';
    if (t.type == 'cmd' && t.text == 'right' && stops.contains('right'))
      return 'right';
    if (t.type == 'cmd' && t.text == 'end' && stops.contains('end'))
      return 'end';
    return null;
  }

  void pushAndAttach(List<MNode> out, MNode n) {
    out.add(n);
    attachScriptsIfAny(out);
  }

  void attachScriptsIfAny(List<MNode> out) {
    if (eof) return;
    final t = peek()!;
    if (t.type == 'sup' || t.type == 'sub' || t.type == 'prime')
      applyScripts(out);
  }

  void applyScripts(List<MNode> out) {
    final baseNode = out.isNotEmpty ? out.removeLast() : MGrp(const []);
    MNode? sub, sup;
    var primes = 0;
    while (!eof) {
      final t = peek()!;
      if (t.type == 'prime') {
        next();
        primes++;
        continue;
      }
      if (t.type == 'sup') {
        next();
        sup = merge(sup, atom());
        continue;
      }
      if (t.type == 'sub') {
        next();
        sub = merge(sub, atom());
        continue;
      }
      break;
    }
    if (primes > 0) {
      for (var k = 0; k < primes; k++) {
        sup = merge(sup, MRun('\u2032'));
      }
    }
    out.add(makeScripted(baseNode, sub, sup));
    attachScriptsIfAny(out);
  }

  MNode makeScripted(MNode base, MNode? sub, MNode? sup) {
    if (base is MNary) {
      base.sub ??= sub;
      base.sup ??= sup;
      return base;
    }
    if (base is MRun &&
        base.style == 'p' &&
        limFamily.contains(base.text) &&
        sub != null &&
        sup == null) {
      return MLim(upper: false, base: base, lim: sub);
    }
    return MScripts(base, sub: sub, sup: sup);
  }

  MNode merge(MNode? a, MNode b) {
    if (a == null) return b;
    if (a is MGrp) return MGrp([...a.children, b]);
    return MGrp([a, b]);
  }

  /// ذرّة: مجموعة أو أمر أو محرف واحد.
  MNode atom() {
    if (eof) return MGrp(const []);
    final t = peek()!;
    switch (t.type) {
      case 'groupOpen':
        next();
        final r = seq(['brace']);
        if (peek()?.type == 'groupClose') next();
        return MGrp(r.nodes);
      case 'cmd':
        next();
        final out = <MNode>[];
        handleCmd(t.text, out);
        if (out.isEmpty) return MGrp(const []);
        return out.length == 1 ? out.first : MGrp(out);
      case 'prime':
        next();
        return MRun('\u2032');
      default:
        next();
        if (t.type == 'char') {
          if (t.text == ' ' ||
              t.text == '\n' ||
              t.text == '\t' ||
              t.text == '\r') return atom();
          return MRun(t.text);
        }
        return MGrp(const []);
    }
  }

  /// محرف الواصلة بعد &\left / &\right / &\middle
  String delimChar() {
    final t = next();
    if (t == null) return '';
    switch (t.type) {
      case 'char':
        return t.text == '.' ? '' : t.text;
      case 'cmd':
        switch (t.text) {
          case 'lbrace':
          case '{':
            return '{';
          case 'rbrace':
          case '}':
            return '}';
          case 'lbrack':
            return '[';
          case 'rbrack':
            return ']';
          case 'langle':
            return '\u27E8';
          case 'rangle':
            return '\u27E9';
          case 'vert':
          case 'lvert':
          case 'rvert':
            return '|';
          case 'Vert':
          case 'lVert':
          case 'rVert':
            return '\u2016';
          case 'lfloor':
            return '\u230A';
          case 'rfloor':
            return '\u230B';
          case 'lceil':
            return '\u2308';
          case 'rceil':
            return '\u2309';
          case 'uparrow':
            return '\u2191';
          case 'downarrow':
            return '\u2193';
          case 'updownarrow':
            return '\u2195';
          case 'backslash':
            return '\\';
          default:
            return '';
        }
      case 'groupOpen':
        seq(['brace']);
        if (peek()?.type == 'groupClose') next();
        return '{';
      default:
        return '';
    }
  }

  /// وسيط {..} خام (لنصوص ومجموعات مستهلكة دون تحليل)
  List<Tok> consumeGroupRaw() {
    if (eof) return const [];
    final t = peek()!;
    if (t.type != 'groupOpen') {
      next();
      return [t];
    }
    next();
    final raw = <Tok>[];
    var depth = 1;
    while (!eof) {
      final tk = next()!;
      if (tk.type == 'groupOpen') depth++;
      if (tk.type == 'groupClose') {
        depth--;
        if (depth == 0) break;
      }
      raw.add(tk);
    }
    return raw;
  }

  /// نص منови رونز خام (يقبلالأوامر الترميزية المعروفة)
  static String tokensText(List<Tok> raw) {
    final buf = StringBuffer();
    for (final tk in raw) {
      switch (tk.type) {
        case 'char':
          buf.write(tk.text);
          continue;
        case 'cmd':
          if (spacingMap.containsKey(tk.text)) {
            buf.write(spacingMap[tk.text]!);
            continue;
          }
          final op = opMap[tk.text] ?? greekMap[tk.text];
          if (op != null) {
            buf.write(op);
            continue;
          }
          if (tk.text == 'textbackslash') {
            buf.write('\\');
            continue;
          }
          buf.write(tk.text);
          continue;
        default:
          continue;
      }
    }
    return buf.toString();
  }

  MNode styledNode(String? style) {
    final node = atom();
    walkStyle(node, style);
    return node;
  }

  void walkStyle(MNode n, String? style) {
    if (style == null) return;
    if (n is MRun) {
      n.style ??= style;
      return;
    }
    if (n is MGrp) {
      for (final c in n.children) {
        walkStyle(c, style);
      }
      return;
    }
    if (n is MScripts) {
      walkStyle(n.base, style);
      return;
    }
  }

  void pushRun(List<MNode> out, MRun r) {
    if (out.isNotEmpty && out.last is MRun) {
      final last = out.last as MRun;
      if (last.style == null && r.style == null) {
        last.text += r.text;
        return;
      }
    }
    out.add(r);
  }

  /// الاسم بعد \begin / \end
  String envName() {
    if (peek()?.type != 'groupOpen') {
      next();
      return '';
    }
    next();
    final buf = StringBuffer();
    while (!eof) {
      final t = peek()!;
      if (t.type == 'groupClose') {
        next();
        break;
      }
      if (t.type == 'char' || t.type == 'cmd') {
        buf.write(t.text);
        next();
        continue;
      }
      next();
    }
    return buf.toString().trim();
  }

  /// بيئة كاملة (matrix/pmatrix/cases/aligned...)
  MNode parseEnv(String envNameRaw) {
    var name = envNameRaw;
    if (name.startsWith('array')) {
      if (peek()?.type == 'groupOpen') {
        next();
        seq(['brace']);
        if (peek()?.type == 'groupClose') next();
      }
      name = 'array';
    }
    if (name == 'smallmatrix') name = 'matrix';
    if (name.endsWith('*')) name = name.substring(0, name.length - 1);

    final rows = <List<MNode>>[];
    var cells = <MNode>[];
    while (true) {
      final res = seq(['brace', 'amp', 'rowsep', 'end']);
      cells.addAll(res.nodes);
      switch (res.stop) {
        case 'amp':
          next();
          rows.add(cells);
          cells = <MNode>[];
          continue;
        case 'rowsep':
          next();
          rows.add(cells);
          cells = <MNode>[];
          continue;
        case 'end':
          next();
          envName();
          rows.add(cells);
          cells = <MNode>[];
          break;
        default:
          rows.add(cells);
          cells = <MNode>[];
          break;
      }
      if (res.stop != 'amp' && res.stop != 'rowsep') break;
    }
    final wrappedRows = rows.isEmpty ? <List<MNode>>[<MNode>[]] : rows;
    switch (name) {
      case 'pmatrix':
        return MMatrix(wrappedRows, '(');
      case 'bmatrix':
        return MMatrix(wrappedRows, '[');
      case 'Bmatrix':
        return MMatrix(wrappedRows, '{');
      case 'vmatrix':
        return MMatrix(wrappedRows, '|');
      case 'Vmatrix':
        return MMatrix(wrappedRows, '\u2016');
      case 'matrix':
      case 'array':
        return MMatrix(wrappedRows, null);
      default:
        return MEqArr(wrappedRows,
            wrapOpen: name == 'cases' || name == 'dcases' ? '{' : null);
    }
  }

  /// استقبال الأوامر (توصّل الكاملة من latex_commands.dart)
  static void Function(TexParser, String, List<MNode>)? commandHook;
  void handleCmd(String name, List<MNode> out) {
    final hook = commandHook;
    if (hook != null) {
      hook(this, name, out);
    }
  }

  static bool isDigitChar(String c) => _digitR.hasMatch(c);
  static bool isLowerChar(String c) => _lowerR.hasMatch(c);
}

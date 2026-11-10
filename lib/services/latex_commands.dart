/// الأوامر الكاملة للمحلل + كيمياء mhchem المصغرة.
library;

import 'math_nodes.dart';
import 'latex_tokens.dart';
import 'latex_parser.dart';

/// الأوامر الكاملة للمحلل.
void latexCommands(TexParser p, String name, List<MNode> out) {
  if (spacingMap.containsKey(name)) { out.add(MRun(spacingMap[name]!)); return; }
  if (greekMap.containsKey(name)) { out.add(MRun(greekMap[name]!)); return; }
  if (bigOpMap.containsKey(name)) {
    final und = !(name == 'int' || name == 'iint' || name == 'iiint' || name == 'oint' || name == 'oiint' || name == 'oiiint');
    final body = p.atom();
    out.add(MNary(bigOpMap[name]!, und, body));
    p.attachScriptsIfAny(out);
    return;
  }
  if (opMap.containsKey(name)) {
    final ch = opMap[name]!;
    switch (name) {
      case 'lbrace': out.add(MRun('{', 'p')); return;
      case 'rbrace': out.add(MRun('}', 'p')); return;
      case 'lbrack': out.add(MRun('[', 'p')); return;
      case 'rbrack': out.add(MRun(']', 'p')); return;
      case 'langle': case 'rangle': case 'vert': case 'Vert':
      case 'lvert': case 'rvert': case 'lVert': case 'rVert':
      case 'lfloor': case 'rfloor': case 'lceil': case 'rceil':
      case 'uparrow': case 'downarrow': case 'Uparrow': case 'Downarrow':
      case 'updownarrow': case 'backslash':
        out.add(MRun(ch));
        p.attachScriptsIfAny(out);
        return;
      default:
        out.add(MRun(ch));
        return;
    }
  }
  if (limFamily.contains(name)) { out.add(MRun(name, 'p')); p.attachScriptsIfAny(out); return; }
  if (funcNames.contains(name)) { out.add(MRun(name, 'p')); return; }
  if (accentMap.containsKey(name)) { out.add(MAcc(accentMap[name]!, p.atom())); return; }

  switch (name) {
    case 'frac': case 'dfrac': case 'cfrac': {
      final a = p.atom(), b = p.atom();
      if (_isEmptyGrp(a) && _isEmptyGrp(b)) throw const FormatException('كسر غير مكتمل');
      out.add(MFrac(a, b));
      return;
    }
    case 'tfrac': {
      final a = p.atom(), b = p.atom();
      if (_isEmptyGrp(a) && _isEmptyGrp(b)) throw const FormatException('كسر غير مكتمل');
      out.add(MFrac(a, b, 'lin'));
      return;
    }
    case 'binom': case 'dbinom': {
      final a = p.atom(), b = p.atom();
      if (_isEmptyGrp(a) && _isEmptyGrp(b)) throw const FormatException('ثنائية غير مكتملة');
      out.add(MFrac(a, b, 'noBar'));
      return;
    }
    case 'sqrt': {
      MNode? deg;
      if (p.peek()?.type == 'char' && p.peek()!.text == '[') {
        p.next();
        final r = p.seq(['rbrack']);
        if (p.peek()?.type == 'char' && p.peek()!.text == ']') p.next();
        deg = MGrp(r.nodes);
      }
      out.add(MRad(p.atom(), deg));
      return;
    }
    case 'overline': case 'widebar': out.add(MBar(true, p.atom())); return;
    case 'underline': out.add(MBar(false, p.atom())); return;
    case 'overbrace': case 'underbrace': {
      final base = p.atom();
      final wantTop = name == 'overbrace';
      MNode? limNode;
      if (wantTop ? p.peek()?.type == 'sup' : p.peek()?.type == 'sub') { p.next(); limNode = p.atom(); }
      out.add(MLim(upper: wantTop, base: base, lim: limNode ?? MRun('', 'p')));
      return;
    }
    case 'left': {
      final beg = p.delimChar();
      final body = p.seq(['right']);
      var endCh = '';
      final tk = p.peek();
      if (tk != null && tk.type == 'cmd' && tk.text == 'right') { p.next(); endCh = p.delimChar(); }
      out.add(MDelim(body.nodes, beg: beg, end: endCh));
      p.attachScriptsIfAny(out);
      return;
    }
    case 'right': case 'middle':
      out.add(MRun(p.delimChar())); return;
    case 'begin':
      out.add(p.parseEnv(p.envName()));
      return;
    case 'end': return;
    case 'text': case 'textrm': case 'textnormal': case 'textup':
    case 'mbox': case 'hbox':
      out.add(MRun(TexParser.tokensText(p.consumeGroupRaw()), 'nor'));
      return;
    case 'textbf':
      out.add(MRun(TexParser.tokensText(p.consumeGroupRaw()), 'b')); return;
    case 'textit':
      out.add(MRun(TexParser.tokensText(p.consumeGroupRaw()), 'p')); return;
    case 'operatorname': case 'operatornamewithlimits': {
      if (p.peek()?.type == 'char' && p.peek()!.text == '*') p.next();
      out.add(MRun(TexParser.tokensText(p.consumeGroupRaw()), 'p'));
      p.attachScriptsIfAny(out);
      return;
    }
    case 'mathrm': case 'mathup': out.add(p.styledNode('p')); return;
    case 'mathbf': case 'boldsymbol': case 'bm': out.add(p.styledNode('b')); return;
    case 'mathbb': case 'Bbb': out.add(p.styledNode('ds')); return;
    case 'mathcal': case 'mathscr': out.add(p.styledNode('script')); return;
    case 'mathfrak': case 'mathfr': case 'frak': out.add(p.styledNode('fraktur')); return;
    case 'mathsf': out.add(p.styledNode('sans')); return;
    case 'mathit': case 'mathnormal': p.atom(); return;
    case 'overset': case 'stackrel': {
      final over = p.atom();
      final base = p.atom();
      out.add(MLim(upper: true, base: base, lim: over));
      p.attachScriptsIfAny(out);
      return;
    }
    case 'underset': {
      final under = p.atom();
      final base = p.atom();
      out.add(MLim(upper: false, base: base, lim: under));
      p.attachScriptsIfAny(out);
      return;
    }
    case 'xrightarrow': case 'xleftarrow': {
      final arrow = MRun(name == 'xrightarrow' ? '\u27F6' : '\u27F5', 'p');
      String? below;
      if (p.peek()?.type == 'char' && p.peek()!.text == '[') {
        p.next();
        final buf = <Tok>[];
        while (!p.eof) {
          final t2 = p.peek()!;
          if (t2.type == 'char' && t2.text == ']') { p.next(); break; }
          buf.add(p.next()!);
        }
        below = TexParser.tokensText(buf);
      }
      final above = TexParser.tokensText(_consumeAtomRaw(p));
      if (below != null && below.isNotEmpty && above.isNotEmpty) {
        out.add(MLim(upper: true, base: MLim(upper: false, base: arrow, lim: MRun(below, 'p')), lim: MRun(above, 'p')));
      } else if (below != null && below.isNotEmpty) {
        out.add(MLim(upper: false, base: arrow, lim: MRun(below, 'p')));
      } else if (above.isNotEmpty) {
        out.add(MLim(upper: true, base: arrow, lim: MRun(above, 'p')));
      } else {
        out.add(arrow);
      }
      p.attachScriptsIfAny(out);
      return;
    }
    case 'substack': {
      final raw = p.consumeGroupRaw();
      final rows = _substackRows(raw);
      out.add(MEqArr(rows));
      p.attachScriptsIfAny(out);
      return;
    }
    case 'ce':
      out.add(MGrp(parseChemistry(p)));
      p.attachScriptsIfAny(out);
      return;
    case 'quad': out.add(MRun('\u2003')); return;
    case 'qquad': out.add(MRun('\u2003\u2003')); return;
    case 'hspace': case 'vspace': case 'kern':
      if (p.peek()?.type == 'char' && p.peek()!.text == '*') p.next();
      p.consumeGroupRaw(); return;
    case 'color': case 'textcolor': case 'colorbox':
      p.consumeGroupRaw();
      if (p.peek()?.type == 'groupOpen') p.consumeGroupRaw();
      return;
    case 'tag': p.consumeGroupRaw(); return;
    case 'mathchoice':
      for (var k = 0; k < 4; k++) {
        if (p.peek()?.type == 'groupOpen') { p.next(); p.seq(['brace']); } else { break; }
      }
      return;
    case 'not': {
      final t = p.peek();
      const m = {'=': '\u2260', '<': '\u226E', '>': '\u226F', '\u2264': '\u2270', '\u2265': '\u2271'};
      if (t != null && t.type == 'char' && m.containsKey(t.text)) { p.next(); out.add(MRun(m[t.text]!)); return; }
      if (t != null && t.type == 'cmd' && opMap.containsKey(t.text)) {
        p.next();
        out.add(MRun(opMap[t.text]! + '\u0338')); return;
      }
      out.add(MRun('\u0338')); return;
    }
    case '{': out.add(MRun('{', 'p')); return;
    case '}': out.add(MRun('}', 'p')); return;
    case '%': case '&': case '#': case '\$': case '_':
      out.add(MRun(name, 'nor')); return;
    default:
      // أوامر غير معروفة: تجاهل بصمت
      const skip = {
        'displaystyle', 'textstyle', 'scriptstyle', 'scriptscriptstyle',
        'limits', 'nolimits', 'relax', 'nonumber', 'notag', 'allowbreak',
        'ensuremath', 'nobreakdash', 'protect', 'plain', 'showstyle',
        'mathinner', 'thinpt', 'enspace', 'critic', 'hphantom', 'vphantom', 'phantom',
      };
      if (skip.contains(name)) {
        if ({'hphantom', 'vphantom', 'phantom'}.contains(name)) p.consumeGroupRaw();
        return;
      }
      return;
  }
}

/// أول{}ي كجمع خام من الونز
List<Tok> _consumeAtomRaw(TexParser p) {
  final t = p.peek();
  if (t != null && t.type == 'groupOpen') return p.consumeGroupRaw();
  return const [];
}

bool _isEmptyGrp(MNode n) => n is MGrp && n.children.isEmpty;

List<List<MNode>> _substackRows(List<Tok> raw) {
  final inner = TexParser(raw);
  final rows = <List<MNode>>[];
  var cur = <MNode>[];
  while (!inner.eof) {
    final res = inner.seq(['brace', 'end', 'rowsep']);
    cur.addAll(res.nodes);
    if (res.stop == 'rowsep') { inner.next(); rows.add(cur); cur = <MNode>[]; continue; }
    if (res.stop == 'eof') break;
    inner.next();
  }
  rows.add(cur);
  return rows;
}

// ============================ كيمياء mhchem ============================

/// التحليل بعد استهلاك '\ce' ومع '{}' مفتوح.
List<MNode> parseChemistry(TexParser p) {
  final nodes = <MNode>[];
  String pendingEl = '';
  String pendingDigits = '';
  var stateDepth = 0;

  void flush({MNode? sub, MNode? sup}) {
    if (pendingEl.isEmpty) return;
    final el = MRun(pendingEl, 'p');
    final node = (sub == null && sup == null) ? el : MScripts(el, sub: sub, sup: sup);
    nodes.add(node);
    pendingEl = '';
  }

  while (!p.eof) {
    final t = p.peek()!;
    if (t.type == 'groupClose') { p.next(); break; }
    if (t.type == 'char') {
      p.next();
      final c = t.text;
      if (c == ' ' || c == '\t' || c == '\n') { flush(); nodes.add(MRun('\u2009')); continue; }
      if (c == '(' || c == '[') { flush(); stateDepth++; nodes.add(MRun(c, 'p')); continue; }
      if (c == ')' || c == ']') { flush(); if (stateDepth > 0) stateDepth--; nodes.add(MRun(c, 'p')); continue; }
      if (c == '+') {
        if (pendingEl.isNotEmpty) { flush(sup: MRun('+', 'p')); continue; }
        nodes.add(MRun('+', 'p')); continue;
      }
      if (c == '-') {
        final n2 = p.peek();
        if (n2 != null && n2.type == 'char' && n2.text == '>') {
          p.next();
          flush();
          nodes.add(MRun('\u2192', 'p'));
          continue;
        }
        if (pendingEl.isNotEmpty) { flush(sup: MRun('\u2212', 'p')); continue; }
        nodes.add(MRun('\u2212', 'p')); continue;
      }
      if (c == '<') {
        final n2 = p.peek();
        if (n2 != null && n2.type == 'char' && n2.text == '-') { p.next(); nodes.add(MRun('\u2190', 'p')); continue; }
        if (n2 != null && n2.type == 'char' && n2.text == '=') {
          p.next();
          if (p.peek()?.type == 'char' && p.peek()!.text == '>') p.next();
          nodes.add(MRun('\u21CC', 'p')); continue;
        }
        nodes.add(MRun('<', 'p')); continue;
      }
      if (RegExp(r'[A-Z]').hasMatch(c)) {
        flush();
        var sym = c;
        while (p.peek() != null && p.peek()!.type == 'char' && TexParser.isLowerChar(p.peek()!.text)) { sym += p.next()!.text; }
        pendingEl = sym;
        continue;
      }
      if (TexParser.isDigitChar(c)) {
        var d = c;
        while (p.peek() != null && p.peek()!.type == 'char' && (TexParser.isDigitChar(p.peek()!.text) || p.peek()!.text == '.')) { d += p.next()!.text; }
        if (pendingEl.isNotEmpty) { flush(sub: MRun(d)); continue; }
        nodes.add(MRun(d, 'p')); continue;
      }
      flush();
      nodes.add(MRun(c, stateDepth > 0 ? 'p' : null));
      continue;
    }
    if (t.type == 'sup' || t.type == 'sub') {
      final isSup = t.type == 'sup';
      p.next();
      final nodes2 = <MNode>[];
      while (!p.eof) {
        final tt = p.peek()!;
        if (tt.type == 'char' && (TexParser.isDigitChar(tt.text) || tt.text == '+' || tt.text == '-')) {
          p.next();
          nodes2.add(MRun(tt.text, 'p'));
          continue;
        }
        if (tt.type == 'groupOpen') { p.next(); nodes2.addAll(p.seq(['brace']).nodes); continue; }
        break;
      }
      final content = nodes2.isEmpty ? MRun('', 'p') : (nodes2.length == 1 ? nodes2.first : MGrp(nodes2));
      if (pendingEl.isNotEmpty && pendingDigits.isNotEmpty) {
        final el = MRun(pendingEl, 'p');
        final subNode = MRun(pendingDigits, 'p');
        final node = isSup ? MScripts(el, sub: subNode, sup: content) : MScripts(el, sub: content, sup: null);
        nodes.add(node);
        pendingEl = ''; pendingDigits = '';
      } else if (nodes.isNotEmpty) {
        final base = nodes.removeLast();
        nodes.add(isSup ? MScripts(base, sup: content) : MScripts(base, sub: content));
      } else {
        nodes.add(MScripts(MGrp(const []), sub: isSup ? null : content, sup: isSup ? content : null));
      }
      continue;
    }
    if (t.type == 'cmd') {
      p.next();
      flush();
      if (spacingMap.containsKey(t.text)) { final c = spacingMap[t.text]!; if (c.isNotEmpty) nodes.add(MRun(c)); continue; }
      if (t.text == 'uparrow') { nodes.add(MRun('\u2191', 'p', )); continue; }
      if (t.text == 'downarrow') { nodes.add(MRun('\u2193', 'p')); continue; }
      if (t.text == 'text') { nodes.add(MRun(TexParser.tokensText(p.consumeGroupRaw()), 'p')); continue; }
      latexCommands(p, t.text, nodes);
      continue;
    }
    p.next();
  }
  flush();
  return nodes;
}

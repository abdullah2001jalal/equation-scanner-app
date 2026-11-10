/// شجرة معادلات وستة جداول رموز + مُسلسل OMML.
library;

sealed class MNode {}

class MRun extends MNode {
  String text;

  /// null: مائل افتراضي، 'p': قائم، 'b': عريض، 'script'/'ds'/'fraktur'/'sans': أنماط خطوط، 'nor': نص عادي.
  String? style;
  MRun(this.text, [this.style]);
}

class MGrp extends MNode {
  final List<MNode> children;
  MGrp(this.children);
}

class MScripts extends MNode {
  final MNode base;
  final MNode? sub;
  final MNode? sup;
  MScripts(this.base, {this.sub, this.sup});
}

class MFrac extends MNode {
  final MNode num, den;
  final String? type; // null | 'lin' | 'noBar'
  MFrac(this.num, this.den, [this.type]);
}

class MRad extends MNode {
  final MNode body;
  final MNode? degree;
  MRad(this.body, [this.degree]);
}

class MDelim extends MNode {
  final String beg, end;
  final List<MNode> body;
  MDelim(this.body, {this.beg = '(', this.end = ')'});
}

class MAcc extends MNode {
  final String chr;
  final MNode base;
  MAcc(this.chr, this.base);
}

class MBar extends MNode {
  final bool top;
  final MNode base;
  MBar(this.top, this.base);
}

class MLim extends MNode {
  final bool upper;
  final MNode base, lim;
  MLim({required this.upper, required this.base, required this.lim});
}

class MNary extends MNode {
  final String chr;
  final bool und;
  MNode? sub, sup;
  final MNode body;
  MNary(this.chr, this.und, this.body, {this.sub, this.sup});
}

class MMatrix extends MNode {
  final List<List<MNode>> rows;
  final String? wrap;
  MMatrix(this.rows, [this.wrap]);
}

class MEqArr extends MNode {
  final List<List<MNode>> rows;
  final String? wrapOpen; // '{' للحالات
  MEqArr(this.rows, {this.wrapOpen});
}

const Map<String, String> greekMap = {
  'alpha': '\u03B1',
  'beta': '\u03B2',
  'gamma': '\u03B3',
  'delta': '\u03B4',
  'epsilon': '\u03F5',
  'varepsilon': '\u03B5',
  'zeta': '\u03B6',
  'eta': '\u03B7',
  'theta': '\u03B8',
  'vartheta': '\u03D1',
  'iota': '\u03B9',
  'kappa': '\u03BA',
  'varkappa': '\u03F0',
  'lambda': '\u03BB',
  'mu': '\u03BC',
  'nu': '\u03BD',
  'xi': '\u03BE',
  'pi': '\u03C0',
  'varpi': '\u03D6',
  'rho': '\u03C1',
  'varrho': '\u03F1',
  'sigma': '\u03C3',
  'varsigma': '\u03C2',
  'tau': '\u03C4',
  'upsilon': '\u03C5',
  'phi': '\u03D5',
  'varphi': '\u03C6',
  'chi': '\u03C7',
  'psi': '\u03C8',
  'omega': '\u03C9',
  'digamma': '\u03DD',
  'Gamma': '\u0393',
  'Delta': '\u0394',
  'Theta': '\u0398',
  'Lambda': '\u039B',
  'Xi': '\u039E',
  'Pi': '\u03A0',
  'Sigma': '\u03A3',
  'Upsilon': '\u03A5',
  'Phi': '\u03A6',
  'Psi': '\u03A8',
  'Omega': '\u03A9',
  'varTheta': '\u03D2',
};

const Map<String, String> opMap = {
  'pm': '\u00B1',
  'mp': '\u2213',
  'times': '\u00D7',
  'div': '\u00F7',
  'ast': '\u2217',
  'star': '\u22C6',
  'circ': '\u2218',
  'bullet': '\u2022',
  'cdot': '\u22C5',
  'oplus': '\u2295',
  'ominus': '\u2296',
  'otimes': '\u2297',
  'oslash': '\u2298',
  'odot': '\u2299',
  'diamond': '\u22C4',
  'bigcirc': '\u25EF',
  'doteq': '\u2250',
  'equiv': '\u2261',
  'leq': '\u2264',
  'le': '\u2264',
  'geq': '\u2265',
  'ge': '\u2265',
  'neq': '\u2260',
  'ne': '\u2260',
  'sim': '\u223C',
  'simeq': '\u2243',
  'approx': '\u2248',
  'cong': '\u2245',
  'propto': '\u221D',
  'prec': '\u227A',
  'preceq': '\u227C',
  'succ': '\u227B',
  'succeq': '\u227D',
  'll': '\u226A',
  'gg': '\u226B',
  'subset': '\u2282',
  'subseteq': '\u2286',
  'supset': '\u2283',
  'supseteq': '\u2287',
  'in': '\u2208',
  'notin': '\u2209',
  'ni': '\u220B',
  'cup': '\u222A',
  'cap': '\u2229',
  'setminus': '\u2216',
  'emptyset': '\u2205',
  'varnothing': '\u2205',
  'sqsubset': '\u228F',
  'sqsubseteq': '\u2291',
  'sqsupset': '\u2290',
  'sqsupseteq': '\u2292',
  'vee': '\u2228',
  'wedge': '\u2227',
  'lor': '\u2228',
  'land': '\u2227',
  'neg': '\u00AC',
  'lnot': '\u00AC',
  'top': '\u22A4',
  'bot': '\u22A5',
  'perp': '\u22A5',
  'parallel': '\u2225',
  'angle': '\u2220',
  'measuredangle': '\u2221',
  'mid': '\u2223',
  'vdash': '\u22A2',
  'dashv': '\u22A3',
  'models': '\u22A8',
  'uparrow': '\u2191',
  'downarrow': '\u2193',
  'Uparrow': '\u21D1',
  'Downarrow': '\u21D3',
  'updownarrow': '\u2195',
  'Updownarrow': '\u21D5',
  'rightarrow': '\u2192',
  'to': '\u2192',
  'leftarrow': '\u2190',
  'gets': '\u2190',
  'leftrightarrow': '\u2194',
  'Leftrightarrow': '\u21D4',
  'Rightarrow': '\u21D2',
  'Leftarrow': '\u21D0',
  'longrightarrow': '\u27F6',
  'longleftarrow': '\u27F5',
  'Longrightarrow': '\u27F9',
  'longleftrightarrow': '\u27F7',
  'mapsto': '\u21A6',
  'hookrightarrow': '\u21AA',
  'hookleftarrow': '\u21A9',
  'nearrow': '\u2197',
  'searrow': '\u2198',
  'swarrow': '\u2199',
  'nwarrow': '\u2196',
  'rightleftharpoons': '\u21CC',
  'leftrightharpoons': '\u21CB',
  'ldots': '\u2026',
  'dots': '\u2026',
  'dotsc': '\u2026',
  'dotso': '\u2026',
  'cdots': '\u22EF',
  'dotsb': '\u22EF',
  'dotsm': '\u22EF',
  'dotsi': '\u22EF',
  'vdots': '\u22EE',
  'ddots': '\u22F1',
  'infty': '\u221E',
  'partial': '\u2202',
  'nabla': '\u2207',
  'forall': '\u2200',
  'exists': '\u2203',
  'nexists': '\u2204',
  'hbar': '\u210F',
  'ell': '\u2113',
  'Re': '\u211C',
  'Im': '\u2111',
  'aleph': '\u2135',
  'prime': '\u2032',
  'backprime': '\u2035',
  'surd': '\u221A',
  'flat': '\u266D',
  'natural': '\u266E',
  'sharp': '\u266F',
  'langle': '\u27E8',
  'rangle': '\u27E9',
  'vert': '|',
  'Vert': '\u2016',
  'lvert': '|',
  'rvert': '|',
  'lVert': '\u2016',
  'rVert': '\u2016',
  'lbrace': '{',
  'rbrace': '}',
  'lbrack': '[',
  'rbrack': ']',
  'lfloor': '\u230A',
  'rfloor': '\u230B',
  'lceil': '\u2308',
  'rceil': '\u2309',
  'backslash': '\\',
  'complex': '\u2102',
  'natnums': '\u2115',
  'reals': '\u211D',
  'rationals': '\u211A',
  'integers': '\u2124',
  'degree': '\u00B0',
  'checkmark': '\u2713',
  'dag': '\u2020',
  'ddag': '\u2021',
  'lq': '\u2018',
  'rq': '\u2019',
};

const Map<String, String> bigOpMap = {
  'sum': '\u2211',
  'prod': '\u220F',
  'coprod': '\u2210',
  'int': '\u222B',
  'iint': '\u222C',
  'iiint': '\u222D',
  'oint': '\u222E',
  'oiint': '\u222F',
  'oiiint': '\u2230',
  'bigcap': '\u22C2',
  'bigcup': '\u22C3',
  'bigvee': '\u22C1',
  'bigwedge': '\u22C0',
  'bigsqcup': '\u2A06',
  'bigoplus': '\u2A01',
  'bigotimes': '\u2A02',
  'bigodot': '\u2A00',
  'biguplus': '\u2A04',
};

const Set<String> limFamily = {
  'lim',
  'limsup',
  'liminf',
  'max',
  'min',
  'sup',
  'inf',
  'Pr'
};

const Set<String> funcNames = {
  'sin',
  'cos',
  'tan',
  'cot',
  'sec',
  'csc',
  'sinh',
  'cosh',
  'tanh',
  'coth',
  'arcsin',
  'arccos',
  'arctan',
  'arccot',
  'arcsec',
  'arccsc',
  'log',
  'ln',
  'lg',
  'exp',
  'det',
  'dim',
  'deg',
  'gcd',
  'hom',
  'ker',
  'arg',
  'Var',
  'Cov',
  'argmax',
  'argmin',
};

const Map<String, String> accentMap = {
  'hat': '\u0302',
  'widehat': '\u0302',
  'tilde': '\u0303',
  'widetilde': '\u0303',
  'bar': '\u0304',
  'vec': '\u20D7',
  'dot': '\u0307',
  'ddot': '\u0308',
  'dddot': '\u20DB',
  'breve': '\u0306',
  'check': '\u030C',
  'widecheck': '\u030C',
  'acute': '\u0301',
  'grave': '\u0300',
  'mathring': '\u030A',
};

const Map<String, String> spacingMap = {
  ',': '\u2009',
  ':': '\u2005',
  ';': '\u2004',
  '!': '',
  '>': '\u2005',
  ' ': '\u00A0',
};

const Set<String> delimNameSet = {
  'langle',
  'rangle',
  'vert',
  'Vert',
  'lvert',
  'rvert',
  'lVert',
  'rVert',
  'lfloor',
  'rfloor',
  'lceil',
  'rceil',
  'uparrow',
  'downarrow',
  'Uparrow',
  'Downarrow',
  'updownarrow',
  'backslash',
};

const String zwsp = '\u200B';

String xmlEsc(String s) => s
    .replaceAll('&', '\u0026amp;')
    .replaceAll('<', '\u0026lt;')
    .replaceAll('>', '\u0026gt;');

String wrapChar(String w) {
  switch (w) {
    case '[':
      return '[';
    case '{':
      return '{';
    case '|':
      return '|';
    case '\u2016':
      return '\u2016';
    default:
      return '(';
  }
}

String wrapClose(String w) {
  switch (w) {
    case '[':
      return ']';
    case '{':
      return '}';
    case '|':
      return '|';
    case '\u2016':
      return '\u2016';
    default:
      return ')';
  }
}

String zeroRun() => '<m:r><m:t xml:space="preserve">$zwsp</m:t></m:r>';

/// يحول شجرة إلى XML مفردات OMML (بدون غلاف m:oMath).
String nodeXml(MNode n) {
  switch (n) {
    case final MRun r:
      return runXml(r);
    case final MGrp g:
      return g.children.map(nodeXml).join();
    case final MScripts s:
      final inner = s.base is MGrp && (s.base as MGrp).children.isEmpty
          ? zeroRun()
          : nodeXml(s.base);
      final base = '<m:e>$inner</m:e>';
      if (s.sub != null && s.sup != null) {
        return '<m:sSubSup>$base<m:sub>${nodeXml(s.sub!)}</m:sub><m:sup>${nodeXml(s.sup!)}</m:sup></m:sSubSup>';
      }
      if (s.sub != null)
        return '<m:sSub>$base<m:sub>${nodeXml(s.sub!)}</m:sub></m:sSub>';
      if (s.sup != null)
        return '<m:sSup>$base<m:sup>${nodeXml(s.sup!)}</m:sup></m:sSup>';
      return inner;
    case final MFrac f:
      final pr = f.type == null
          ? ''
          : '<m:fPr><m:type m:val="${f.type == 'lin' ? 'lin' : 'noBar'}"/></m:fPr>';
      return '<m:f>$pr<m:num>${nodeXml(f.num)}</m:num><m:den>${nodeXml(f.den)}</m:den></m:f>';
    case final MRad r:
      if (r.degree == null) {
        return '<m:rad><m:radPr><m:degHide m:val="1"/></m:radPr><m:deg/><m:e>${nodeXml(r.body)}</m:e></m:rad>';
      }
      return '<m:rad><m:radPr><m:degHide m:val="0"/></m:radPr><m:deg>${nodeXml(r.degree!)}</m:deg><m:e>${nodeXml(r.body)}</m:e></m:rad>';
    case final MDelim d:
      final beg = (d.beg.isEmpty || d.beg == '(')
          ? ''
          : '<m:begChr m:val="${xmlEsc(d.beg)}"/>';
      final end = (d.end.isEmpty || d.end == ')')
          ? ''
          : '<m:endChr m:val="${xmlEsc(d.end)}"/>';
      final pr = (beg.isEmpty && end.isEmpty) ? '' : '<m:dPr>$beg$end</m:dPr>';
      final body = d.body.isEmpty
          ? '<m:e>$zeroRun()</m:e>'
          : '<m:e>${d.body.map(nodeXml).join()}</m:e>';
      return '<m:d>$pr$body</m:d>';
    case final MAcc a:
      return '<m:acc><m:accPr><m:chr m:val="${xmlEsc(a.chr)}"/></m:accPr><m:e>${nodeXml(a.base)}</m:e></m:acc>';
    case final MBar b:
      return '<m:bar><m:barPr><m:pos m:val="${b.top ? 'top' : 'bot'}"/></m:barPr><m:e>${nodeXml(b.base)}</m:e></m:bar>';
    case final MLim l:
      final tag = l.upper ? 'limUpp' : 'limLow';
      return '<m:$tag><m:e>${nodeXml(l.base)}</m:e><m:lim>${nodeXml(l.lim)}</m:lim></m:$tag>';
    case final MNary na:
      final hides = <String>[];
      if (na.sub == null) hides.add('<m:subHide m:val="1"/>');
      if (na.sup == null) hides.add('<m:supHide m:val="1"/>');
      final pr =
          '<m:naryPr><m:chr m:val="${xmlEsc(na.chr)}"/><m:limLoc m:val="${na.und ? 'undOvr' : 'subSup'}"/>${hides.join()}</m:naryPr>';
      final sub =
          na.sub == null ? '<m:sub/>' : '<m:sub>${nodeXml(na.sub!)}</m:sub>';
      final sup =
          na.sup == null ? '<m:sup/>' : '<m:sup>${nodeXml(na.sup!)}</m:sup>';
      return '<m:nary>$pr$sub$sup<m:e>${nodeXml(na.body)}</m:e></m:nary>';
    case final MMatrix m:
      final inner = matrixInner(m.rows);
      if (m.wrap == null) {
        return '<m:m><m:mPr><m:mcJc m:val="center"/></m:mPr>$inner</m:m>';
      }
      return '<m:d><m:dPr><m:begChr m:val="${xmlEsc(wrapChar(m.wrap!))}"/><m:endChr m:val="${xmlEsc(wrapClose(m.wrap!))}"/></m:dPr><m:e>$inner</m:e></m:d>';
    case final MEqArr e:
      final rowsXml = e.rows
          .map((r0) =>
              '<m:e>${r0.isEmpty ? zeroRun() : r0.map(nodeXml).join()}</m:e>')
          .join();
      if (e.wrapOpen != null) {
        return '<m:d><m:dPr><m:begChr m:val="${xmlEsc(e.wrapOpen!)}"/></m:dPr><m:e>$rowsXml</m:e></m:d>';
      }
      return '<m:eqArr>$rowsXml</m:eqArr>';
  }
}

String matrixInner(List<List<MNode>> rows) {
  final b = StringBuffer();
  final list = rows.isEmpty ? [[]] : rows;
  for (final row in list) {
    b.write('<m:mr>');
    if (row.isEmpty) {
      b.write('<m:e>$zeroRun()</m:e>');
    } else {
      for (final cell in row) {
        b.write('<m:e>${nodeXml(cell)}</m:e>');
      }
    }
    b.write('</m:mr>');
  }
  return b.toString();
}

String runXml(MRun r) {
  final pr = <String>[];
  switch (r.style) {
    case 'b':
      pr.add('<m:sty m:val="b"/>');
      break;
    case 'p':
      pr.add('<m:sty m:val="p"/>');
      break;
    case 'script':
      pr.add('<m:scr m:val="script"/>');
      break;
    case 'ds':
      pr.add('<m:scr m:val="double-struck"/>');
      break;
    case 'fraktur':
      pr.add('<m:scr m:val="fraktur"/>');
      break;
    case 'sans':
      pr.add('<m:scr m:val="sans-serif"/>');
      break;
    case 'nor':
      pr.add('<m:nor/>');
      break;
  }
  final rPr = pr.isEmpty ? '' : '<m:rPr>${pr.join()}</m:rPr>';
  return '<m:r>$rPr<m:t xml:space="preserve">${xmlEsc(r.text)}</m:t></m:r>';
}

/// بناء ملف docx من نتيجة المسح: نصوص حقيقية + معادلات OMML حقيقية (ليست صورًا).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/scan_result.dart';
import 'latex_to_omml.dart';

final _arabicR = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');

bool hasArabic(String s) => _arabicR.hasMatch(s);

String _esc(String s) => s
    .replaceAll('&', '\u0026amp;')
    .replaceAll('<', '\u0026lt;')
    .replaceAll('>', '\u0026gt;');

String _attr(String s) => _esc(s).replaceAll('"', '\u0026quot;');

const String _nsW =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const String _nsM =
    'http://schemas.openxmlformats.org/officeDocument/2006/math';

/// خريطة ترقيم القوائم: [numId, الممنوعة]
class _NumState {
  int nextId = 2;
  final List<String> xml = [];

  int newNum() {
    final id = nextId++;
    xml.add('<w:num w:numId="$id"><w:abstractNumId w:val="1"/></w:num>');
    return id;
  }
}

String _runXml(ScanRun r, bool paraRtl) {
  if (r.isEquation) {
    final latex = r.text;
    final omml = latexToOmmlOrNull(latex);
    if (omml != null) return omml;
    return '<w:r><w:rPr><w:i/><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr><w:t xml:space="preserve">${_esc(latex)}</w:t></w:r>';
  }
  final rtl = paraRtl && hasArabic(r.text);
  final rPr = rtl ? '<w:rPr><w:rtl/><w:rFonts w:cs="Arial"/></w:rPr>' : '';
  return '<w:r>$rPr<w:t xml:space="preserve">${_esc(r.text)}</w:t></w:r>';
}

String _pPr({
  String? style,
  bool bidi = false,
  String? numId,
  int? before,
  int? after = 160,
  String? jc,
  int? line = 276,
}) {
  final parts = StringBuffer();
  if (style != null) parts.write('<w:pStyle w:val="${_attr(style)}"/>');
  if (numId != null) {
    parts.write(
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="${_attr(numId)}"/></w:numPr>');
  }
  if (bidi) parts.write('<w:bidi/>');
  final sp = StringBuffer('<w:spacing');
  if (before != null) sp.write(' w:before="$before"');
  if (after != null) sp.write(' w:after="$after"');
  if (line != null) sp.write(' w:line="$line" w:lineRule="auto"');
  sp.write('/>');
  parts.write(sp);
  if (numId != null) parts.write('<w:ind w:left="720" w:hanging="360"/>');
  if (jc != null) parts.write('<w:jc w:val="${_attr(jc)}"/>');
  return '<w:pPr>${parts}</w:pPr>';
}

/// يبني XML الفقرات في الملف (خارج وظيفة واحدة قابلية اختبار أفضل)
String documentXml(ScanDocument doc, {required _NumState num}) {
  final body = StringBuffer();
  final docArabic =
      hasArabic(doc.title) || doc.blocks.any((b) => hasArabic(_blockText(b)));

  if (doc.title.trim().isNotEmpty) {
    body.write(
        '<w:p>${_pPr(style: 'Title', bidi: hasArabic(doc.title), jc: 'center', after: 240)}'
        '<w:r><w:t xml:space="preserve">${_esc(doc.title.trim())}</w:t></w:r></w:p>');
  }

  String? lastNumId;
  BlockType? lastType;

  for (final b in doc.blocks) {
    switch (b.type) {
      case BlockType.displayEquation:
        final omml = latexToOmmlOrNull(b.latex);
        final inner = omml ??
            '<m:oMath><m:r><m:rPr><m:nor/></m:rPr><m:t xml:space="preserve">${_esc(b.latex)}</m:t></m:r></m:oMath>';
        body.write('<w:p>${_pPr(after: 200, line: 276)}'
            '<m:oMathPara><m:oMathParaPr><m:jc m:val="center"/></m:oMathParaPr>$inner</m:oMathPara></w:p>');
        lastType = b.type;
        break;
      case BlockType.table:
        body.write(_tableXml(b, docArabic));
        body.write('<w:p>${_pPr(after: 80)}</w:p>');
        lastType = b.type;
        break;
      case BlockType.bullet:
      case BlockType.numbered:
        String numId;
        if (b.type == BlockType.numbered) {
          if (lastType != BlockType.numbered) {
            numId = num.newNum().toString();
            lastNumId = numId;
          } else {
            numId = lastNumId ?? num.newNum().toString();
          }
        } else {
          numId = '1';
        }
        final text = _blockText(b);
        body.write('<w:p>${_pPr(bidi: hasArabic(text), numId: numId)}'
            '${b.runs.map((r) => _runXml(r, hasArabic(text))).join()}</w:p>');
        lastType = b.type;
        break;
      case BlockType.heading1:
        _cellHeading(b, body, 'Heading1', 240);
        lastType = b.type;
        break;
      case BlockType.heading2:
        _cellHeading(b, body, 'Heading2', 200);
        lastType = b.type;
        break;
      case BlockType.heading3:
        _cellHeading(b, body, 'Heading3', 160);
        lastType = b.type;
        break;
      case BlockType.paragraph:
        final text = _blockText(b);
        final bidi = hasArabic(text);
        body.write('<w:p>${_pPr(bidi: bidi, jc: bidi ? 'both' : null)}'
            '${b.runs.map((r) => _runXml(r, bidi)).join()}</w:p>');
        lastType = b.type;
        break;
    }
  }
  if (body.isEmpty) {
    body.write(
        '<w:p>${_pPr()}<w:r><w:t xml:space="preserve">\u200F</w:t></w:r></w:p>');
  }

  final bidiSect = docArabic ? '<w:bidi/>' : '';
  final sect = '<w:sectPr>$bidiSect'
      '<w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1417" w:right="1134" w:bottom="1417" w:left="1134" w:header="709" w:footer="709" w:gutter="0"/>'
      '</w:sectPr>';

  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<w:document xmlns:w="$_nsW" xmlns:m="$_nsM" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<w:body>${body}$sect</w:body></w:document>';
}

void _cellHeading(ScanBlock b, StringBuffer body, String style, int before) {
  final text = _blockText(b);
  body.write(
      '<w:p>${_pPr(style: style, bidi: hasArabic(text), before: before, after: 120)}'
      '${b.runs.map((r) => _runXml(r, hasArabic(text))).join()}</w:p>');
}

String _blockText(ScanBlock b) {
  if (b.latex.isNotEmpty) return b.latex;
  final buf = StringBuffer();
  for (final r in b.runs) {
    buf.write(r.text);
  }
  for (final row in b.rows) {
    for (final c in row) {
      buf.write(c.text);
    }
  }
  return buf.toString();
}

String _tableXml(ScanBlock b, bool docArabic) {
  final sb = StringBuffer();
  sb.write('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
      '<w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders>'
      '<w:top w:val="single" w:sz="4" w:color="999999"/>'
      '<w:left w:val="single" w:sz="4" w:color="999999"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="999999"/>'
      '<w:right w:val="single" w:sz="4" w:color="999999"/>'
      '<w:insideH w:val="single" w:sz="4" w:color="999999"/>'
      '<w:insideV w:val="single" w:sz="4" w:color="999999"/>'
      '</w:tblBorders></w:tblPr>');
  for (final row in b.rows) {
    sb.write('<w:tr>');
    if (row.isEmpty) {
      sb.write(
          '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr><w:p>${_pPr()}</w:p></w:tc>');
    }
    for (final cell in row) {
      final cellText = cell.text;
      final bidi = hasArabic(cellText) || docArabic;
      sb.write('<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>'
          '<w:p>${_pPr(bidi: bidi)}${_runXml(cell, bidi)}</w:p></w:tc>');
    }
    sb.write('</w:tr>');
  }
  sb.write('</w:tbl>');
  return sb.toString();
}

String _stylesXml() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<w:styles xmlns:w="$_nsW">'
    '<w:docDefaults><w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>'
    '<w:sz w:val="22"/><w:szCs w:val="22"/>'
    '</w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr/></w:pPrDefault></w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/>'
    '<w:pPr><w:spacing w:after="240"/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="40"/><w:szCs w:val="40"/><w:color w:val="1F4E79"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/>'
    '<w:pPr><w:spacing w:before="240" w:after="120"/><w:keepNext/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/><w:color w:val="1F4E79"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/>'
    '<w:pPr><w:spacing w:before="200" w:after="100"/><w:keepNext/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="2F5496"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/>'
    '<w:pPr><w:spacing w:before="160" w:after="80"/><w:keepNext/></w:pPr>'
    '<w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/><w:color w:val="2F5496"/></w:rPr></w:style>'
    '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/></w:style>'
    '</w:styles>';

String _numberingXml(_NumState num) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<w:numbering xmlns:w="$_nsW">'
    '<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>'
    '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/>'
    '<w:lvlText w:val="\u2022"/><w:lvlJc w:val="left"/>'
    '<w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/></w:rPr></w:lvl>'
    '</w:abstractNum>'
    '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>'
    '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/>'
    '<w:lvlText w:val="%1."/><w:lvlJc w:val="left"/>'
    '<w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl>'
    '</w:abstractNum>'
    '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
    '${num.xml.join()}'
    '</w:numbering>';

String _contentTypesXml() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
    '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '</Types>';

String _relsXml() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

String _docRelsXml() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>'
    '</Relationships>';

String _settingsXml() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<w:settings xmlns:w="$_nsW"><w:defaultTabStop w:val="708"/>'
    '<w:characterSpacingControl w:val="compressPunctuation"/>'
    '</w:settings>';

String _coreXml(ScanDocument doc) {
  final title = doc.title.trim().isEmpty ? 'المستند الممسوح' : doc.title.trim();
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:title>${_esc(title)}</dc:title>'
      '<dc:creator>\u0645\u0627\u0633\u062D \u0627\u0644\u0645\u0639\u0627\u062F\u0644\u0627\u062A</dc:creator>'
      '</cp:coreProperties>';
}

String _appXml() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
    '<Application>EquationScanner</Application></Properties>';

/// يبني ملف docx كامل بايتات ZIP.
Uint8List buildDocx(ScanDocument doc) {
  final num = _NumState();
  final docXml = documentXml(doc, num: num);
  final archive = Archive();

  void addFile(String path, List<int> bytes) {
    final f = ArchiveFile(path, bytes.length, bytes);
    archive.addFile(f);
  }

  void addXml(String path, String xml) => addFile(path, utf8.encode(xml));
  addXml('[Content_Types].xml', _contentTypesXml());
  addXml('_rels/.rels', _relsXml());
  addXml('docProps/core.xml', _coreXml(doc));
  addXml('docProps/app.xml', _appXml());
  addXml('word/document.xml', docXml);
  addXml('word/styles.xml', _stylesXml());
  addXml('word/numbering.xml', _numberingXml(num));
  addXml('word/settings.xml', _settingsXml());
  addXml('word/_rels/document.xml.rels', _docRelsXml());

  final out = ZipEncoder().encode(archive);
  if (out == null) throw const FormatException('فشل ضغط docx');
  return Uint8List.fromList(out);
}

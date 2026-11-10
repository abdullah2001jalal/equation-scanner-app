import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equation_scanner/models/scan_result.dart';
import 'package:equation_scanner/services/docx_builder.dart';
import 'package:equation_scanner/services/latex_to_omml.dart';

void main() {
  group('LaTeX → OMML', () {
    test('كسر وأس', () {
      final xml = latexToOmml(r'\frac{a}{b}+c^2');
      expect(xml, contains('<m:f>'));
      expect(xml, contains('<m:sSup>'));
    });

    test('مجموع بحدود', () {
      final xml = latexToOmml(r'\sum_{i=1}^{n} i^2 = \frac{n(n+1)(2n+1)}{6}');
      expect(xml, contains('<m:nary>'));
      expect(xml, contains('m:limLoc'));
      expect(xml, contains('undOvr'));
    });

    test('جذر وتكامل', () {
      final xml = latexToOmml(r'\int_0^\infty e^{-x^2}\,dx=\frac{\sqrt{\pi}}{2}');
      expect(xml, contains('<m:rad>'));
      expect(xml, contains('<m:nary>'));
    });

    test('كيمياء مع \ce', () {
      final xml = latexToOmml(r'\ce{2H2 + O2 -> 2H2O}');
      expect(xml, contains('<m:sSub>'));
      expect(xml, contains('\u2192'));
    });

    test('مصفوفة', () {
      final xml = latexToOmml(r'M=\begin{pmatrix}1&2\\3&4\end{pmatrix}');
      expect(xml, contains('<m:mr>'));
      expect(xml, contains('begChr'));
    });

    test('فشل آمن', () {
      expect(latexToOmmlOrNull(r'\frac{'), isNull);
    });
  });

  group('docx', () {
    test('بناء ملف سليم ويطبق RTL', () {
      final doc = const ScanDocument(
        title: 'اختبار المعادلة',
        blocks: [
          ScanBlock(type: BlockType.heading1, runs: [ScanRun(text: 'عنوان رئيسي')]),
          ScanBlock(type: BlockType.paragraph, runs: [
            ScanRun(text: 'هذا نص عربي مع '),
            ScanRun(text: r'\frac{a}{b}', isEquation: true),
          ]),
          ScanBlock(type: BlockType.displayEquation, latex: r'\sum_{i=1}^n i'),
          ScanBlock(type: BlockType.numbered, runs: [ScanRun(text: 'أول سؤال')]),
          ScanBlock(type: BlockType.bullet, runs: [ScanRun(text: 'خطوة')]),
        ],
      );
      final bytes = buildDocx(doc);
      final zip = ZipDecoder().decodeBytes(bytes);
      final names = zip.files.map((f) => f.name).toList();
      expect(names, contains('word/document.xml'));
      expect(names, contains('word/styles.xml'));
      final documentXml = utf8.decode(zip.findFile('word/document.xml')!.content as List<int>);
      expect(documentXml, contains('<m:oMath>'));
      expect(documentXml, contains('<m:oMathPara>'));
      expect(documentXml, contains('<w:bidi/>'));
      expect(documentXml, contains('<w:numPr>'));
    });
  });

  group('ScanDocument.fromJson', () {
    test('يحل NNJSON ناتج النموذج', () {
      final map = jsonDecode('''
      {"document":{"title":"ع","blocks":[
        {"type":"heading1","runs":[{"type":"text","text":"a"}]},
        {"type":"display_equation","latex":"\\\\( x^2 \\\\)"},
        {"type":"table","rows":[[{"type":"text","text":"k"},{"type":"equation","latex":"y=mx+b"}]]}
      ]}}''') as Map<String, dynamic>;
      final d = ScanDocument.fromJson(map);
      expect(d.blocks.length, 3);
      expect(d.blocks[1].latex, 'x^2');
      expect(d.blocks[2].rows[0][1].isEquation, isTrue);
    });
  });
}

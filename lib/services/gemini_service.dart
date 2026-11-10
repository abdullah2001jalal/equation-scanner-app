/// خدمة Gemini: مسح الصور/ملفات PDF وإخراج مستند منظّم JSON.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../models/scan_result.dart';

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

class GeminiService {
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';
  final http.Client client;
  GeminiService({http.Client? client}) : client = client ?? http.Client();

  static const int maxChunkImages = 4;
  static const Duration _timeout = Duration(seconds: 300);

  /// فحص مجموعة صور (JPEG bytes) وإرجاع مستند واحد.
  Future<ScanDocument> scanImages(
    List<Uint8List> images, {
    required String apiKey,
    String model = 'gemini-2.5-flash',
    void Function(int done, int total)? onProgress,
  }) async {
    if (images.isEmpty) throw GeminiException('لا توجد صور للتحليل');
    final chunks = <List<Uint8List>>[];
    for (var i = 0; i < images.length; i += maxChunkImages) {
      chunks.add(images.sublist(i, i + maxChunkImages));
    }
    final blocks = <ScanBlock>[];
    String? docTitle;
    for (var c = 0; c < chunks.length; c++) {
      onProgress?.call(c, chunks.length);
      final chunkNote = chunks.length > 1
          ? '\n\n(جهة إضافية: هذه الصور هي الصفحات ${c * maxChunkImages + 1} إلى ${(c + 1) * maxChunkImages} من نفس المستند — تابع الترقيم والتسلسل كما هي دون إعادة عنوان مستند جديد.)'
          : '';
      final part = await _request(
        buildPrompt(chunk: chunkNote),
        imageParts: chunks[c],
        apiKey: apiKey,
        model: model,
      );
      final d = ScanDocument.fromJson(part);
      if (docTitle == null && d.title.trim().isNotEmpty && d.blocks.isNotEmpty)
        docTitle = d.title.trim();
      blocks.addAll(d.blocks);
    }
    onProgress?.call(chunks.length, chunks.length);
    return ScanDocument(title: docTitle ?? '', blocks: blocks);
  }

  /// تحويل PDF إلى صور JPEG (بحد صفحات) ثم فحصها.
  Future<ScanDocument> scanPdf(
    String pdfPath, {
    required String apiKey,
    String model = 'gemini-2.5-flash',
    int maxPages = 40,
    void Function(String message)? onProgress,
  }) async {
    final images = <Uint8List>[];
    final doc = await PdfDocument.openFile(pdfPath);
    final total = doc.pagesCount.clamp(0, maxPages);
    for (var i = 0; i < total; i++) {
      onProgress?.call('تحضير الصفحة ${i + 1} من $total من PDF');
      final page = await doc.getPage(i + 1);
      final physW = page.width > 0 ? page.width.toDouble() : 612.0;
      final physH = page.height > 0 ? page.height.toDouble() : 792.0;
      final scale = 1600.0 / (physW > physH ? physW : physH);
      final w = (physW * scale).round().clamp(200, 2400);
      final h = (physH * scale).round().clamp(200, 3300);
      final rendered = await page.render(
          width: w.toDouble(), height: h.toDouble(), format: PdfPageImageFormat.jpeg);
      if (rendered != null && rendered.bytes.isNotEmpty)
        images.add(Uint8List.fromList(rendered.bytes));
      await page.close();
    }
    await doc.close();
    if (images.isEmpty) throw GeminiException('لم يُحيط أي صفحة من PDF');
    return scanImages(
      images,
      apiKey: apiKey,
      model: model,
      onProgress: (done, t) =>
          onProgress?.call('إرسال الدفعة ${done + 1} من $t إلى Gemini'),
    );
  }

  static Future<Uint8List> compressImage(Uint8List src) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        src,
        quality: 85,
        minWidth: 1200,
        minHeight: 1200,
        rotate: 0,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (out.isEmpty) return src;
      return Uint8List.fromList(out);
    } catch (_) {
      return src;
    }
  }

  // ============================ الداخل ============================

  String buildPrompt({String chunk = ''}) {
    final pr = '''
You are a meticulous OCR document-digitization engine for math, physics and chemistry content.
You will receive scanned pages (photos or PDF renders). Transcribe EVERYTHING you see: printed text AND handwritten notes, in the original language.

STRUCTURE RULES:
- Reading order top-to-bottom, natural paragraphs (split long walls of text into logical paragraphs).
- Section titles => blocks: heading1, heading2, heading3 (1=top level).
- Bullet items => blocks: bullet; numbered exercises/questions => blocks: numbered.
- Tables => block: "table" with rows (array of rows), each row is an array of cells, each cell is an object {"type":"text"|"equation","text"/"latex":...}.
- Standalone equations or derivations => block: "display_equation" with "latex".
- Inline math inside a sentence => runs entry {"type":"equation","latex":"..."} between plain {"type":"text"...} runs. Never mix text and math inside one run.

MATH FORMATTING (high quality, KaTeX-style LaTeX):
- Use \\frac{}{}, \\dfrac{}{}, ^{}, _{}, \\sqrt{}, \\int, \\sum, \\prod, \\lim_{}, greek \\alpha..\\omega, \\pi, \\infty, \\partial, \\nabla, \\vec{}, \\hat{}, \\bar{}, \\pm, \\times, \\cdot, \\leq, \\geq, \\neq, \\approx, \\equiv, \\Rightarrow, \\rightarrow.
- Functions upright: \\sin \\cos \\tan \\log \\ln \\lim \\max \\min. Units and upright words inside math: \\text{...} or \\mathrm{...}.
- Matrices: \\begin{pmatrix}...\\end{pmatrix} / bmatrix / vmatrix. Systems: \\begin{cases}...\\end{cases}.
- Chemistry: use mhchem \\ce{...} for formulas and reactions, e.g. \\ce{2H2 + O2 -> 2H2O}, \\ce{Fe2(SO4)3}, \\ce{HNO3(aq) + KOH(aq) -> KNO3(aq) + H2O(l)}, \\ce{Cu^{2+}}.
- Sub/Superscripts clearly small in source (like H2O, x^2, m/s2) MUST be real _{} or ^{}.

QUALITY RULES:
- Preserve the original language and wording. Do not translate, solve, explain, summarize or add content.
- Fix obvious OCR spelling mistakes ONLY when confident.
- If handwriting is messy: choose the most plausible careful reading; never output placeholders like [unclear]. Decimals, negatives and degrees must be exact.
- Keep numbering exactly as in source (1., (2), أ) ...).
- No markdown syntax anywhere in text runs (no **, no \\(, no \\[, no#, no \$). Plain unicode text only. Math only inside equation runs / latex fields.

OUTPUT: JSON only, following the provided schema exactly.$chunk''';
    return pr;
  }

  Map<String, dynamic> get _schema {
    final runItem = {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'enum': ['text', 'equation']
        },
        'text': {'type': 'string'},
        'latex': {'type': 'string'},
      },
      'required': ['type'],
    };
    return {
      'type': 'object',
      'properties': {
        'document': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'blocks': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'type': {
                    'type': 'string',
                    'enum': [
                      'heading1',
                      'heading2',
                      'heading3',
                      'paragraph',
                      'bullet',
                      'numbered',
                      'display_equation',
                      'table'
                    ],
                  },
                  'runs': {'type': 'array', 'items': runItem},
                  'latex': {'type': 'string'},
                  'rows': {
                    'type': 'array',
                    'items': {'type': 'array', 'items': runItem},
                  },
                },
                'required': ['type'],
              },
            },
          },
          'required': ['blocks'],
        },
      },
      'required': ['document'],
    };
  }

  List<Map<String, dynamic>> _imageParts(List<Uint8List> images) {
    final parts = <Map<String, dynamic>>[];
    for (final img in images) {
      parts.add({
        'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(img)},
      });
    }
    return parts;
  }

  Future<Map<String, dynamic>> _request(
    String prompt, {
    required List<Uint8List> imageParts,
    required String apiKey,
    required String model,
  }) async {
    final genConf = <String, dynamic>{
      'responseMimeType': 'application/json',
      'responseSchema': _schema,
      'temperature': 0.2,
      'topP': 0.95,
      'maxOutputTokens': 32768,
    };
    if (model.contains('2.5') || model.contains('gemini-3')) {
      genConf['thinkingConfig'] = {'thinkingBudget': 0};
    }
    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            ..._imageParts(imageParts),
          ],
        }
      ],
      'generationConfig': genConf,
    };

    final uri = Uri.parse('$_endpoint/$model:generateContent');
    var schemaDropped = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      http.Response resp;
      try {
        resp = await client
            .post(
              uri,
              headers: {
                'x-goog-api-key': apiKey,
                'Content-Type': 'application/json'
              },
              body: jsonEncode(body),
            )
            .timeout(_timeout);
      } on TimeoutException {
        throw GeminiException('انتهت مهلة الاتصال بالخدمة');
      } catch (e) {
        if (attempt == 1) throw GeminiException('تعذر الاتصال: $e');
        await Future.delayed(const Duration(seconds: 4));
        continue;
      }

      if (resp.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final cands = decoded['candidates'] as List? ?? [];
        if (cands.isEmpty) {
          final block = (decoded['promptFeedback'] as Map?)?['blockReason'];
          throw GeminiException(block != null
              ? 'رفض النموذج الطلب: $block'
              : 'لا توجد نتيجة من النموذج');
        }
        final cand = cands.first as Map<String, dynamic>;
        final finishReason = cand['finishReason'];
        final content = cand['content'] as Map<String, dynamic>?;
        final partsRaw = content?['parts'] as List? ?? [];
        final textBuf = StringBuffer();
        for (final pr in partsRaw) {
          if (pr is Map && pr['text'] != null) textBuf.write(pr['text']);
        }
        final text = textBuf.toString().trim();
        if (text.isEmpty) {
          if (finishReason == 'SAFETY')
            throw GeminiException('تم حجز الرد بسبب سياسة السلامة');
          throw GeminiException('ناتج فارغ من النموذج ($finishReason)');
        }
        return _decodeJsonLoose(text);
      }

      final errBody = utf8.decode(resp.bodyBytes, allowMalformed: true);
      String errMessage = errBody;
      try {
        final ej = jsonDecode(errBody) as Map<String, dynamic>;
        final e0 = ej['error'];
        if (e0 is Map && e0['message'] != null)
          errMessage = e0['message'].toString();
      } catch (_) {}

      if ((resp.statusCode == 429 ||
              resp.statusCode == 503 ||
              resp.statusCode == 500) &&
          attempt == 0) {
        await Future.delayed(const Duration(seconds: 6));
        continue;
      }
      if (!schemaDropped &&
          resp.statusCode == 400 &&
          errMessage.toLowerCase().contains('schema')) {
        schemaDropped = true;
        genConf.remove('responseSchema');
        continue;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw GeminiException('مفتاح API غير صالح أو منتهي الصلاحية');
      }
      if (resp.statusCode == 429)
        throw GeminiException(
            'تجاوزت حد الاستخدام، انتظر قليلًا ثم حاول مجددًا');
      if (resp.statusCode == 404)
        throw GeminiException('النموذج "$model" غير متاح');
      throw GeminiException('خطأ من الخدمة (${resp.statusCode}): $errMessage');
    }
    throw GeminiException('فشل الاتصال بعد إعادة المحاولة');
  }

  Map<String, dynamic> _decodeJsonLoose(String text) {
    var t = text.trim();
    final fence = RegExp(r'^```(?:json)?\s*|\s*```$');
    t = t.replaceAllMapped(fence, (m) => '');
    try {
      return jsonDecode(t) as Map<String, dynamic>;
    } catch (_) {
      final i = t.lastIndexOf('}');
      final j0 = t.indexOf('{');
      if (j0 >= 0 && i > j0) {
        try {
          return jsonDecode(t.substring(j0, i + 1)) as Map<String, dynamic>;
        } catch (_) {}
      }
      throw GeminiException('نتيجة غير مفهومة من النموذج');
    }
  }
}

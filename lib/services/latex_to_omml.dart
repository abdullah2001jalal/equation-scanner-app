/// المدخل العام: LaTeX → OMML داخل <m:oMath>.
library;

import 'math_nodes.dart';
import 'latex_tokens.dart';
import 'latex_parser.dart';
import 'latex_commands.dart';

/// يحوّل صيغة LaTeX إلى XML مدقوق لمعادلات Word. يفشل بـ FormatException عند تعذر التحليل.
String latexToOmml(String tex) {
  final src = tex.trim();
  if (src.isEmpty) throw const FormatException('الصيغة فارغة');
  final raw = tokenize(src);
  if (raw.isEmpty) throw const FormatException('لا توجد رموز');
  final p = TexParser(raw);
  TexParser.commandHook = latexCommands;
  final res = p.seq(const []);
  final xml = res.nodes.map(nodeXml).join();
  if (xml.trim().isEmpty) throw const FormatException('لم يُنتج نتيجة');
  return '<m:oMath>$xml</m:oMath>';
}

/// محاولة تحويل آمنة: ترجع null عند الفشل.
String? latexToOmmlOrNull(String tex) {
  try {
    return latexToOmml(tex);
  } catch (_) {
    return null;
  }
}

/// شاشة النتيجة: معاينة منظمة + إنشاء ملف Word ومشاركته.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_result.dart';
import '../services/docx_builder.dart';

class ResultScreen extends StatefulWidget {
  final ScanDocument doc;
  final String apiKey;
  final String model;
  const ResultScreen({super.key, required this.doc, required this.apiKey, required this.model});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _busy = false;

  Future<void> _generateAndShare({required bool share}) async {
    setState(() => _busy = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch.remainder(100000000);
      final path = '${dir.path}/المعادلات_$ts.docx';
      final bytes = buildDocx(widget.doc);
      await File(path).writeAsBytes(bytes, flush: true);
      setState(() { _busy = false; });
      await _pushHistory(path);
      if (share) {
        await Share.shareXFiles(
          [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')],
          text: 'الناتج من ماسح المعادلات',
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ: $path')));
      }
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('فشل إنشاء الملف'),
          content: Text('$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ),
      );
    }
  }

  Future<void> _pushHistory(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('docx_history') ?? [];
      final next = [path, ...list.where((p) => p != path)].take(30).toList();
      await prefs.setStringList('docx_history', next);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('النتيجة')),
        body: _busy
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('جارٍ إنشاء ملف Word...')]))
            : _preview(),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _generateAndShare(share: true),
                    icon: const Icon(Icons.share),
                    label: const Text('إنشاء ملف Word ومشاركته'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _generateAndShare(share: false),
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ فقط'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    final d = widget.doc;
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: d.blocks.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          if (d.title.trim().isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(d.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79)), textAlign: TextAlign.center),
          );
        }
        final b = d.blocks[i - 1];
        return _blockWidget(b);
      },
    );
  }

  Widget _blockWidget(ScanBlock b) {
    switch (b.type) {
      case BlockType.heading1:
        return _heading(b, 18);
      case BlockType.heading2:
        return _heading(b, 16);
      case BlockType.heading3:
        return _heading(b, 14.5);
      case BlockType.paragraph:
      case BlockType.bullet:
      case BlockType.numbered:
        return _paragraph(b, listed: b.type != BlockType.paragraph, numbered: b.type == BlockType.numbered);
      case BlockType.displayEquation:
        return _displayEquation(b.latex);
      case BlockType.table:
        return _tableWidget(b);
    }
  }

  Widget _heading(ScanBlock b, double size) {
    final txt = b.runs.where((r) => !r.isEquation).map((r) => r.text).join();
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(txt.trim().isEmpty ? '(عنوان)' : txt, style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: const Color(0xFF2F5496))),
    );
  }

  Widget _paragraph(ScanBlock b, {required bool listed, required bool numbered}) {
    final spans = <InlineSpan>[];
    if (listed) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(numbered ? '\u0661.' : '\u2022'),
        ),
      ));
    }
    for (final r in b.runs) {
      if (r.isEquation) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _mathSafe(r.text, fontSize: 14),
          ),
        ));
      } else {
        spans.add(TextSpan(text: r.text));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(children: spans),
        style: const TextStyle(fontSize: 15, height: 1.65),
        textDirection: hasArabic(b.runs.map((r) => r.text).join()) ? TextDirection.rtl : TextDirection.ltr,
      ),
    );
  }

  Widget _displayEquation(String latex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: _mathSafe(latex, fontSize: 16)),
    );
  }

  Widget _tableWidget(ScanBlock b) {
    final rows = b.rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.map((r) => r.length).reduce((a, b2) => a > b2 ? a : b2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade400, width: 0.7),
        children: [
          for (final row in rows)
            TableRow(children: [
              for (var c = 0; c < cols; c++)
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: c < row.length && row.isNotEmpty
                      ? (row[c].isEquation
                          ? _mathSafe(row[c].text, fontSize: 12.5)
                          : Text(row[c].text, style: const TextStyle(fontSize: 13)))
                      : const Text(''),
                ),
            ]),
        ],
      ),
    );
  }

  Widget _mathSafe(String latex, {required double fontSize}) {
    try {
      return Math.tex(latex, textStyle: TextStyle(fontSize: fontSize));
    } catch (_) {
      return Text(latex, style: TextStyle(fontSize: fontSize - 1.5, fontFamily: 'monospace', color: Colors.red.shade700), textDirection: TextDirection.ltr);
    }
  }
}

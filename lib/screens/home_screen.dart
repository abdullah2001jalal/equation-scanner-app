/// الشاشة الرئيسية: اختيار المصدر (كاميرا/معرض/PDF) + الإعدادات + سجل الملفات.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gemini_service.dart';
import '../services/settings_store.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _settings = SettingsStore();
  final _service = GeminiService();
  bool _busy = false;
  String _progress = '';
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList('docx_history') ?? []);
  }

  Future<void> _openSettings() async {
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController(text: await _settings.getModel());
    keyCtrl.text = await _settings.getApiKey();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإعدادات'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مفتاح AI Studio (Gemini API)'),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'AQ.Ab8... أو AIza...'),
              ),
              const SizedBox(height: 12),
              const Text('اسم النموذج'),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(hintText: 'gemini-2.5-flash'),
              ),
              const SizedBox(height: 8),
              const Text(
                'يُخزَّن المفتاح على هاتفك فقط، أوتوماتيكي التشفير.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await _settings.setApiKey(keyCtrl.text);
              await _settings.setModel(modelCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _processImages(List<Uint8List> images) async {
    final apiKey = await _settings.getApiKey();
    final model = await _settings.getModel();
    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مفتاح API من زر الإعدادات أولًا'), duration: Duration(seconds: 4)),
      );
      _openSettings();
      return;
    }
    setState(() => _busy = true);
    try {
      final compressed = <Uint8List>[];
      for (var i = 0; i < images.length; i++) {
        setState(() => _progress = 'تحضير الصورة ${i + 1}/${images.length}...');
        compressed.add(await GeminiService.compressImage(images[i]));
      }
      final cImages = <Uint8List>[];
      for (final im in compressed) {
        cImages.add(im);
      }
      final doc = await _service.scanImages(
        cImages,
        apiKey: apiKey,
        model: model,
        onProgress: (done, total) => setState(() => _progress = 'تحليل الدفعة ${done + 1} من $total...'),
      );
      setState(() => _busy = false);
      if (doc.blocks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يُستخرج محتوى! صورة أوضح؟')));
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(doc: doc, apiKey: apiKey, model: model)),
      );
    } on GeminiException catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      _showError('خطأ غير متوقع: $e');
    }
  }

  Future<void> _processPdf(String path) async {
    final apiKey = await _settings.getApiKey();
    final model = await _settings.getModel();
    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مفتاح API من زر الإعدادات أولًا'), duration: Duration(seconds: 4)),
      );
      _openSettings();
      return;
    }
    setState(() => _busy = true);
    try {
      final doc = await _service.scanPdf(
        path,
        apiKey: apiKey,
        model: model,
        onProgress: (m) => setState(() => _progress = m),
      );
      setState(() => _busy = false);
      if (doc.blocks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يُستخرج محتوى من PDF')));
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(doc: doc, apiKey: apiKey, model: model)),
      );
    } on GeminiException catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      _showError('خطأ غير متوقع: $e');
    }
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعذر الاستكمال'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ),
    );
  }

  Future<void> _fromCamera() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100, maxWidth: 2400);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      await _processImages([Uint8List.fromList(bytes)]);
    } catch (e) {
      _showError('تعذر فتح الكاميرا: $e');
    }
  }

  Future<void> _fromGallery() async {
    try {
      final xs = await _picker.pickMultiImage(imageQuality: 100, maxWidth: 2400);
      if (xs.isEmpty) return;
      final imgs = <Uint8List>[];
      for (final x in xs) { imgs.add(Uint8List.fromList(await x.readAsBytes())); }
      await _processImages(imgs);
    } catch (e) {
      _showError('تعذر اختيار الصور: $e');
    }
  }

  Future<void> _fromPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final path = res?.files.single.path;
      if (path == null) return;
      await _processPdf(path);
    } catch (e) {
      _showError('تعذر اختيار PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح المعادلات'),
        actions: [
          IconButton(onPressed: _busy ? null : _openSettings, icon: const Icon(Icons.settings), tooltip: 'الإعدادات'),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _busy ? _busyView() : _idleView(),
      ),
    );
  }

  Widget _idleView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.functions, size: 72, color: Color(0xFF1F4E79)),
        const SizedBox(height: 8),
        const Text(
          'استخرج النصوص والمعادلات الرياضية والكيميائية\nمن صور أو ملفات PDF إلى ملف Word (docx)\nبمعادلات أصلية قابلة للتحرير — يدعم خط اليد وخط الطباعة',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 24),
        _bigButton(Icons.photo_camera, 'التقاط صورة (كاميرا)', _fromCamera, Colors.blue),
        const SizedBox(height: 12),
        _bigButton(Icons.photo_library, 'اختيار صور (معرض) — يدعم تعدد الصفحات', _fromGallery, Colors.green),
        const SizedBox(height: 12),
        _bigButton(Icons.picture_as_pdf, 'اختيار ملف PDF', _fromPdf, Colors.red),
        const SizedBox(height: 28),
        if (_history.isNotEmpty) ...[
          Text('الملفات المسلّمة مؤخراً', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        ..._history.take(8).map((path) => Card(child: ListTile(title: Text(path.replaceAll('\\', ' / ').split(' / ').last), subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.description_outlined)))),
      ],
    );
  }

  Widget _busyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_progress, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('قد تستغرق العملية عدة دقائق — لا تغلق التطبيق', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _bigButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      ),
    );
  }
}

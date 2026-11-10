/// تخزين مفتاح API والإعدادات بأمان.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsStore {
  static const envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyApi = 'gemini_api_key';
  static const _keyModel = 'gemini_model';

  static const defaultModel = 'gemini-2.5-flash';

  Future<String> getApiKey({String envFallback = ''}) async {
    final v = await _storage.read(key: _keyApi);
    if (v != null && v.trim().isNotEmpty) return v.trim();
    return envFallback.trim();
  }

  Future<void> setApiKey(String value) => _storage.write(key: _keyApi, value: value.trim());

  Future<String> getModel() async {
    final v = await _storage.read(key: _keyModel);
    final t = v?.trim();
    return (t != null && t.isNotEmpty) ? t : defaultModel;
  }

  Future<void> setModel(String value) => _storage.write(key: _keyModel, value: value.trim());
}

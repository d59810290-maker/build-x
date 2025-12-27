/// إعدادات API - معطلة في نسخة النماذج المحلية
/// هذه النسخة تعمل بالكامل محلياً بدون أي اتصال خارجي
class ApiConfig {
  static String _apiUrl = "";
  static DateTime? _lastLoadTime;

  /// تحميل الإعدادات - معطل في نسخة النماذج المحلية
  static Future<void> loadConfig() async {
    // نسخة النماذج المحلية لا تحتاج إلى API خارجي
    _apiUrl = "";
    _lastLoadTime = DateTime.now();
    print("📱 Local Models Version - No external API needed");
  }

  /// إعادة تحميل الإعدادات
  static Future<void> reloadConfig() async {
    await loadConfig();
  }

  /// الحصول على رابط API (فارغ دائماً في هذه النسخة)
  static String get apiUrl => _apiUrl;

  /// تعيين رابط API
  static set apiUrl(String url) {
    _apiUrl = url.trim();
    _lastLoadTime = DateTime.now();
  }

  /// التحقق من تحميل الرابط
  static bool isConfigLoaded() {
    // في نسخة النماذج المحلية، نعتبر الإعدادات محملة دائماً
    return true;
  }

  /// التحقق مما إذا كان يجب إعادة تحميل الإعدادات
  static bool shouldReload() {
    return false; // لا حاجة لإعادة التحميل
  }

  /// الحصول على وقت آخر تحميل
  static DateTime? get lastLoadTime => _lastLoadTime;

  /// الحصول على معلومات تفصيلية
  static String getDebugInfo() {
    return '''
═══════════════════════════════════════════════════════════
🔍 Local Models Version - API Config
═══════════════════════════════════════════════════════════
📱 Mode: Local Models Only
🔒 External API: Disabled
✅ Status: Ready for local inference
═══════════════════════════════════════════════════════════
''';
  }
}

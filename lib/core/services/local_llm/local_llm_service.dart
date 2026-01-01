import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_model_info.dart';
import 'available_models.dart';

/// خدمة إدارة النماذج المحلية
class LocalLLMService extends ChangeNotifier {
  static const String _downloadedModelsKey = 'local_llm_downloaded_models_v1';
  static const String _selectedModelKey = 'local_llm_selected_model_v1';
  static const String _settingsKey = 'local_llm_settings_v1';

  static LocalLLMService? _instance;
  static LocalLLMService get instance => _instance ??= LocalLLMService._();

  LocalLLMService._();

  bool _initialized = false;
  bool get initialized => _initialized;

  // النماذج المحملة
  final Map<String, DownloadedModel> _downloadedModels = {};
  Map<String, DownloadedModel> get downloadedModels => Map.unmodifiable(_downloadedModels);

  // النموذج المحدد حالياً
  String? _selectedModelId;
  String? get selectedModelId => _selectedModelId;
  DownloadedModel? get selectedModel => _selectedModelId != null ? _downloadedModels[_selectedModelId] : null;

  // حالة التحميل
  final Map<String, StreamController<double>> _downloadProgressControllers = {};
  final Map<String, bool> _downloadingModels = {};

  // إعدادات النموذج
  LocalLLMSettings _settings = const LocalLLMSettings();
  LocalLLMSettings get settings => _settings;

  // حالة النموذج المحمل في الذاكرة
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;
  String? _loadedModelId;
  String? get loadedModelId => _loadedModelId;

  /// تهيئة الخدمة
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // تحميل النماذج المحملة
      final modelsJson = prefs.getString(_downloadedModelsKey);
      if (modelsJson != null && modelsJson.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(modelsJson);
          for (final entry in data.entries) {
            try {
              final model = DownloadedModel.fromJson(entry.value as Map<String, dynamic>);
              // التحقق من وجود الملف
              if (await File(model.localPath).exists()) {
                _downloadedModels[entry.key] = model;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      // تحميل النموذج المحدد
      _selectedModelId = prefs.getString(_selectedModelKey);
      if (_selectedModelId != null && !_downloadedModels.containsKey(_selectedModelId)) {
        _selectedModelId = null;
      }

      // تحميل الإعدادات
      final settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null && settingsJson.isNotEmpty) {
        try {
          _settings = LocalLLMSettings.fromJson(jsonDecode(settingsJson));
        } catch (_) {}
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing LocalLLMService: $e');
      _initialized = true;
    }
  }

  /// حفظ البيانات
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // حفظ النماذج المحملة
    final modelsData = <String, dynamic>{};
    for (final entry in _downloadedModels.entries) {
      modelsData[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_downloadedModelsKey, jsonEncode(modelsData));

    // حفظ النموذج المحدد
    if (_selectedModelId != null) {
      await prefs.setString(_selectedModelKey, _selectedModelId!);
    } else {
      await prefs.remove(_selectedModelKey);
    }

    // حفظ الإعدادات
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }

  /// الحصول على مسار مجلد النماذج
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/local_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// التحقق مما إذا كان النموذج محملاً
  bool isModelDownloaded(String modelId) {
    return _downloadedModels.containsKey(modelId);
  }

  /// التحقق مما إذا كان النموذج قيد التحميل
  bool isModelDownloading(String modelId) {
    return _downloadingModels[modelId] == true;
  }

  /// الحصول على تقدم التحميل
  Stream<double>? getDownloadProgress(String modelId) {
    return _downloadProgressControllers[modelId]?.stream;
  }

  /// تحميل نموذج مع callback للتقدم وإشعارات
  Future<void> downloadModel(
    LocalModelInfo modelInfo, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
    void Function(String status)? onStatusChange,
  }) async {
    if (_downloadingModels[modelInfo.id] == true) return;
    if (_downloadedModels.containsKey(modelInfo.id)) return;

    _downloadingModels[modelInfo.id] = true;
    _downloadProgressControllers[modelInfo.id] = StreamController<double>.broadcast();
    notifyListeners();

    try {
      final modelsDir = await getModelsDirectory();
      final filePath = '${modelsDir.path}/${modelInfo.filename}';
      final file = File(filePath);

      debugPrint('📥 Starting download: ${modelInfo.name}');
      debugPrint('📍 URL: ${modelInfo.downloadUrl}');
      debugPrint('💾 Save to: $filePath');
      onStatusChange?.call('جاري بدء التحميل... / Starting download...');

      // استخدام HttpClient للتعامل مع redirects بشكل صحيح
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 60);
      httpClient.idleTimeout = const Duration(minutes: 5);
      
      final request = await httpClient.getUrl(Uri.parse(modelInfo.downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 10;
      // إضافة User-Agent لتجنب حظر بعض الخوادم
      request.headers.set('User-Agent', 'BuildX-App/1.0');
      
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل النموذج: HTTP ${response.statusCode}\nFailed to download model: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength > 0 
          ? response.contentLength 
          : modelInfo.sizeBytes;
      int receivedBytes = 0;
      int lastReportedPercent = -1;

      debugPrint('📦 Content length: $contentLength bytes');
      onStatusChange?.call('جاري التحميل... / Downloading...');

      // فتح الملف للكتابة
      final sink = file.openWrite();
      
      // إرسال تقدم أولي
      _downloadProgressControllers[modelInfo.id]?.add(0.0);
      onProgress?.call(0.0, 0, contentLength);

      await for (final chunk in response) {
        // التحقق من إلغاء التحميل
        if (_downloadingModels[modelInfo.id] != true) {
          await sink.close();
          try { await file.delete(); } catch (_) {}
          throw Exception('تم إلغاء التحميل / Download cancelled');
        }
        
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = receivedBytes / contentLength;
        final currentPercent = (progress * 100).toInt();
        
        _downloadProgressControllers[modelInfo.id]?.add(progress);
        onProgress?.call(progress, receivedBytes, contentLength);
        
        // إرسال إشعار كل 5%
        if (currentPercent != lastReportedPercent && currentPercent % 5 == 0) {
          lastReportedPercent = currentPercent;
          final downloadedMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (contentLength / (1024 * 1024)).toStringAsFixed(1);
          debugPrint('⬇️ Download progress: $currentPercent% ($downloadedMB MB / $totalMB MB)');
          onStatusChange?.call('$currentPercent% - $downloadedMB MB / $totalMB MB');
        }
      }

      await sink.close();
      httpClient.close();

      debugPrint('✅ Download complete: ${modelInfo.name}');
      onStatusChange?.call('اكتمل التحميل! ✅ / Download complete!');

      // إنشاء سجل النموذج المحمل
      final downloadedModel = DownloadedModel(
        info: modelInfo,
        localPath: filePath,
        downloadedAt: DateTime.now(),
        status: LocalModelStatus.downloaded,
      );

      _downloadedModels[modelInfo.id] = downloadedModel;
      await _save();

      _downloadProgressControllers[modelInfo.id]?.add(1.0);
      onProgress?.call(1.0, contentLength, contentLength);
    } catch (e) {
      debugPrint('❌ Error downloading model: $e');
      onStatusChange?.call('فشل التحميل: $e');
      _downloadProgressControllers[modelInfo.id]?.addError(e);
      rethrow;
    } finally {
      _downloadingModels[modelInfo.id] = false;
      await _downloadProgressControllers[modelInfo.id]?.close();
      _downloadProgressControllers.remove(modelInfo.id);
      notifyListeners();
    }
  }

  /// إلغاء تحميل نموذج
  Future<void> cancelDownload(String modelId) async {
    _downloadingModels[modelId] = false;
    await _downloadProgressControllers[modelId]?.close();
    _downloadProgressControllers.remove(modelId);
    notifyListeners();
  }

  /// حذف نموذج محمل
  Future<void> deleteModel(String modelId) async {
    final model = _downloadedModels[modelId];
    if (model == null) return;

    try {
      final file = File(model.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting model file: $e');
    }

    _downloadedModels.remove(modelId);

    if (_selectedModelId == modelId) {
      _selectedModelId = null;
      _isModelLoaded = false;
      _loadedModelId = null;
    }

    await _save();
    notifyListeners();
  }

  /// تحديد النموذج النشط
  Future<void> selectModel(String modelId) async {
    if (!_downloadedModels.containsKey(modelId)) return;

    _selectedModelId = modelId;
    await _save();
    notifyListeners();
  }

  /// إلغاء تحديد النموذج
  Future<void> deselectModel() async {
    _selectedModelId = null;
    _isModelLoaded = false;
    _loadedModelId = null;
    await _save();
    notifyListeners();
  }

  /// تحديث الإعدادات
  Future<void> updateSettings(LocalLLMSettings newSettings) async {
    _settings = newSettings;
    await _save();
    notifyListeners();
  }

  /// الحصول على قائمة النماذج المتاحة للتنزيل
  List<LocalModelInfo> get availableModels => AvailableModels.models;

  /// الحصول على النماذج التي تدعم العربية
  List<LocalModelInfo> get arabicModels => AvailableModels.arabicModels;

  /// الحصول على النماذج الخفيفة
  List<LocalModelInfo> get lightweightModels => AvailableModels.lightweightModels;

  /// الحصول على حجم التخزين المستخدم
  Future<int> getUsedStorage() async {
    int total = 0;
    for (final model in _downloadedModels.values) {
      try {
        final file = File(model.localPath);
        if (await file.exists()) {
          total += await file.length();
        }
      } catch (_) {}
    }
    return total;
  }

  /// تنظيف النماذج غير المستخدمة
  Future<void> cleanupUnusedModels() async {
    final modelsDir = await getModelsDirectory();
    if (!await modelsDir.exists()) return;

    final validPaths = _downloadedModels.values.map((m) => m.localPath).toSet();

    await for (final entity in modelsDir.list()) {
      if (entity is File && !validPaths.contains(entity.path)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  /// التحقق من صحة النماذج المحملة
  Future<void> validateDownloadedModels() async {
    final toRemove = <String>[];

    for (final entry in _downloadedModels.entries) {
      final file = File(entry.value.localPath);
      if (!await file.exists()) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _downloadedModels.remove(id);
    }

    if (toRemove.isNotEmpty) {
      if (_selectedModelId != null && toRemove.contains(_selectedModelId)) {
        _selectedModelId = null;
      }
      await _save();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final controller in _downloadProgressControllers.values) {
      controller.close();
    }
    super.dispose();
  }
}

/// إعدادات النموذج المحلي
class LocalLLMSettings {
  final int contextLength;
  final double temperature;
  final double topP;
  final int topK;
  final double repeatPenalty;
  final int maxTokens;
  final int threads;
  final bool useGpu;
  final int gpuLayers;
  final String systemPrompt;
  final String systemPromptAr;

  const LocalLLMSettings({
    this.contextLength = 2048,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.repeatPenalty = 1.1,
    this.maxTokens = 512,
    this.threads = 4,
    this.useGpu = true,
    this.gpuLayers = 0,
    this.systemPrompt = 'You are a helpful AI assistant.',
    this.systemPromptAr = 'أنت مساعد ذكاء اصطناعي مفيد.',
  });

  LocalLLMSettings copyWith({
    int? contextLength,
    double? temperature,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? threads,
    bool? useGpu,
    int? gpuLayers,
    String? systemPrompt,
    String? systemPromptAr,
  }) {
    return LocalLLMSettings(
      contextLength: contextLength ?? this.contextLength,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      maxTokens: maxTokens ?? this.maxTokens,
      threads: threads ?? this.threads,
      useGpu: useGpu ?? this.useGpu,
      gpuLayers: gpuLayers ?? this.gpuLayers,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      systemPromptAr: systemPromptAr ?? this.systemPromptAr,
    );
  }

  Map<String, dynamic> toJson() => {
        'contextLength': contextLength,
        'temperature': temperature,
        'topP': topP,
        'topK': topK,
        'repeatPenalty': repeatPenalty,
        'maxTokens': maxTokens,
        'threads': threads,
        'useGpu': useGpu,
        'gpuLayers': gpuLayers,
        'systemPrompt': systemPrompt,
        'systemPromptAr': systemPromptAr,
      };

  factory LocalLLMSettings.fromJson(Map<String, dynamic> json) => LocalLLMSettings(
        contextLength: json['contextLength'] as int? ?? 2048,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
        topK: json['topK'] as int? ?? 40,
        repeatPenalty: (json['repeatPenalty'] as num?)?.toDouble() ?? 1.1,
        maxTokens: json['maxTokens'] as int? ?? 512,
        threads: json['threads'] as int? ?? 4,
        useGpu: json['useGpu'] as bool? ?? true,
        gpuLayers: json['gpuLayers'] as int? ?? 0,
        systemPrompt: json['systemPrompt'] as String? ?? 'You are a helpful AI assistant.',
        systemPromptAr: json['systemPromptAr'] as String? ?? 'أنت مساعد ذكاء اصطناعي مفيد.',
      );
}

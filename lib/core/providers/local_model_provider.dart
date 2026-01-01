import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/local_llm/local_llm_service.dart';
import '../services/local_llm/local_inference_service.dart';
import '../services/local_llm/local_model_info.dart';
import '../services/local_llm/available_models.dart';

/// مزود النماذج المحلية
/// يدير حالة النماذج المحلية ويوفر واجهة للتفاعل معها
class LocalModelProvider extends ChangeNotifier {
  final LocalLLMService _llmService = LocalLLMService.instance;
  final LocalInferenceService _inferenceService = LocalInferenceService.instance;

  bool _initialized = false;
  bool get initialized => _initialized;

  // حالة التحميل
  final Map<String, double> _downloadProgress = {};
  final Map<String, String?> _downloadErrors = {};

  // فلتر النماذج
  String _searchQuery = '';
  String _categoryFilter = 'all'; // 'all', 'arabic', 'lightweight', 'multilingual'
  bool _showOnlyDownloaded = false;

  String get searchQuery => _searchQuery;
  String get categoryFilter => _categoryFilter;
  bool get showOnlyDownloaded => _showOnlyDownloaded;

  /// تهيئة المزود
  Future<void> init() async {
    if (_initialized) return;

    await _llmService.init();

    _llmService.addListener(_onServiceChanged);
    _inferenceService.addListener(_onServiceChanged);

    _initialized = true;
    notifyListeners();
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  // ===== الحصول على النماذج =====

  /// جميع النماذج المتاحة
  List<LocalModelInfo> get allModels => AvailableModels.models;

  /// النماذج المفلترة
  List<LocalModelInfo> get filteredModels {
    var models = allModels;

    // فلتر الفئة
    if (_categoryFilter == 'arabic') {
      models = models.where((m) => m.supportsArabic).toList();
    } else if (_categoryFilter == 'lightweight') {
      models = models.where((m) => m.sizeBytes < 1024 * 1024 * 1024).toList();
    } else if (_categoryFilter == 'multilingual') {
      models = models.where((m) => m.languages.length > 3).toList();
    }

    // فلتر المحملة فقط
    if (_showOnlyDownloaded) {
      models = models.where((m) => isModelDownloaded(m.id)).toList();
    }

    // فلتر البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      models = models.where((m) =>
          m.name.toLowerCase().contains(query) ||
          m.nameAr.contains(query) ||
          m.description.toLowerCase().contains(query) ||
          m.descriptionAr.contains(query)).toList();
    }

    return models;
  }

  /// النماذج المحملة
  Map<String, DownloadedModel> get downloadedModels => _llmService.downloadedModels;

  /// النموذج المحدد
  DownloadedModel? get selectedModel => _llmService.selectedModel;
  String? get selectedModelId => _llmService.selectedModelId;

  /// النموذج المحمل في الذاكرة
  bool get isModelLoaded => _inferenceService.isModelLoaded;
  String? get loadedModelId => _inferenceService.loadedModelId;
  bool get isLoading => _inferenceService.isLoading;
  bool get isGenerating => _inferenceService.isGenerating;

  /// الإعدادات
  LocalLLMSettings get settings => _llmService.settings;

  // ===== إدارة الفلاتر =====

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setShowOnlyDownloaded(bool value) {
    _showOnlyDownloaded = value;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = 'all';
    _showOnlyDownloaded = false;
    notifyListeners();
  }

  // ===== إدارة النماذج =====

  /// التحقق مما إذا كان النموذج محملاً
  bool isModelDownloaded(String modelId) => _llmService.isModelDownloaded(modelId);

  /// التحقق مما إذا كان النموذج قيد التحميل
  bool isModelDownloading(String modelId) => _llmService.isModelDownloading(modelId);

  /// الحصول على تقدم التحميل
  double getDownloadProgress(String modelId) => _downloadProgress[modelId] ?? 0.0;

  /// الحصول على خطأ التحميل
  String? getDownloadError(String modelId) => _downloadErrors[modelId];

  // حالة التحميل الحالية
  final Map<String, String> _downloadStatus = {};
  String getDownloadStatus(String modelId) => _downloadStatus[modelId] ?? '';

  /// تحميل نموذج مع إشعارات التقدم
  Future<void> downloadModel(String modelId, {
    void Function(String status)? onStatusChange,
  }) async {
    final modelInfo = AvailableModels.findById(modelId);
    if (modelInfo == null) return;

    _downloadProgress[modelId] = 0.0;
    _downloadErrors[modelId] = null;
    _downloadStatus[modelId] = 'جاري البدء... / Starting...';
    notifyListeners();

    try {
      // بدء التحميل مع callback للتقدم والحالة
      await _llmService.downloadModel(
        modelInfo,
        onProgress: (progress, receivedBytes, totalBytes) {
          _downloadProgress[modelId] = progress;
          notifyListeners();
        },
        onStatusChange: (status) {
          _downloadStatus[modelId] = status;
          onStatusChange?.call(status);
          notifyListeners();
        },
      );

      _downloadProgress.remove(modelId);
      _downloadStatus[modelId] = 'اكتمل! ✅ / Complete!';
      notifyListeners();
      
      // مسح الحالة بعد ثانيتين
      Future.delayed(const Duration(seconds: 2), () {
        _downloadStatus.remove(modelId);
        notifyListeners();
      });
    } catch (e) {
      _downloadErrors[modelId] = e.toString();
      _downloadProgress.remove(modelId);
      _downloadStatus[modelId] = 'فشل: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// إلغاء تحميل نموذج
  Future<void> cancelDownload(String modelId) async {
    await _llmService.cancelDownload(modelId);
    _downloadProgress.remove(modelId);
    notifyListeners();
  }

  /// حذف نموذج
  Future<void> deleteModel(String modelId) async {
    // إلغاء تحميل النموذج من الذاكرة إذا كان محملاً
    if (_inferenceService.loadedModelId == modelId) {
      await _inferenceService.unloadModel();
    }
    await _llmService.deleteModel(modelId);
  }

  /// تحديد نموذج
  Future<void> selectModel(String modelId) async {
    await _llmService.selectModel(modelId);
  }

  /// إلغاء تحديد النموذج
  Future<void> deselectModel() async {
    await _llmService.deselectModel();
  }

  // ===== تحميل النموذج في الذاكرة =====

  /// تحميل النموذج المحدد في الذاكرة
  Future<bool> loadSelectedModel() async {
    final model = selectedModel;
    if (model == null) return false;

    return await _inferenceService.loadModel(model, settings);
  }

  /// تحميل نموذج محدد في الذاكرة
  Future<bool> loadModel(String modelId) async {
    final model = downloadedModels[modelId];
    if (model == null) return false;

    await selectModel(modelId);
    return await _inferenceService.loadModel(model, settings);
  }

  /// إلغاء تحميل النموذج من الذاكرة
  Future<void> unloadModel() async {
    await _inferenceService.unloadModel();
  }

  // ===== الاستدلال =====

  /// توليد استجابة
  Stream<String> generateResponse({
    required String prompt,
    List<Map<String, String>>? history,
    String? systemPrompt,
  }) {
    return _inferenceService.generateResponse(
      prompt: prompt,
      history: history,
      systemPrompt: systemPrompt,
      maxTokens: settings.maxTokens,
      temperature: settings.temperature,
    );
  }

  /// إيقاف التوليد
  void stopGeneration() {
    _inferenceService.stopGeneration();
  }

  // ===== الإعدادات =====

  /// تحديث الإعدادات
  Future<void> updateSettings(LocalLLMSettings newSettings) async {
    await _llmService.updateSettings(newSettings);

    // إعادة تحميل النموذج إذا كان محملاً
    if (isModelLoaded && selectedModel != null) {
      await _inferenceService.loadModel(selectedModel!, newSettings);
    }
  }

  // ===== معلومات التخزين =====

  /// الحصول على حجم التخزين المستخدم
  Future<int> getUsedStorage() async {
    return await _llmService.getUsedStorage();
  }

  /// تنظيف النماذج غير المستخدمة
  Future<void> cleanupUnusedModels() async {
    await _llmService.cleanupUnusedModels();
  }

  @override
  void dispose() {
    _llmService.removeListener(_onServiceChanged);
    _inferenceService.removeListener(_onServiceChanged);
    super.dispose();
  }
}

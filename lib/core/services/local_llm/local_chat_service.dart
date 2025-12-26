import 'dart:async';
import 'package:flutter/foundation.dart';
import 'local_llm_service.dart';
import 'local_inference_service.dart';
import 'local_model_info.dart';

/// خدمة المحادثة المحلية
/// تدمج بين خدمة إدارة النماذج وخدمة الاستدلال
class LocalChatService extends ChangeNotifier {
  static LocalChatService? _instance;
  static LocalChatService get instance => _instance ??= LocalChatService._();

  LocalChatService._();

  final LocalLLMService _llmService = LocalLLMService.instance;
  final LocalInferenceService _inferenceService = LocalInferenceService.instance;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool get isModelLoaded => _inferenceService.isModelLoaded;
  bool get isGenerating => _inferenceService.isGenerating;
  String? get lastError => _inferenceService.lastError;

  DownloadedModel? get currentModel => _llmService.selectedModel;
  LocalLLMSettings get settings => _llmService.settings;

  /// تهيئة الخدمة
  Future<void> init() async {
    if (_initialized) return;

    await _llmService.init();

    // الاستماع للتغييرات
    _llmService.addListener(_onLLMServiceChanged);
    _inferenceService.addListener(_onInferenceServiceChanged);

    _initialized = true;
    notifyListeners();
  }

  void _onLLMServiceChanged() {
    notifyListeners();
  }

  void _onInferenceServiceChanged() {
    notifyListeners();
  }

  /// تحميل النموذج المحدد
  Future<bool> loadSelectedModel() async {
    final model = _llmService.selectedModel;
    if (model == null) {
      return false;
    }

    return await _inferenceService.loadModel(model, _llmService.settings);
  }

  /// تحميل نموذج محدد
  Future<bool> loadModel(String modelId) async {
    final model = _llmService.downloadedModels[modelId];
    if (model == null) {
      return false;
    }

    await _llmService.selectModel(modelId);
    return await _inferenceService.loadModel(model, _llmService.settings);
  }

  /// إلغاء تحميل النموذج
  Future<void> unloadModel() async {
    await _inferenceService.unloadModel();
  }

  /// إرسال رسالة والحصول على استجابة متدفقة
  Stream<String> sendMessage({
    required String message,
    List<Map<String, String>>? history,
    String? systemPrompt,
  }) {
    if (!isModelLoaded) {
      return Stream.error(Exception('No model loaded'));
    }

    // استخدام system prompt من الإعدادات إذا لم يتم تحديده
    final effectiveSystemPrompt = systemPrompt ?? 
        (_isArabicText(message) ? settings.systemPromptAr : settings.systemPrompt);

    return _inferenceService.generateResponse(
      prompt: message,
      history: history,
      systemPrompt: effectiveSystemPrompt,
      maxTokens: settings.maxTokens,
      temperature: settings.temperature,
    );
  }

  /// إيقاف التوليد
  void stopGeneration() {
    _inferenceService.stopGeneration();
  }

  /// تحديث الإعدادات
  Future<void> updateSettings(LocalLLMSettings newSettings) async {
    await _llmService.updateSettings(newSettings);

    // إعادة تحميل النموذج إذا كان محملاً
    if (isModelLoaded && currentModel != null) {
      await _inferenceService.loadModel(currentModel!, newSettings);
    }
  }

  /// التحقق مما إذا كان النص عربياً
  bool _isArabicText(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// الحصول على قائمة النماذج المتاحة
  List<LocalModelInfo> get availableModels => _llmService.availableModels;

  /// الحصول على النماذج المحملة
  Map<String, DownloadedModel> get downloadedModels => _llmService.downloadedModels;

  /// تحميل نموذج جديد
  Future<void> downloadModel(LocalModelInfo modelInfo) async {
    await _llmService.downloadModel(modelInfo);
  }

  /// حذف نموذج
  Future<void> deleteModel(String modelId) async {
    if (_inferenceService.loadedModelId == modelId) {
      await unloadModel();
    }
    await _llmService.deleteModel(modelId);
  }

  /// التحقق مما إذا كان النموذج محملاً
  bool isModelDownloaded(String modelId) => _llmService.isModelDownloaded(modelId);

  /// التحقق مما إذا كان النموذج قيد التحميل
  bool isModelDownloading(String modelId) => _llmService.isModelDownloading(modelId);

  /// الحصول على تقدم التحميل
  Stream<double>? getDownloadProgress(String modelId) => _llmService.getDownloadProgress(modelId);

  @override
  void dispose() {
    _llmService.removeListener(_onLLMServiceChanged);
    _inferenceService.removeListener(_onInferenceServiceChanged);
    super.dispose();
  }
}

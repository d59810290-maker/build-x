import 'dart:async';
import 'package:flutter/foundation.dart';
import 'local_llm_service.dart';
import 'local_inference_service.dart';
import 'local_model_info.dart';

/// خدمة API للنماذج المحلية
/// توفر واجهة متوافقة مع ChatApiService للتكامل مع نظام المحادثة
class LocalApiService {
  static final LocalApiService _instance = LocalApiService._();
  static LocalApiService get instance => _instance;

  LocalApiService._();

  final LocalLLMService _llmService = LocalLLMService.instance;
  final LocalInferenceService _inferenceService = LocalInferenceService.instance;

  /// التحقق مما إذا كان النموذج المحلي متاحاً
  bool get isAvailable => _inferenceService.isModelLoaded;

  /// الحصول على معرف النموذج المحمل
  String? get loadedModelId => _inferenceService.loadedModelId;

  /// إرسال رسالة مع استجابة متدفقة
  Future<Stream<String>> sendMessageStream({
    required String prompt,
    List<Map<String, dynamic>>? messages,
    String? systemPrompt,
  }) async {
    if (!isAvailable) {
      throw Exception('No local model loaded. Please load a model first.');
    }

    // تحويل الرسائل إلى التنسيق المطلوب
    final history = messages?.map((m) {
      return {
        'role': m['role']?.toString() ?? 'user',
        'content': m['content']?.toString() ?? '',
      };
    }).toList();

    // استخدام system prompt من الإعدادات إذا لم يتم تحديده
    final effectiveSystemPrompt = systemPrompt ?? 
        (_isArabicText(prompt) 
            ? _llmService.settings.systemPromptAr 
            : _llmService.settings.systemPrompt);

    return _inferenceService.generateResponse(
      prompt: prompt,
      history: history,
      systemPrompt: effectiveSystemPrompt,
      maxTokens: _llmService.settings.maxTokens,
      temperature: _llmService.settings.temperature,
    );
  }

  /// توليد نص (للعناوين وغيرها)
  Future<String> generateText({
    required String prompt,
  }) async {
    if (!isAvailable) {
      throw Exception('No local model loaded. Please load a model first.');
    }

    final buffer = StringBuffer();
    final stream = _inferenceService.generateResponse(
      prompt: prompt,
      maxTokens: 256,
      temperature: 0.7,
    );

    await for (final chunk in stream) {
      buffer.write(chunk);
    }

    return buffer.toString();
  }

  /// إيقاف التوليد
  void stopGeneration() {
    _inferenceService.stopGeneration();
  }

  /// التحقق مما إذا كان النص عربياً
  bool _isArabicText(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// الحصول على معلومات النموذج المحمل
  DownloadedModel? get loadedModel {
    final modelId = _inferenceService.loadedModelId;
    if (modelId == null) return null;
    return _llmService.downloadedModels[modelId];
  }

  /// التحقق من حالة التوليد
  bool get isGenerating => _inferenceService.isGenerating;

  /// التحقق من حالة التحميل
  bool get isLoading => _inferenceService.isLoading;

  /// الحصول على آخر خطأ
  String? get lastError => _inferenceService.lastError;
}

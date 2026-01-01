import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'local_model_info.dart';
import 'local_llm_service.dart';

/// خدمة الاستدلال المحلي باستخدام flutter_llama (llama.cpp)
class LocalInferenceService extends ChangeNotifier {
  static LocalInferenceService? _instance;
  static LocalInferenceService get instance => _instance ??= LocalInferenceService._();

  LocalInferenceService._();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  String? _loadedModelPath;
  String? get loadedModelPath => _loadedModelPath;

  String? _loadedModelId;
  String? get loadedModelId => _loadedModelId;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _lastError;
  String? get lastError => _lastError;

  // flutter_llama singleton instance
  final FlutterLlama _llama = FlutterLlama.instance;
  LocalLLMSettings? _currentSettings;
  StreamController<String>? _responseController;
  bool _shouldStop = false;

  /// تحميل النموذج في الذاكرة
  Future<bool> loadModel(DownloadedModel model, LocalLLMSettings settings) async {
    if (_isLoading) return false;

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // التحقق من وجود الملف
      final file = File(model.localPath);
      if (!await file.exists()) {
        throw Exception('Model file not found: ${model.localPath}');
      }

      // إنهاء أي نموذج سابق
      await unloadModel();

      debugPrint('🔄 Loading model: ${model.localPath}');
      debugPrint('📊 Settings: threads=${settings.threads}, context=${settings.contextLength}');

      // إنشاء تكوين النموذج
      final config = LlamaConfig(
        modelPath: model.localPath,
        nThreads: settings.threads,
        nGpuLayers: settings.gpuLayers,
        contextSize: settings.contextLength,
        batchSize: 512,
        useGpu: settings.gpuLayers > 0,
        verbose: kDebugMode,
      );

      // تحميل النموذج باستخدام flutter_llama
      final success = await _llama.loadModel(config);

      if (success) {
        _currentSettings = settings;
        _isModelLoaded = true;
        _loadedModelPath = model.localPath;
        _loadedModelId = model.info.id;
        debugPrint('✅ Model loaded successfully: ${model.info.name}');
      } else {
        throw Exception('Failed to load model');
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('❌ Error loading model: $e');
      _lastError = e.toString();
      _isLoading = false;
      _isModelLoaded = false;
      notifyListeners();
      return false;
    }
  }

  /// إلغاء تحميل النموذج من الذاكرة
  Future<void> unloadModel() async {
    _shouldStop = true;
    
    try {
      if (_llama.isModelLoaded) {
        await _llama.unloadModel();
      }
    } catch (e) {
      debugPrint('Warning: Error unloading model: $e');
    }
    
    _isModelLoaded = false;
    _loadedModelPath = null;
    _loadedModelId = null;
    _isGenerating = false;
    _responseController?.close();
    _responseController = null;
    notifyListeners();
  }

  /// توليد استجابة
  Stream<String> generateResponse({
    required String prompt,
    List<Map<String, String>>? history,
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
  }) {
    if (!_isModelLoaded || !_llama.isModelLoaded) {
      return Stream.error(Exception('Model not loaded'));
    }

    if (_isGenerating) {
      return Stream.error(Exception('Already generating'));
    }

    _isGenerating = true;
    _shouldStop = false;
    _responseController = StreamController<String>.broadcast();
    notifyListeners();

    // بناء prompt كامل مع السياق
    final fullPrompt = _buildFullPrompt(
      prompt: prompt,
      history: history,
      systemPrompt: systemPrompt,
    );

    // بدء التوليد في background
    _generateAsync(
      fullPrompt: fullPrompt,
      maxTokens: maxTokens ?? _currentSettings?.maxTokens ?? 512,
      temperature: temperature ?? _currentSettings?.temperature ?? 0.7,
    );

    return _responseController!.stream;
  }

  /// بناء prompt كامل مع السياق والتاريخ
  String _buildFullPrompt({
    required String prompt,
    List<Map<String, String>>? history,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    
    // إضافة system prompt
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.writeln('<|system|>');
      buffer.writeln(systemPrompt);
      buffer.writeln('<|end|>');
    }
    
    // إضافة التاريخ
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        buffer.writeln('<|$role|>');
        buffer.writeln(content);
        buffer.writeln('<|end|>');
      }
    }
    
    // إضافة الرسالة الحالية
    buffer.writeln('<|user|>');
    buffer.writeln(prompt);
    buffer.writeln('<|end|>');
    buffer.writeln('<|assistant|>');
    
    return buffer.toString();
  }

  /// توليد الاستجابة بشكل غير متزامن
  Future<void> _generateAsync({
    required String fullPrompt,
    required int maxTokens,
    required double temperature,
  }) async {
    try {
      debugPrint('🚀 Starting generation with $maxTokens max tokens');
      
      // إنشاء معلمات التوليد
      final params = GenerationParams(
        prompt: fullPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: _currentSettings?.topP ?? 0.9,
        topK: _currentSettings?.topK ?? 40,
        repeatPenalty: _currentSettings?.repeatPenalty ?? 1.1,
      );

      // استخدام flutter_llama للتوليد المتدفق
      final stream = _llama.generateStream(params);

      await for (final token in stream) {
        if (_shouldStop) {
          debugPrint('⏹️ Generation stopped by user');
          await _llama.stopGeneration();
          break;
        }
        
        // إرسال token للـ stream
        _responseController?.add(token);
      }

      debugPrint('✅ Generation completed');
    } catch (e) {
      debugPrint('❌ Generation error: $e');
      _responseController?.addError(e);
    } finally {
      _isGenerating = false;
      _responseController?.close();
      _responseController = null;
      notifyListeners();
    }
  }

  /// إيقاف التوليد
  void stopGeneration() {
    _shouldStop = true;
    _llama.stopGeneration();
    debugPrint('⏹️ Stop generation requested');
  }

  @override
  void dispose() {
    unloadModel();
    super.dispose();
  }
}

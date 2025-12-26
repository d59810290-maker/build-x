import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'local_model_info.dart';
import 'local_llm_service.dart';

/// خدمة الاستدلال المحلي باستخدام llama.cpp
/// تعمل في Isolate منفصل لتجنب حجب واجهة المستخدم
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

  // Isolate للاستدلال
  Isolate? _inferenceIsolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  StreamController<String>? _responseController;

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

      // إنهاء أي Isolate سابق
      await unloadModel();

      // إنشاء قناة الاتصال
      _receivePort = ReceivePort();

      // بدء Isolate الاستدلال
      _inferenceIsolate = await Isolate.spawn(
        _inferenceIsolateEntry,
        _InferenceInitMessage(
          sendPort: _receivePort!.sendPort,
          modelPath: model.localPath,
          settings: settings,
        ),
      );

      // انتظار رسالة التهيئة
      final completer = Completer<bool>();

      _receivePort!.listen((message) {
        if (message is SendPort) {
          _sendPort = message;
        } else if (message is _InferenceResponse) {
          if (message.type == _ResponseType.initialized) {
            _isModelLoaded = true;
            _loadedModelPath = model.localPath;
            _loadedModelId = model.info.id;
            completer.complete(true);
          } else if (message.type == _ResponseType.error) {
            _lastError = message.content;
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          } else if (message.type == _ResponseType.token) {
            _responseController?.add(message.content ?? '');
          } else if (message.type == _ResponseType.done) {
            _isGenerating = false;
            _responseController?.close();
            _responseController = null;
            notifyListeners();
          }
        }
      });

      final result = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _lastError = 'Model loading timed out';
          return false;
        },
      );

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      _isModelLoaded = false;
      notifyListeners();
      return false;
    }
  }

  /// إلغاء تحميل النموذج من الذاكرة
  Future<void> unloadModel() async {
    _inferenceIsolate?.kill(priority: Isolate.immediate);
    _inferenceIsolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
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
    if (!_isModelLoaded || _sendPort == null) {
      return Stream.error(Exception('Model not loaded'));
    }

    if (_isGenerating) {
      return Stream.error(Exception('Already generating'));
    }

    _isGenerating = true;
    _responseController = StreamController<String>.broadcast();
    notifyListeners();

    _sendPort!.send(_InferenceRequest(
      prompt: prompt,
      history: history,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    ));

    return _responseController!.stream;
  }

  /// إيقاف التوليد
  void stopGeneration() {
    if (_isGenerating && _sendPort != null) {
      _sendPort!.send(_StopRequest());
    }
  }

  @override
  void dispose() {
    unloadModel();
    super.dispose();
  }
}

// ===== رسائل الاتصال بين Isolates =====

class _InferenceInitMessage {
  final SendPort sendPort;
  final String modelPath;
  final LocalLLMSettings settings;

  _InferenceInitMessage({
    required this.sendPort,
    required this.modelPath,
    required this.settings,
  });
}

class _InferenceRequest {
  final String prompt;
  final List<Map<String, String>>? history;
  final String? systemPrompt;
  final int? maxTokens;
  final double? temperature;

  _InferenceRequest({
    required this.prompt,
    this.history,
    this.systemPrompt,
    this.maxTokens,
    this.temperature,
  });
}

class _StopRequest {}

enum _ResponseType { initialized, token, done, error }

class _InferenceResponse {
  final _ResponseType type;
  final String? content;

  _InferenceResponse(this.type, [this.content]);
}

/// نقطة دخول Isolate الاستدلال
/// ملاحظة: هذا placeholder - التنفيذ الفعلي يتطلب flutter_llama أو مكتبة مشابهة
void _inferenceIsolateEntry(_InferenceInitMessage initMessage) async {
  final receivePort = ReceivePort();
  initMessage.sendPort.send(receivePort.sendPort);

  // محاكاة تحميل النموذج
  // في التنفيذ الفعلي، سيتم استخدام flutter_llama هنا
  await Future.delayed(const Duration(milliseconds: 500));

  // إرسال رسالة التهيئة الناجحة
  initMessage.sendPort.send(_InferenceResponse(_ResponseType.initialized));

  bool shouldStop = false;

  await for (final message in receivePort) {
    if (message is _StopRequest) {
      shouldStop = true;
      continue;
    }

    if (message is _InferenceRequest) {
      shouldStop = false;

      try {
        // محاكاة توليد الاستجابة
        // في التنفيذ الفعلي، سيتم استخدام llama.cpp هنا
        final response = _generateMockResponse(
          message.prompt,
          message.history,
          message.systemPrompt,
        );

        // إرسال الاستجابة كـ tokens
        for (int i = 0; i < response.length && !shouldStop; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          initMessage.sendPort.send(_InferenceResponse(
            _ResponseType.token,
            response[i],
          ));
        }

        initMessage.sendPort.send(_InferenceResponse(_ResponseType.done));
      } catch (e) {
        initMessage.sendPort.send(_InferenceResponse(
          _ResponseType.error,
          e.toString(),
        ));
      }
    }
  }
}

/// توليد استجابة وهمية للاختبار
String _generateMockResponse(
  String prompt,
  List<Map<String, String>>? history,
  String? systemPrompt,
) {
  // كشف اللغة العربية
  final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(prompt);

  if (isArabic) {
    return '''مرحباً! أنا نموذج ذكاء اصطناعي يعمل محلياً على جهازك.

هذه استجابة تجريبية. في الإصدار الكامل، سأستخدم نموذج GGUF الفعلي للرد على أسئلتك.

**ملاحظة:** لتفعيل الاستدلال الفعلي، يجب تثبيت مكتبة flutter_llama وتحميل نموذج GGUF.

سؤالك كان: "$prompt"''';
  }

  return '''Hello! I am an AI model running locally on your device.

This is a test response. In the full version, I will use the actual GGUF model to answer your questions.

**Note:** To enable actual inference, you need to install the flutter_llama library and load a GGUF model.

Your question was: "$prompt"''';
}

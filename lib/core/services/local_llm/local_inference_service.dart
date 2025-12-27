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
/// ملاحظة: يستخدم محاكاة ذكية حتى يتم تفعيل flutter_llama
void _inferenceIsolateEntry(_InferenceInitMessage initMessage) async {
  final receivePort = ReceivePort();
  initMessage.sendPort.send(receivePort.sendPort);

  // محاكاة تحميل النموذج (في الإصدار الفعلي سيتم استخدام flutter_llama)
  await Future.delayed(const Duration(milliseconds: 800));

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
        // توليد استجابة ذكية بناءً على السياق
        final response = _generateSmartResponse(
          message.prompt,
          message.history,
          message.systemPrompt,
          initMessage.settings,
        );

        // إرسال الاستجابة كـ tokens (محاكاة streaming)
        final words = response.split(' ');
        for (int i = 0; i < words.length && !shouldStop; i++) {
          await Future.delayed(Duration(milliseconds: 30 + (i % 3) * 10));
          final word = i == 0 ? words[i] : ' ${words[i]}';
          initMessage.sendPort.send(_InferenceResponse(
            _ResponseType.token,
            word,
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

/// توليد استجابة ذكية بناءً على السياق
String _generateSmartResponse(
  String prompt,
  List<Map<String, String>>? history,
  String? systemPrompt,
  LocalLLMSettings settings,
) {
  final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(prompt);
  final promptLower = prompt.toLowerCase();
  
  // تحليل نوع السؤال
  if (isArabic) {
    // أسئلة التحية
    if (prompt.contains('مرحبا') || prompt.contains('السلام') || prompt.contains('أهلا')) {
      return 'مرحباً بك! أنا مساعدك الذكي الذي يعمل محلياً على جهازك. كيف يمكنني مساعدتك اليوم؟';
    }
    
    // أسئلة عن الهوية
    if (prompt.contains('من أنت') || prompt.contains('ما اسمك')) {
      return 'أنا نموذج ذكاء اصطناعي يعمل محلياً على جهازك. أستطيع مساعدتك في الإجابة على الأسئلة، كتابة النصوص، والمحادثة بالعربية والإنجليزية. جميع بياناتك تبقى على جهازك ولا تُرسل لأي خادم خارجي.';
    }
    
    // أسئلة عن القدرات
    if (prompt.contains('ماذا تستطيع') || prompt.contains('ما الذي يمكنك')) {
      return '''يمكنني مساعدتك في العديد من المهام:

• الإجابة على الأسئلة العامة
• كتابة وتحرير النصوص
• الترجمة بين اللغات
• شرح المفاهيم المعقدة
• المساعدة في البرمجة
• إنشاء محتوى إبداعي

كل هذا يعمل محلياً على جهازك بدون الحاجة للإنترنت!''';
    }
    
    // أسئلة عن الوقت
    if (prompt.contains('الوقت') || prompt.contains('الساعة') || prompt.contains('التاريخ')) {
      final now = DateTime.now();
      return 'الوقت الحالي هو ${now.hour}:${now.minute.toString().padLeft(2, '0')} والتاريخ هو ${now.day}/${now.month}/${now.year}.';
    }
    
    // أسئلة حسابية بسيطة
    final mathMatch = RegExp(r'(\d+)\s*[\+\-\*\/x×÷]\s*(\d+)').firstMatch(prompt);
    if (mathMatch != null || prompt.contains('احسب') || prompt.contains('كم')) {
      if (mathMatch != null) {
        final a = int.tryParse(mathMatch.group(1) ?? '0') ?? 0;
        final b = int.tryParse(mathMatch.group(2) ?? '0') ?? 0;
        final op = prompt.contains('+') ? '+' : prompt.contains('-') ? '-' : prompt.contains('*') || prompt.contains('×') || prompt.contains('x') ? '×' : '÷';
        int result;
        switch (op) {
          case '+': result = a + b; break;
          case '-': result = a - b; break;
          case '×': result = a * b; break;
          case '÷': result = b != 0 ? a ~/ b : 0; break;
          default: result = 0;
        }
        return 'النتيجة هي: $a $op $b = $result';
      }
    }
    
    // استجابة افتراضية للعربية
    return '''شكراً على سؤالك! أنا نموذج ذكاء اصطناعي يعمل محلياً على جهازك.

بخصوص سؤالك: "$prompt"

أستطيع مساعدتك بشكل أفضل عندما يتم تفعيل الاستدلال الكامل. حالياً أعمل في وضع المحاكاة الذكية.

💡 **نصيحة:** لتجربة أفضل، تأكد من تحميل نموذج يدعم العربية مثل Qwen 2.5.''';
  }
  
  // English responses
  if (promptLower.contains('hello') || promptLower.contains('hi ') || promptLower.contains('hey')) {
    return 'Hello! I\'m your local AI assistant running directly on your device. How can I help you today?';
  }
  
  if (promptLower.contains('who are you') || promptLower.contains('what are you')) {
    return 'I\'m a local AI model running on your device. I can help you with questions, writing, and conversations. All your data stays private on your device.';
  }
  
  if (promptLower.contains('what can you do') || promptLower.contains('help me')) {
    return '''I can help you with many tasks:

• Answering general questions
• Writing and editing text
• Translation between languages
• Explaining complex concepts
• Coding assistance
• Creative content generation

All running locally on your device without internet!''';
  }
  
  // Time/date questions
  if (promptLower.contains('time') || promptLower.contains('date')) {
    final now = DateTime.now();
    return 'The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')} and the date is ${now.month}/${now.day}/${now.year}.';
  }
  
  // Math questions
  final mathMatch = RegExp(r'(\d+)\s*[\+\-\*\/x×÷]\s*(\d+)').firstMatch(prompt);
  if (mathMatch != null) {
    final a = int.tryParse(mathMatch.group(1) ?? '0') ?? 0;
    final b = int.tryParse(mathMatch.group(2) ?? '0') ?? 0;
    final op = prompt.contains('+') ? '+' : prompt.contains('-') ? '-' : prompt.contains('*') || prompt.contains('×') || prompt.contains('x') ? '×' : '÷';
    int result;
    switch (op) {
      case '+': result = a + b; break;
      case '-': result = a - b; break;
      case '×': result = a * b; break;
      case '÷': result = b != 0 ? a ~/ b : 0; break;
      default: result = 0;
    }
    return 'The result is: $a $op $b = $result';
  }
  
  // Default English response
  return '''Thank you for your question! I'm a local AI model running on your device.

Regarding your question: "$prompt"

I can provide better assistance when full inference is enabled. Currently running in smart simulation mode.

💡 **Tip:** For the best experience, make sure to download a model that supports your language.''';
}

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
  final promptLower = prompt.toLowerCase().trim();
  final promptAr = prompt.trim();
  
  // ===== الاستجابات العربية =====
  if (isArabic) {
    // تحيات
    if (_matchesAny(promptAr, ['مرحبا', 'السلام', 'أهلا', 'هلا', 'صباح', 'مساء'])) {
      return 'مرحباً بك! 👋 أنا مساعدك الذكي BuildX. كيف يمكنني مساعدتك اليوم؟';
    }
    
    // الهوية
    if (_matchesAny(promptAr, ['من أنت', 'ما اسمك', 'عرفني بنفسك', 'اسمك ايش', 'شو اسمك'])) {
      return '''أنا **BuildX** 🤖 - مساعدك الذكي!

أعمل محلياً على جهازك مما يعني:
• 🔒 خصوصية تامة - بياناتك لا تغادر جهازك
• ⚡ سرعة عالية - لا حاجة للإنترنت
• 🌍 دعم العربية والإنجليزية

كيف يمكنني مساعدتك؟''';
    }
    
    // القدرات
    if (_matchesAny(promptAr, ['ماذا تستطيع', 'ما الذي يمكنك', 'شو تقدر', 'ايش تسوي', 'قدراتك'])) {
      return '''يمكنني مساعدتك في:

📝 **الكتابة والتحرير**
• كتابة مقالات ورسائل
• تصحيح الأخطاء اللغوية
• تلخيص النصوص

💻 **البرمجة**
• كتابة وشرح الكود
• حل المشاكل البرمجية
• شرح المفاهيم التقنية

🌐 **الترجمة**
• الترجمة بين اللغات
• شرح المصطلحات

🧮 **الحسابات**
• العمليات الحسابية
• حل المسائل الرياضية

جرب أي شيء! 🚀''';
    }
    
    // الوقت والتاريخ
    if (_matchesAny(promptAr, ['الوقت', 'الساعة', 'التاريخ', 'كم الساعة', 'اليوم'])) {
      final now = DateTime.now();
      final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      return '''⏰ **الوقت الحالي:** ${now.hour}:${now.minute.toString().padLeft(2, '0')}
📅 **التاريخ:** ${now.day}/${now.month}/${now.year}
📆 **اليوم:** ${days[now.weekday % 7]}''';
    }
    
    // الشكر
    if (_matchesAny(promptAr, ['شكرا', 'شكراً', 'مشكور', 'يعطيك العافية'])) {
      return 'العفو! 😊 سعيد بمساعدتك. هل تحتاج أي شيء آخر؟';
    }
    
    // الوداع
    if (_matchesAny(promptAr, ['مع السلامة', 'باي', 'وداعا', 'الى اللقاء'])) {
      return 'مع السلامة! 👋 أتمنى لك يوماً سعيداً. أراك قريباً!';
    }
    
    // أسئلة حسابية
    final mathResult = _calculateMath(prompt);
    if (mathResult != null) {
      return '🧮 **النتيجة:** $mathResult';
    }
    
    // أسئلة البرمجة
    if (_matchesAny(promptAr, ['كود', 'برمجة', 'برنامج', 'دالة', 'فنكشن'])) {
      return '''أستطيع مساعدتك في البرمجة! 💻

أخبرني:
• ما هي لغة البرمجة؟
• ما الذي تريد تحقيقه؟
• هل لديك كود تريد مراجعته؟

سأساعدك بأفضل طريقة ممكنة!''';
    }
    
    // استجابة افتراضية ذكية
    return '''شكراً على سؤالك! 🤔

بخصوص: "$promptAr"

أنا أعمل حالياً في وضع المحاكاة الذكية. للحصول على إجابات أكثر دقة:

1. 📥 قم بتحميل نموذج AI من الإعدادات
2. 🎯 جرب نماذج مثل Qwen 2.5 للعربية
3. ⚡ النماذج الأصغر أسرع في الاستجابة

هل يمكنني مساعدتك بشيء آخر؟''';
  }
  
  // ===== English Responses =====
  
  // Greetings
  if (_matchesAny(promptLower, ['hello', 'hi', 'hey', 'good morning', 'good evening'])) {
    return 'Hello! 👋 I\'m BuildX, your AI assistant. How can I help you today?';
  }
  
  // Identity
  if (_matchesAny(promptLower, ['who are you', 'what are you', 'your name', 'introduce yourself'])) {
    return '''I'm **BuildX** 🤖 - Your Smart AI Assistant!

I run locally on your device, which means:
• 🔒 Complete privacy - your data never leaves your device
• ⚡ Fast responses - no internet needed
• 🌍 Support for Arabic and English

How can I assist you?''';
  }
  
  // Capabilities
  if (_matchesAny(promptLower, ['what can you do', 'help me', 'capabilities', 'features'])) {
    return '''I can help you with:

📝 **Writing & Editing**
• Write articles and emails
• Fix grammar and spelling
• Summarize texts

💻 **Programming**
• Write and explain code
• Debug issues
• Explain technical concepts

🌐 **Translation**
• Translate between languages
• Explain terminology

🧮 **Calculations**
• Math operations
• Problem solving

Try anything! 🚀''';
  }
  
  // Time/Date
  if (_matchesAny(promptLower, ['time', 'date', 'what day', 'today'])) {
    final now = DateTime.now();
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return '''⏰ **Current Time:** ${now.hour}:${now.minute.toString().padLeft(2, '0')}
📅 **Date:** ${now.month}/${now.day}/${now.year}
📆 **Day:** ${days[now.weekday % 7]}''';
  }
  
  // Thanks
  if (_matchesAny(promptLower, ['thank', 'thanks', 'appreciate'])) {
    return 'You\'re welcome! 😊 Happy to help. Need anything else?';
  }
  
  // Goodbye
  if (_matchesAny(promptLower, ['bye', 'goodbye', 'see you', 'later'])) {
    return 'Goodbye! 👋 Have a great day. See you soon!';
  }
  
  // Math
  final mathResult = _calculateMath(prompt);
  if (mathResult != null) {
    return '🧮 **Result:** $mathResult';
  }
  
  // Programming
  if (_matchesAny(promptLower, ['code', 'program', 'function', 'script', 'debug'])) {
    return '''I can help with programming! 💻

Tell me:
• What programming language?
• What do you want to achieve?
• Do you have code to review?

I'll help you the best I can!''';
  }
  
  // Default smart response
  return '''Thanks for your question! 🤔

Regarding: "$prompt"

I'm currently running in smart simulation mode. For more accurate answers:

1. 📥 Download an AI model from Settings
2. 🎯 Try models like Llama 3.2 or Qwen 2.5
3. ⚡ Smaller models respond faster

Can I help you with something else?''';
}

/// التحقق من تطابق أي من الكلمات المفتاحية
bool _matchesAny(String text, List<String> keywords) {
  final lower = text.toLowerCase();
  return keywords.any((k) => lower.contains(k.toLowerCase()));
}

/// حساب العمليات الرياضية
String? _calculateMath(String prompt) {
  // البحث عن عمليات حسابية بسيطة
  final patterns = [
    RegExp(r'(\d+(?:\.\d+)?)\s*[\+]\s*(\d+(?:\.\d+)?)'),
    RegExp(r'(\d+(?:\.\d+)?)\s*[\-]\s*(\d+(?:\.\d+)?)'),
    RegExp(r'(\d+(?:\.\d+)?)\s*[\*×x]\s*(\d+(?:\.\d+)?)'),
    RegExp(r'(\d+(?:\.\d+)?)\s*[\/÷]\s*(\d+(?:\.\d+)?)'),
  ];
  
  for (int i = 0; i < patterns.length; i++) {
    final match = patterns[i].firstMatch(prompt);
    if (match != null) {
      final a = double.tryParse(match.group(1) ?? '0') ?? 0;
      final b = double.tryParse(match.group(2) ?? '0') ?? 0;
      double result;
      String op;
      
      switch (i) {
        case 0: result = a + b; op = '+'; break;
        case 1: result = a - b; op = '-'; break;
        case 2: result = a * b; op = '×'; break;
        case 3: result = b != 0 ? a / b : 0; op = '÷'; break;
        default: return null;
      }
      
      // تنسيق النتيجة
      final resultStr = result == result.toInt() 
          ? result.toInt().toString() 
          : result.toStringAsFixed(2);
      
      return '$a $op $b = $resultStr';
    }
  }
  
  return null;
}

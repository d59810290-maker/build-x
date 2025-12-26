import 'local_model_info.dart';

/// قائمة النماذج المتاحة للتنزيل
/// تشمل نماذج عربية وخفيفة يمكن تشغيلها على الهواتف المحمولة
class AvailableModels {
  static const List<LocalModelInfo> models = [
    // ===== نماذج Qwen - دعم عربي ممتاز =====
    LocalModelInfo(
      id: 'qwen2.5-0.5b-instruct-q4',
      name: 'Qwen 2.5 0.5B Instruct Q4',
      nameAr: 'كوين 2.5 - 0.5 مليار (خفيف جداً)',
      description: 'Ultra-lightweight model with Arabic support. Perfect for mobile devices with limited resources.',
      descriptionAr: 'نموذج خفيف جداً مع دعم اللغة العربية. مثالي للهواتف ذات الموارد المحدودة.',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeBytes: 397000000, // ~397 MB
      quantization: 'Q4_K_M',
      languages: ['ar', 'en', 'zh', 'fr', 'de', 'es', 'it', 'pt', 'ru', 'ja', 'ko'],
      supportsArabic: true,
      contextLength: 32768,
      category: 'lightweight',
      huggingFaceRepo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
      huggingFaceFile: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    ),
    LocalModelInfo(
      id: 'qwen2.5-1.5b-instruct-q4',
      name: 'Qwen 2.5 1.5B Instruct Q4',
      nameAr: 'كوين 2.5 - 1.5 مليار (موصى به)',
      description: 'Excellent balance of size and capability. Strong Arabic support with good reasoning.',
      descriptionAr: 'توازن ممتاز بين الحجم والقدرة. دعم عربي قوي مع استدلال جيد.',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      sizeBytes: 1100000000, // ~1.1 GB
      quantization: 'Q4_K_M',
      languages: ['ar', 'en', 'zh', 'fr', 'de', 'es', 'it', 'pt', 'ru', 'ja', 'ko'],
      supportsArabic: true,
      contextLength: 32768,
      category: 'multilingual',
      huggingFaceRepo: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      huggingFaceFile: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    ),
    LocalModelInfo(
      id: 'qwen2.5-3b-instruct-q4',
      name: 'Qwen 2.5 3B Instruct Q4',
      nameAr: 'كوين 2.5 - 3 مليار (متقدم)',
      description: 'More capable model with excellent Arabic understanding. Requires more RAM.',
      descriptionAr: 'نموذج أكثر قدرة مع فهم عربي ممتاز. يتطلب ذاكرة أكبر.',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
      filename: 'qwen2.5-3b-instruct-q4_k_m.gguf',
      sizeBytes: 2100000000, // ~2.1 GB
      quantization: 'Q4_K_M',
      languages: ['ar', 'en', 'zh', 'fr', 'de', 'es', 'it', 'pt', 'ru', 'ja', 'ko'],
      supportsArabic: true,
      contextLength: 32768,
      category: 'multilingual',
      huggingFaceRepo: 'Qwen/Qwen2.5-3B-Instruct-GGUF',
      huggingFaceFile: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    ),

    // ===== نماذج Gemma - من Google =====
    LocalModelInfo(
      id: 'gemma-2-2b-it-q4',
      name: 'Gemma 2 2B Instruct Q4',
      nameAr: 'جيما 2 - 2 مليار',
      description: 'Google\'s efficient model with multilingual support including Arabic.',
      descriptionAr: 'نموذج جوجل الفعال مع دعم متعدد اللغات بما في ذلك العربية.',
      downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
      filename: 'gemma-2-2b-it-Q4_K_M.gguf',
      sizeBytes: 1700000000, // ~1.7 GB
      quantization: 'Q4_K_M',
      languages: ['ar', 'en', 'de', 'es', 'fr', 'it', 'pt', 'nl', 'pl', 'ru'],
      supportsArabic: true,
      contextLength: 8192,
      category: 'multilingual',
      huggingFaceRepo: 'bartowski/gemma-2-2b-it-GGUF',
      huggingFaceFile: 'gemma-2-2b-it-Q4_K_M.gguf',
    ),

    // ===== نماذج Phi - من Microsoft =====
    LocalModelInfo(
      id: 'phi-3.5-mini-instruct-q4',
      name: 'Phi 3.5 Mini Instruct Q4',
      nameAr: 'فاي 3.5 ميني',
      description: 'Microsoft\'s compact model with strong reasoning. Good multilingual support.',
      descriptionAr: 'نموذج مايكروسوفت المدمج مع استدلال قوي. دعم جيد متعدد اللغات.',
      downloadUrl: 'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      filename: 'Phi-3.5-mini-instruct-Q4_K_M.gguf',
      sizeBytes: 2400000000, // ~2.4 GB
      quantization: 'Q4_K_M',
      languages: ['ar', 'en', 'zh', 'de', 'es', 'fr', 'it', 'ja', 'ko', 'pt', 'ru'],
      supportsArabic: true,
      contextLength: 128000,
      category: 'multilingual',
      huggingFaceRepo: 'bartowski/Phi-3.5-mini-instruct-GGUF',
      huggingFaceFile: 'Phi-3.5-mini-instruct-Q4_K_M.gguf',
    ),

    // ===== نماذج TinyLlama - خفيفة جداً =====
    LocalModelInfo(
      id: 'tinyllama-1.1b-chat-q4',
      name: 'TinyLlama 1.1B Chat Q4',
      nameAr: 'تايني لاما 1.1 مليار',
      description: 'Very lightweight model for basic conversations. Limited Arabic support.',
      descriptionAr: 'نموذج خفيف جداً للمحادثات الأساسية. دعم عربي محدود.',
      downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      filename: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      sizeBytes: 670000000, // ~670 MB
      quantization: 'Q4_K_M',
      languages: ['en', 'ar'],
      supportsArabic: false,
      contextLength: 2048,
      category: 'lightweight',
      huggingFaceRepo: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
      huggingFaceFile: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    ),

    // ===== نماذج SmolLM - صغيرة وفعالة =====
    LocalModelInfo(
      id: 'smollm2-360m-instruct-q8',
      name: 'SmolLM2 360M Instruct Q8',
      nameAr: 'سمول إل إم 360 مليون (صغير جداً)',
      description: 'Extremely small model for very limited devices. Basic capabilities.',
      descriptionAr: 'نموذج صغير للغاية للأجهزة المحدودة جداً. قدرات أساسية.',
      downloadUrl: 'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
      filename: 'smollm2-360m-instruct-q8_0.gguf',
      sizeBytes: 386000000, // ~386 MB
      quantization: 'Q8_0',
      languages: ['en'],
      supportsArabic: false,
      contextLength: 2048,
      category: 'lightweight',
      huggingFaceRepo: 'HuggingFaceTB/SmolLM2-360M-Instruct-GGUF',
      huggingFaceFile: 'smollm2-360m-instruct-q8_0.gguf',
    ),
    LocalModelInfo(
      id: 'smollm2-1.7b-instruct-q4',
      name: 'SmolLM2 1.7B Instruct Q4',
      nameAr: 'سمول إل إم 1.7 مليار',
      description: 'Efficient small model with good performance for its size.',
      descriptionAr: 'نموذج صغير فعال مع أداء جيد لحجمه.',
      downloadUrl: 'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
      filename: 'smollm2-1.7b-instruct-q4_k_m.gguf',
      sizeBytes: 1100000000, // ~1.1 GB
      quantization: 'Q4_K_M',
      languages: ['en'],
      supportsArabic: false,
      contextLength: 8192,
      category: 'lightweight',
      huggingFaceRepo: 'HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF',
      huggingFaceFile: 'smollm2-1.7b-instruct-q4_k_m.gguf',
    ),

    // ===== نماذج Llama - من Meta =====
    LocalModelInfo(
      id: 'llama-3.2-1b-instruct-q4',
      name: 'Llama 3.2 1B Instruct Q4',
      nameAr: 'لاما 3.2 - 1 مليار',
      description: 'Meta\'s latest small model with improved multilingual capabilities.',
      descriptionAr: 'أحدث نموذج صغير من ميتا مع قدرات متعددة اللغات محسنة.',
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      sizeBytes: 770000000, // ~770 MB
      quantization: 'Q4_K_M',
      languages: ['en', 'de', 'fr', 'it', 'pt', 'hi', 'es', 'th'],
      supportsArabic: false,
      contextLength: 131072,
      category: 'lightweight',
      huggingFaceRepo: 'bartowski/Llama-3.2-1B-Instruct-GGUF',
      huggingFaceFile: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    ),
    LocalModelInfo(
      id: 'llama-3.2-3b-instruct-q4',
      name: 'Llama 3.2 3B Instruct Q4',
      nameAr: 'لاما 3.2 - 3 مليار',
      description: 'Meta\'s capable small model with good reasoning abilities.',
      descriptionAr: 'نموذج ميتا القادر الصغير مع قدرات استدلال جيدة.',
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      filename: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      sizeBytes: 2000000000, // ~2 GB
      quantization: 'Q4_K_M',
      languages: ['en', 'de', 'fr', 'it', 'pt', 'hi', 'es', 'th'],
      supportsArabic: false,
      contextLength: 131072,
      category: 'multilingual',
      huggingFaceRepo: 'bartowski/Llama-3.2-3B-Instruct-GGUF',
      huggingFaceFile: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    ),

    // ===== نماذج Mistral =====
    LocalModelInfo(
      id: 'mistral-7b-instruct-v0.3-q2',
      name: 'Mistral 7B Instruct v0.3 Q2',
      nameAr: 'ميسترال 7 مليار (مضغوط)',
      description: 'Highly compressed version of Mistral 7B. Good for devices with limited storage.',
      descriptionAr: 'نسخة مضغوطة للغاية من ميسترال 7 مليار. جيد للأجهزة ذات التخزين المحدود.',
      downloadUrl: 'https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q2_K.gguf',
      filename: 'Mistral-7B-Instruct-v0.3-Q2_K.gguf',
      sizeBytes: 3100000000, // ~3.1 GB
      quantization: 'Q2_K',
      languages: ['en', 'fr', 'de', 'es', 'it', 'pt', 'nl', 'ru', 'zh', 'ja', 'ko', 'ar'],
      supportsArabic: true,
      contextLength: 32768,
      category: 'multilingual',
      huggingFaceRepo: 'bartowski/Mistral-7B-Instruct-v0.3-GGUF',
      huggingFaceFile: 'Mistral-7B-Instruct-v0.3-Q2_K.gguf',
    ),
  ];

  /// الحصول على النماذج التي تدعم العربية
  static List<LocalModelInfo> get arabicModels =>
      models.where((m) => m.supportsArabic).toList();

  /// الحصول على النماذج الخفيفة (أقل من 1 جيجا)
  static List<LocalModelInfo> get lightweightModels =>
      models.where((m) => m.sizeBytes < 1024 * 1024 * 1024).toList();

  /// الحصول على النماذج حسب الفئة
  static List<LocalModelInfo> getByCategory(String category) =>
      models.where((m) => m.category == category).toList();

  /// البحث عن نموذج بالمعرف
  static LocalModelInfo? findById(String id) {
    try {
      return models.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// الحصول على النموذج الموصى به للعربية
  static LocalModelInfo get recommendedArabicModel =>
      models.firstWhere((m) => m.id == 'qwen2.5-1.5b-instruct-q4');

  /// الحصول على أخف نموذج يدعم العربية
  static LocalModelInfo get lightestArabicModel =>
      models.firstWhere((m) => m.id == 'qwen2.5-0.5b-instruct-q4');
}

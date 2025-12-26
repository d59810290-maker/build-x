/// معلومات النموذج المحلي
class LocalModelInfo {
  final String id;
  final String name;
  final String nameAr;
  final String description;
  final String descriptionAr;
  final String downloadUrl;
  final String filename;
  final int sizeBytes;
  final String quantization;
  final List<String> languages;
  final bool supportsArabic;
  final int contextLength;
  final String category; // 'arabic', 'multilingual', 'lightweight'
  final String? huggingFaceRepo;
  final String? huggingFaceFile;

  const LocalModelInfo({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.descriptionAr,
    required this.downloadUrl,
    required this.filename,
    required this.sizeBytes,
    required this.quantization,
    required this.languages,
    required this.supportsArabic,
    required this.contextLength,
    required this.category,
    this.huggingFaceRepo,
    this.huggingFaceFile,
  });

  String get sizeMB => (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
  String get sizeGB => (sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

  String get displaySize {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '$sizeGB GB';
    }
    return '$sizeMB MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameAr': nameAr,
        'description': description,
        'descriptionAr': descriptionAr,
        'downloadUrl': downloadUrl,
        'filename': filename,
        'sizeBytes': sizeBytes,
        'quantization': quantization,
        'languages': languages,
        'supportsArabic': supportsArabic,
        'contextLength': contextLength,
        'category': category,
        'huggingFaceRepo': huggingFaceRepo,
        'huggingFaceFile': huggingFaceFile,
      };

  factory LocalModelInfo.fromJson(Map<String, dynamic> json) => LocalModelInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        nameAr: json['nameAr'] as String? ?? json['name'] as String,
        description: json['description'] as String,
        descriptionAr: json['descriptionAr'] as String? ?? json['description'] as String,
        downloadUrl: json['downloadUrl'] as String,
        filename: json['filename'] as String,
        sizeBytes: json['sizeBytes'] as int,
        quantization: json['quantization'] as String,
        languages: (json['languages'] as List<dynamic>).cast<String>(),
        supportsArabic: json['supportsArabic'] as bool,
        contextLength: json['contextLength'] as int,
        category: json['category'] as String,
        huggingFaceRepo: json['huggingFaceRepo'] as String?,
        huggingFaceFile: json['huggingFaceFile'] as String?,
      );
}

/// حالة النموذج المحلي المحمل
enum LocalModelStatus {
  notDownloaded,
  downloading,
  downloaded,
  loading,
  loaded,
  error,
}

/// النموذج المحلي المحمل
class DownloadedModel {
  final LocalModelInfo info;
  final String localPath;
  final DateTime downloadedAt;
  LocalModelStatus status;
  double downloadProgress;
  String? errorMessage;

  DownloadedModel({
    required this.info,
    required this.localPath,
    required this.downloadedAt,
    this.status = LocalModelStatus.downloaded,
    this.downloadProgress = 1.0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'info': info.toJson(),
        'localPath': localPath,
        'downloadedAt': downloadedAt.toIso8601String(),
        'status': status.index,
      };

  factory DownloadedModel.fromJson(Map<String, dynamic> json) => DownloadedModel(
        info: LocalModelInfo.fromJson(json['info'] as Map<String, dynamic>),
        localPath: json['localPath'] as String,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        status: LocalModelStatus.values[json['status'] as int? ?? 2],
      );
}

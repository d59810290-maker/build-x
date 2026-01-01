import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/services/local_llm/local_model_info.dart';

/// بطاقة عرض النموذج
class ModelCard extends StatelessWidget {
  final LocalModelInfo model;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isSelected;
  final bool isLoaded;
  final double downloadProgress;
  final String downloadStatus;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onSelect;
  final VoidCallback onLoad;
  final VoidCallback onUnload;
  final VoidCallback? onCancelDownload;

  const ModelCard({
    super.key,
    required this.model,
    required this.isDownloaded,
    required this.isDownloading,
    required this.isSelected,
    required this.isLoaded,
    required this.downloadProgress,
    this.downloadStatus = '',
    required this.onDownload,
    required this.onDelete,
    required this.onSelect,
    required this.onLoad,
    required this.onUnload,
    this.onCancelDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLoaded
              ? colorScheme.primary
              : isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.outlineVariant,
          width: isLoaded ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isDownloaded ? onSelect : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف العلوي: الأيقونة والاسم والحالة
              Row(
                children: [
                  // أيقونة النموذج
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(colorScheme).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(),
                      color: _getCategoryColor(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // الاسم والوصف
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.nameAr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          model.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // شارات الحالة
                  _buildStatusBadges(context),
                ],
              ),

              const SizedBox(height: 12),

              // الوصف
              Text(
                model.descriptionAr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // معلومات النموذج
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    context,
                    icon: LucideIcons.hardDrive,
                    label: model.displaySize,
                  ),
                  _buildInfoChip(
                    context,
                    icon: LucideIcons.cpu,
                    label: model.quantization,
                  ),
                  _buildInfoChip(
                    context,
                    icon: LucideIcons.messageSquare,
                    label: '${model.contextLength ~/ 1024}K',
                  ),
                  if (model.supportsArabic)
                    _buildInfoChip(
                      context,
                      icon: LucideIcons.languages,
                      label: 'عربي',
                      isHighlighted: true,
                    ),
                ],
              ),

              // شريط التقدم أثناء التحميل
              if (isDownloading) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: downloadProgress > 0 ? downloadProgress : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    downloadStatus.isNotEmpty ? downloadStatus : 'جاري التنزيل...',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(downloadProgress * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: downloadProgress > 0 ? downloadProgress : null,
                          minHeight: 10,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatBytes((downloadProgress * model.sizeBytes).toInt()),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                          Text(
                            'من ${model.displaySize}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // أزرار الإجراءات
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isDownloaded) ...[
                    // زر الحذف
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(LucideIcons.trash2),
                      tooltip: 'حذف',
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // زر التحميل/الإيقاف
                    if (isLoaded)
                      FilledButton.tonalIcon(
                        onPressed: onUnload,
                        icon: const Icon(LucideIcons.power),
                        label: const Text('إيقاف'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.errorContainer,
                          foregroundColor: colorScheme.onErrorContainer,
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: onLoad,
                        icon: const Icon(LucideIcons.play),
                        label: const Text('تشغيل'),
                      ),
                  ] else if (isDownloading) ...[
                    // زر الإلغاء
                    OutlinedButton.icon(
                      onPressed: onCancelDownload,
                      icon: const Icon(LucideIcons.x),
                      label: const Text('إلغاء'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                    ),
                  ] else ...[
                    // زر التنزيل
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(LucideIcons.download),
                      label: const Text('تنزيل'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadges(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoaded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.zap, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'نشط',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          )
        else if (isDownloaded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.check, size: 12, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(
                  'محمل',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isHighlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isHighlighted
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isHighlighted
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (model.category) {
      case 'arabic':
        return LucideIcons.languages;
      case 'lightweight':
        return LucideIcons.feather;
      case 'multilingual':
        return LucideIcons.globe;
      default:
        return LucideIcons.brain;
    }
  }

  Color _getCategoryColor(ColorScheme colorScheme) {
    switch (model.category) {
      case 'arabic':
        return Colors.green;
      case 'lightweight':
        return Colors.orange;
      case 'multilingual':
        return colorScheme.primary;
      default:
        return colorScheme.secondary;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

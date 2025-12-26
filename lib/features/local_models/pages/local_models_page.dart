import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/local_model_provider.dart';
import '../../../core/services/local_llm/local_model_info.dart';
import '../widgets/model_card.dart';
import '../widgets/model_filter_chips.dart';
import 'local_model_settings_page.dart';

/// صفحة إدارة النماذج المحلية
class LocalModelsPage extends StatefulWidget {
  const LocalModelsPage({super.key});

  @override
  State<LocalModelsPage> createState() => _LocalModelsPageState();
}

class _LocalModelsPageState extends State<LocalModelsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalModelProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النماذج المحلية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LocalModelSettingsPage(),
                ),
              );
            },
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: Consumer<LocalModelProvider>(
        builder: (context, provider, _) {
          if (!provider.initialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              // شريط البحث
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'البحث عن نموذج...',
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
              ),

              // فلاتر الفئات
              const ModelFilterChips(),

              // معلومات النموذج المحمل
              if (provider.isModelLoaded && provider.selectedModel != null)
                _buildLoadedModelInfo(context, provider),

              // قائمة النماذج
              Expanded(
                child: _buildModelsList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadedModelInfo(BuildContext context, LocalModelProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final model = provider.selectedModel!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.brain,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'النموذج النشط',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
                Text(
                  model.info.nameAr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (provider.isGenerating)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.power),
              onPressed: () => provider.unloadModel(),
              tooltip: 'إيقاف النموذج',
              color: colorScheme.onPrimaryContainer,
            ),
        ],
      ),
    );
  }

  Widget _buildModelsList(BuildContext context, LocalModelProvider provider) {
    final models = provider.filteredModels;

    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نماذج مطابقة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: provider.clearFilters,
              child: const Text('مسح الفلاتر'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return ModelCard(
          model: model,
          isDownloaded: provider.isModelDownloaded(model.id),
          isDownloading: provider.isModelDownloading(model.id),
          isSelected: provider.selectedModelId == model.id,
          isLoaded: provider.loadedModelId == model.id,
          downloadProgress: provider.getDownloadProgress(model.id),
          onDownload: () => _downloadModel(context, provider, model),
          onDelete: () => _deleteModel(context, provider, model),
          onSelect: () => provider.selectModel(model.id),
          onLoad: () => _loadModel(context, provider, model),
          onUnload: () => provider.unloadModel(),
        );
      },
    );
  }

  Future<void> _downloadModel(
    BuildContext context,
    LocalModelProvider provider,
    LocalModelInfo model,
  ) async {
    try {
      await provider.downloadModel(model.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحميل ${model.nameAr} بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل النموذج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteModel(
    BuildContext context,
    LocalModelProvider provider,
    LocalModelInfo model,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف النموذج'),
        content: Text('هل تريد حذف ${model.nameAr}؟\nسيتم حذف الملف من الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteModel(model.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف ${model.nameAr}'),
          ),
        );
      }
    }
  }

  Future<void> _loadModel(
    BuildContext context,
    LocalModelProvider provider,
    LocalModelInfo model,
  ) async {
    final success = await provider.loadModel(model.id);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحميل ${model.nameAr} في الذاكرة'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل تحميل النموذج في الذاكرة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

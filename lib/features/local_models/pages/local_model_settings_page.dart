import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/local_model_provider.dart';
import '../../../core/services/local_llm/local_llm_service.dart';

/// صفحة إعدادات النماذج المحلية
class LocalModelSettingsPage extends StatefulWidget {
  const LocalModelSettingsPage({super.key});

  @override
  State<LocalModelSettingsPage> createState() => _LocalModelSettingsPageState();
}

class _LocalModelSettingsPageState extends State<LocalModelSettingsPage> {
  late LocalLLMSettings _settings;
  bool _hasChanges = false;

  final _systemPromptController = TextEditingController();
  final _systemPromptArController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<LocalModelProvider>();
    _settings = provider.settings;
    _systemPromptController.text = _settings.systemPrompt;
    _systemPromptArController.text = _settings.systemPromptAr;
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _systemPromptArController.dispose();
    super.dispose();
  }

  void _updateSettings(LocalLLMSettings newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    final provider = context.read<LocalModelProvider>();
    await provider.updateSettings(_settings);
    setState(() {
      _hasChanges = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإعدادات'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النموذج المحلي'),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(LucideIcons.save),
              label: const Text('حفظ'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم الأداء
          _buildSectionHeader(context, 'الأداء', LucideIcons.gauge),
          const SizedBox(height: 8),
          _buildCard(
            context,
            children: [
              _buildSliderTile(
                context,
                title: 'طول السياق',
                subtitle: 'عدد الرموز في السياق',
                value: _settings.contextLength.toDouble(),
                min: 512,
                max: 8192,
                divisions: 15,
                valueLabel: '${_settings.contextLength}',
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(contextLength: value.toInt()));
                },
              ),
              const Divider(),
              _buildSliderTile(
                context,
                title: 'الحد الأقصى للرموز',
                subtitle: 'أقصى عدد رموز في الاستجابة',
                value: _settings.maxTokens.toDouble(),
                min: 64,
                max: 2048,
                divisions: 31,
                valueLabel: '${_settings.maxTokens}',
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(maxTokens: value.toInt()));
                },
              ),
              const Divider(),
              _buildSliderTile(
                context,
                title: 'عدد الخيوط',
                subtitle: 'خيوط المعالج المستخدمة',
                value: _settings.threads.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                valueLabel: '${_settings.threads}',
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(threads: value.toInt()));
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('استخدام GPU'),
                subtitle: const Text('تسريع باستخدام معالج الرسومات'),
                value: _settings.useGpu,
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(useGpu: value));
                },
              ),
              if (_settings.useGpu) ...[
                const Divider(),
                _buildSliderTile(
                  context,
                  title: 'طبقات GPU',
                  subtitle: 'عدد الطبقات على GPU (0 = تلقائي)',
                  value: _settings.gpuLayers.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  valueLabel: '${_settings.gpuLayers}',
                  onChanged: (value) {
                    _updateSettings(_settings.copyWith(gpuLayers: value.toInt()));
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // قسم التوليد
          _buildSectionHeader(context, 'التوليد', LucideIcons.sparkles),
          const SizedBox(height: 8),
          _buildCard(
            context,
            children: [
              _buildSliderTile(
                context,
                title: 'درجة الحرارة',
                subtitle: 'التحكم في عشوائية الاستجابة',
                value: _settings.temperature,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                valueLabel: _settings.temperature.toStringAsFixed(1),
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(temperature: value));
                },
              ),
              const Divider(),
              _buildSliderTile(
                context,
                title: 'Top P',
                subtitle: 'احتمالية تراكمية للرموز',
                value: _settings.topP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                valueLabel: _settings.topP.toStringAsFixed(2),
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(topP: value));
                },
              ),
              const Divider(),
              _buildSliderTile(
                context,
                title: 'Top K',
                subtitle: 'عدد الرموز المرشحة',
                value: _settings.topK.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                valueLabel: '${_settings.topK}',
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(topK: value.toInt()));
                },
              ),
              const Divider(),
              _buildSliderTile(
                context,
                title: 'عقوبة التكرار',
                subtitle: 'تقليل تكرار الكلمات',
                value: _settings.repeatPenalty,
                min: 1.0,
                max: 2.0,
                divisions: 20,
                valueLabel: _settings.repeatPenalty.toStringAsFixed(2),
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(repeatPenalty: value));
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // قسم System Prompt
          _buildSectionHeader(context, 'رسالة النظام', LucideIcons.messageSquare),
          const SizedBox(height: 8),
          _buildCard(
            context,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رسالة النظام (إنجليزي)',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _systemPromptController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'You are a helpful AI assistant.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        _updateSettings(_settings.copyWith(systemPrompt: value));
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'رسالة النظام (عربي)',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _systemPromptArController,
                      maxLines: 3,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'أنت مساعد ذكاء اصطناعي مفيد.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        _updateSettings(_settings.copyWith(systemPromptAr: value));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // قسم التخزين
          _buildSectionHeader(context, 'التخزين', LucideIcons.hardDrive),
          const SizedBox(height: 8),
          _buildCard(
            context,
            children: [
              FutureBuilder<int>(
                future: context.read<LocalModelProvider>().getUsedStorage(),
                builder: (context, snapshot) {
                  final usedBytes = snapshot.data ?? 0;
                  final usedGB = (usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
                  return ListTile(
                    leading: const Icon(LucideIcons.database),
                    title: const Text('المساحة المستخدمة'),
                    subtitle: Text('$usedGB GB'),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: const Text('تنظيف الملفات غير المستخدمة'),
                subtitle: const Text('حذف ملفات النماذج المعطوبة'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () async {
                  await context.read<LocalModelProvider>().cleanupUnusedModels();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم التنظيف'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // إعادة تعيين الإعدادات
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _settings = const LocalLLMSettings();
                  _systemPromptController.text = _settings.systemPrompt;
                  _systemPromptArController.text = _settings.systemPromptAr;
                  _hasChanges = true;
                });
              },
              icon: const Icon(LucideIcons.rotateCcw),
              label: const Text('إعادة تعيين الإعدادات'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

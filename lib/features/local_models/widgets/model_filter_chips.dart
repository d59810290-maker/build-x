import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/local_model_provider.dart';

/// شرائح فلترة النماذج
class ModelFilterChips extends StatelessWidget {
  const ModelFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<LocalModelProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: 'الكل',
                icon: LucideIcons.layoutGrid,
                isSelected: provider.categoryFilter == 'all',
                onSelected: () => provider.setCategoryFilter('all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'يدعم العربية',
                icon: LucideIcons.languages,
                isSelected: provider.categoryFilter == 'arabic',
                onSelected: () => provider.setCategoryFilter('arabic'),
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'خفيف',
                icon: LucideIcons.feather,
                isSelected: provider.categoryFilter == 'lightweight',
                onSelected: () => provider.setCategoryFilter('lightweight'),
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'متعدد اللغات',
                icon: LucideIcons.globe,
                isSelected: provider.categoryFilter == 'multilingual',
                onSelected: () => provider.setCategoryFilter('multilingual'),
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'المحملة فقط',
                icon: LucideIcons.download,
                isSelected: provider.showOnlyDownloaded,
                onSelected: () => provider.setShowOnlyDownloaded(!provider.showOnlyDownloaded),
                color: colorScheme.secondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipColor = color ?? colorScheme.primary;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? colorScheme.onPrimary : chipColor,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: chipColor,
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : colorScheme.outline,
      ),
    );
  }
}

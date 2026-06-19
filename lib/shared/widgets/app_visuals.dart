import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 24,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: iconSize, color: filled ? Colors.white : color),
    );
  }
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: filled ? Colors.white : color),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: filled ? Colors.white : AppColors.ink),
      ),
      side: BorderSide(color: filled ? color : color.withValues(alpha: 0.22)),
      backgroundColor: filled ? color : color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            AppIconBadge(icon: icon, color: AppColors.mutedInk, size: 52),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

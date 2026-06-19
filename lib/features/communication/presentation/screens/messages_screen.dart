import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_visuals.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Messages',
      body: SingleChildScrollView(
        padding: ResponsiveLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                AppAnimatedEntry(child: _MessagesHeader()),
                SizedBox(height: 14),
                AppAnimatedEntry(
                  index: 1,
                  child: AppEmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No conversations yet.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const AppIconBadge(
              icon: Icons.forum_outlined,
              color: AppColors.fieldBlue,
              size: 50,
              filled: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Project chats and team conversations.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

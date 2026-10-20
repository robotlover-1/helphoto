import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';

/// 紧凑的建议卡片：摘要 + 两行解释，点击查看完整说明。
class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(suggestionProvider);
    if (s == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showFullText(context, s.summary, s.explanation),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.summary,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.explanation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullText(BuildContext context, String summary, String explanation) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(explanation),
          ],
        ),
      ),
    );
  }
}

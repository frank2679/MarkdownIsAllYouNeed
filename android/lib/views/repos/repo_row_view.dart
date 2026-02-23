import 'package:flutter/material.dart';
import '../../models/repository.dart';

class RepoRowView extends StatelessWidget {
  final Repository repo;
  final bool isCloned;

  const RepoRowView({super.key, required this.repo, required this.isCloned});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Cloned indicator
          if (isCloned)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        repo.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (repo.isPrivate) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                    if (repo.fork) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.fork_right,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  repo.owner.login,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (repo.description != null && repo.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    repo.description!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (repo.stargazersCount > 0) ...[
            Icon(
              Icons.star_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              '${repo.stargazersCount}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

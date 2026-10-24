import 'package:flutter/material.dart';

import '../api.dart';

/// Centered icon, title, message and an optional action. Used for empty,
/// error and offline states so they all look the same.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Offline and server errors get different copy; both offer a retry.
  factory StatusView.error(Object error, {required VoidCallback onRetry}) => error is OfflineException
      ? StatusView(
          icon: Icons.wifi_off_rounded,
          title: "You're offline",
          message: 'Check your connection and try again. Saved recipes and your shopping list still work.',
          actionLabel: 'Try again',
          onAction: onRetry,
        )
      : StatusView(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          message: error is ApiException ? error.message : 'Could not load recipes.',
          actionLabel: 'Try again',
          onAction: onRetry,
        );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: t.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message,
                style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

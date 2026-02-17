import 'package:flutter/material.dart';

/// Theme-aware empty state with optional animation and action.
/// Use for feed, lists, search results, etc.
class EmptyState extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool animate;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
    this.animate = true,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);
    final titleColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);
    final messageColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    Widget content = Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 80, color: iconColor),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            style: theme.textTheme.bodyMedium?.copyWith(color: messageColor),
            textAlign: TextAlign.center,
          ),
          if (widget.onAction != null && widget.actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.onAction,
              icon: const Icon(Icons.add, size: 20),
              label: Text(widget.actionLabel!),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.animate) {
      content = FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: _scale, child: content),
      );
    }

    return Center(child: content);
  }
}

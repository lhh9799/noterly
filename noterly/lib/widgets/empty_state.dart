import 'package:flutter/material.dart';
import 'package:noterly/theme/app_theme.dart';

/// A large, friendly placeholder for an empty list.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyState({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: AppTheme.motionMedium,
              curve: AppTheme.springBouncyCurve,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 112,
                height: 112,
                decoration: ShapeDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(44)),
                ),
                child: Icon(icon, size: 52, color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

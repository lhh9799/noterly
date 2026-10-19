import 'package:flutter/material.dart';
import 'package:noterly/theme/app_theme.dart';

/// A Material 3 Expressive segmented list group: each item sits in its own container, separated by a small gap,
/// with large corners on the outside of the group and small corners between items.
class ExpressiveListGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  static const double gap = 2;
  static const Radius outerRadius = Radius.circular(AppTheme.radiusExtraLarge - 4);
  static const Radius innerRadius = Radius.circular(4);

  const ExpressiveListGroup({required this.children, this.margin = const EdgeInsets.symmetric(horizontal: 16), super.key});

  /// The corners for the item at [index] in a group of [count] items.
  static BorderRadius radiusFor(int index, int count) =>
      BorderRadius.vertical(top: index == 0 ? outerRadius : innerRadius, bottom: index == count - 1 ? outerRadius : innerRadius);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        children: [for (var i = 0; i < children.length; i++) ExpressiveListItem(index: i, count: children.length, child: children[i])],
      ),
    );
  }
}

/// One item of an [ExpressiveListGroup], for lists that build their items lazily.
class ExpressiveListItem extends StatelessWidget {
  final int index;
  final int count;
  final Widget child;

  const ExpressiveListItem({required this.index, required this.count, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: index > 0 ? ExpressiveListGroup.gap : 0),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: ExpressiveListGroup.radiusFor(index, count)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// The heading above an [ExpressiveListGroup].
class ExpressiveSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ExpressiveSectionHeader(this.title, {this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.primary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// The reminder's colour, shown as a dot inside a soft rounded-square container beside it.
class ExpressiveColourBadge extends StatelessWidget {
  final Color colour;
  final double size;

  const ExpressiveColourBadge({required this.colour, this.size = 40, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Tint the colour towards the surface so it reads as a soft container, with a solid dot in the middle.
    final container = Color.alphaBlend(colour.withValues(alpha: 0.22), scheme.surfaceContainerHighest);

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: container,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(size * 0.36)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.4,
        height: size * 0.4,
        decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
      ),
    );
  }
}

/// The background revealed behind a list item while it is swiped away.
class ExpressiveDismissBackground extends StatelessWidget {
  final IconData icon;
  final bool isSecondary;

  const ExpressiveDismissBackground({required this.icon, this.isSecondary = false, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.tertiaryContainer,
      alignment: isSecondary ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: scheme.onTertiaryContainer),
    );
  }
}

/// The title block at the top of the app's picker dialogs.
class ExpressiveDialogHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;

  const ExpressiveDialogHeader({required this.title, this.icon, this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, color: theme.colorScheme.secondary, size: 28), const SizedBox(height: 16)],
          Text(title, style: theme.textTheme.headlineSmall!.copyWith(color: theme.colorScheme.onSurface)),
          if (subtitle?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: AppTheme.motionFast,
              child: Text(
                subtitle!,
                key: ValueKey(subtitle),
                style: theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The confirm and cancel buttons at the bottom of the app's picker dialogs.
class ExpressiveDialogActions extends StatelessWidget {
  final List<Widget> children;

  const ExpressiveDialogActions({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, overflowAlignment: OverflowBarAlignment.end, children: children),
    );
  }
}

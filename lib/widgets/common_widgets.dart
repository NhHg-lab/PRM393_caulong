import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

String formatVnd(int value) {
  final chars = value.toString().split('').reversed.toList();
  final groups = <String>[];
  for (var index = 0; index < chars.length; index += 3) {
    groups.add(chars.skip(index).take(3).toList().reversed.join());
  }
  return '${groups.reversed.join('.')}đ';
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.compact = false});
  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.navyDeep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(compact ? 12 : 15),
          ),
          child: Icon(
            Icons.sports_tennis_rounded,
            color: AppColors.navyDeep,
            size: compact ? 22 : 27,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          'COURTLY',
          style: TextStyle(
            color: foreground,
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class CourtArtwork extends StatelessWidget {
  const CourtArtwork({
    super.key,
    required this.color,
    required this.icon,
    this.height = 150,
    this.heroTag,
  });
  final Color color;
  final IconData icon;
  final double height;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .92), color.withValues(alpha: .62)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -25,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .14),
                  width: 20,
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 16,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 48),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 42,
                  color: Colors.white.withValues(alpha: .35),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PLAY\nYOUR WAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.15,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return heroTag == null ? content : Hero(tag: heroTag!, child: content);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: AppColors.limeSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.navy),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carte de base Fayma : coins arrondis, bord discret et ombre optionnelle.
class FaymaCard extends StatelessWidget {
  const FaymaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.gradient,
    this.border,
    this.radius = AppTheme.cardRadius,
    this.onTap,
    this.onLongPress,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final effectiveBorder = border ??
        (gradient == null
            ? Border.all(color: AppColors.border)
            : Border.all(color: Colors.transparent));

    Widget content = Material(
      color:
          gradient == null ? (color ?? AppColors.surface) : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: borderRadius,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
          border: effectiveBorder,
        ),
        child: onTap == null && onLongPress == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );

    if (elevated) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: content,
      );
    }

    return content;
  }
}

/// En-tête de section avec titre, sous-titre et action facultative.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Petite étiquette de statut colorée.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontSize: compact ? 10.5 : 11.5,
                ),
          ),
        ],
      ),
    );
  }
}

/// Avatar carré arrondi avec les initiales du client.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.background,
    this.foreground,
  });

  final String name;
  final double size;
  final Color? background;
  final Color? foreground;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length > 1 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        gradient: background == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mintSoft, AppColors.indigoSoft],
              )
            : null,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: foreground ?? AppColors.mintDark,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}

/// Barre de progression animée et arrondie.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.mint,
    this.background = AppColors.surfaceMuted,
    this.height = 7,
  });

  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, animated, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: background),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animated,
                  child: ColoredBox(color: color),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bandeau d'information ou d'alerte.
class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.indigo,
    this.background = AppColors.indigoSoft,
    this.trailing,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Color color;
  final Color background;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: textTheme.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(
                    color: color,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// État vide / erreur avec icône et actions.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.color = AppColors.mint,
    this.background = AppColors.mintSoft,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 34, color: color),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(height: 1.5),
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onPrimary,
                  icon: Icon(primaryIcon ?? Icons.add_rounded, size: 20),
                  label: Text(primaryLabel!),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicateur de chargement centré avec libellé discret.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Ligne d'information avec libellé à gauche et valeur à droite.
class AppKeyValueRow extends StatelessWidget {
  const AppKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.ink,
    this.padding = const EdgeInsets.symmetric(vertical: 5),
  });

  final String label;
  final String value;
  final Color valueColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodySmall)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.titleSmall?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

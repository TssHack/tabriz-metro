import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Flat rounded card with a hairline border (no heavy shadows).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = AppRadii.card,
    this.flat = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  /// Without the soft shadow (for nested or tinted cards).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: t.border),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: flat ? null : softShadow(context),
      ),
      child: Material(
        color: color ?? t.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: t.fg,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small rounded label (chips are fully rounded per the design system).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = foreground ?? t.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? t.surface2,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing dot that marks live/estimated data.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color, this.size = 8});

  final Color? color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // Respect the platform "reduce motion" setting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduce) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.tokens.success;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_c),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.child,
    this.icon,
    this.warning = false,
  });

  final Widget child;
  final IconData? icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = warning ? t.warningSoft : t.primarySoft;
    final fg = warning ? t.warning : t.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: t.fg, fontSize: 13, height: 1.6),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered empty/error state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.fgMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.fgMuted),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Rounded pill toggle with an animated thumb (design-system segmented
/// control). Works in RTL and LTR.
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T value, String label, IconData? icon)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final index = options.indexWhere((o) => o.$1 == value);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: t.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                start: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (v, label, icon) in options)
                    Expanded(
                      child: Semantics(
                        selected: v == value,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                          onTap: () => onChanged(v),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon != null) ...[
                                  Icon(
                                    icon,
                                    size: 16,
                                    color: v == value ? t.primary : t.fgMuted,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: v == value
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: v == value ? t.fg : t.fgMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fades and slides its child in once when first built.
class EntranceFade extends StatelessWidget {
  const EntranceFade({super.key, required this.child, this.delay = 0});

  final Widget child;

  /// Stagger index (each step adds 40 ms).
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay * 40),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Soft drop shadow used by elevated cards.
List<BoxShadow> softShadow(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

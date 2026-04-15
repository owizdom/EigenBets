import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'grid_backdrop.dart';
import 'terminal_palette.dart';

/// The foundational card shell for the trading-terminal aesthetic.
///
///   ┌────────────────────────────────────────────────┐
///   │■│                                              │   ← 3px conviction stripe
///   │■│  ╭── diagonal grid backdrop @ ~1.5% ──╮     │
///   │■│  │                                      │     │
///   │■│  │            content                   │     │
///   │■│  │                                      │     │
///   │■│  ╰──────────────────────────────────────╯     │
///   └────────────────────────────────────────────────┘
///
/// On hover: lifts 2px, the conviction stripe glows outward ~12px, and the
/// card border inherits a cyan tint — instrumentation lighting up.
class TradingCard extends StatefulWidget {
  final Widget child;
  final Color? stripeColor;
  final double stripeWidth;
  final bool showGridBackdrop;
  final bool hoverable;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? surfaceColor;
  final Color? borderColor;

  const TradingCard({
    Key? key,
    required this.child,
    this.stripeColor,
    this.stripeWidth = 3,
    this.showGridBackdrop = true,
    this.hoverable = true,
    this.onTap,
    this.borderRadius = 14,
    this.padding,
    this.surfaceColor,
    this.borderColor,
  }) : super(key: key);

  @override
  State<TradingCard> createState() => _TradingCardState();
}

class _TradingCardState extends State<TradingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = widget.surfaceColor ?? AppTheme.surfaceColor;
    final baseBorder = widget.borderColor ?? theme.dividerColor;
    final stripe = widget.stripeColor ?? theme.colorScheme.primary;
    final hoverTint = TerminalPalette.ledCyan;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = widget.hoverable && true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: AnimatedContainer(
        duration: TerminalPalette.hoverLift,
        curve: TerminalPalette.hoverCurve,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovered
                ? Color.lerp(baseBorder, hoverTint.withOpacity(0.55), 0.8)!
                : baseBorder,
            width: 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: stripe.withOpacity(0.18),
                    blurRadius: 22,
                    spreadRadius: -4,
                    offset: const Offset(-6, 2),
                  ),
                  BoxShadow(
                    color: hoverTint.withOpacity(0.10),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              if (widget.showGridBackdrop)
                const Positioned.fill(
                  child: Opacity(
                    opacity: 0.55,
                    child: GridBackdrop(opacity: 0.55),
                  ),
                ),
              // Conviction stripe — slightly brighter on hover.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: TerminalPalette.hoverLift,
                  width: widget.stripeWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        stripe.withOpacity(_hovered ? 1.0 : 0.9),
                        stripe.withOpacity(_hovered ? 0.75 : 0.55),
                      ],
                    ),
                    boxShadow: _hovered
                        ? [
                            BoxShadow(
                              color: stripe.withOpacity(0.7),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  splashColor: stripe.withOpacity(0.07),
                  highlightColor: hoverTint.withOpacity(0.04),
                  child: Padding(
                    padding: widget.padding ??
                        const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

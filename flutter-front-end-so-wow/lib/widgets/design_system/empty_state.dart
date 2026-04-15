import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'terminal_palette.dart';

/// Compositional empty state. Replaces the default
/// "icon + centered grey text" pattern with a deliberate panel:
///
///   - A geometric target-reticle / grid backdrop drawn via CustomPainter
///   - A tinted glow halo behind the focal icon
///   - Primary headline in tracking-tight caps, secondary subtext in micro-cap
///   - Optional action button (for retry / go-to-markets)
///
/// The same component handles "no data yet" and "couldn't load". If you pass
/// [tint], it colors the halo + pattern lines (e.g. red for errors).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String message;
  final Color? tint;
  final Widget? action;
  final double minHeight;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.headline,
    required this.message,
    this.tint,
    this.action,
    this.minHeight = 220,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tint ?? theme.colorScheme.primary;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Backdrop: concentric target-reticle drawn at 14% opacity.
          Positioned.fill(
            child: CustomPaint(
              painter: _ReticlePainter(color: accent.withOpacity(0.16)),
            ),
          ),
          // Focal glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withOpacity(0.22),
                  accent.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Content column
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TerminalPalette.deepSurface,
                    border: Border.all(
                      color: accent.withOpacity(0.45),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.22),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  headline.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TerminalPalette.microCap(
                    context,
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                    fontSize: 11.5,
                  ).copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.58),
                      height: 1.4,
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 4 concentric circles.
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, 48.0 * i, paint);
    }

    // Crosshair
    final crossPaint = Paint()
      ..color = color.withOpacity(color.opacity * 0.7)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(center.dx - 220, center.dy),
        Offset(center.dx + 220, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 220),
        Offset(center.dx, center.dy + 220), crossPaint);

    // Tick marks every 30°.
    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi * 2) / 12;
      final inner = Offset(
        center.dx + math.cos(angle) * 180,
        center.dy + math.sin(angle) * 180,
      );
      final outer = Offset(
        center.dx + math.cos(angle) * 192,
        center.dy + math.sin(angle) * 192,
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color;
}

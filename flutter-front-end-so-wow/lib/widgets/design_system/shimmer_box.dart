import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'terminal_palette.dart';

/// A shimmer placeholder that reads like instrumentation warming up —
/// a sweeping diagonal highlight across a dim base, clipped to a rounded
/// rectangle. Use instead of [CircularProgressIndicator] in data regions.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? base;

  const ShimmerBox({
    Key? key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
    this.base,
  }) : super(key: key);

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TerminalPalette.shimmerCycle,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.base ?? AppTheme.surfaceColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: base)),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShimmerPainter(
                      t: t,
                      accent: AppTheme.primaryColor.withOpacity(0.14),
                      accent2: AppTheme.secondaryColor.withOpacity(0.18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t; // 0..1
  final Color accent;
  final Color accent2;

  _ShimmerPainter({required this.t, required this.accent, required this.accent2});

  @override
  void paint(Canvas canvas, Size size) {
    final sweepWidth = size.width * 0.45;
    final totalPath = size.width + sweepWidth;
    final x = -sweepWidth + totalPath * t;

    final rect = Rect.fromLTWH(x, 0, sweepWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          accent,
          accent2,
          accent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) =>
      old.t != t || old.accent != accent || old.accent2 != accent2;
}

/// Convenience stacker for list-row shimmer skeletons. Renders [count] rows
/// of the same height with [gap] between. Use where a list would normally
/// render (feeds, leaderboards, comment threads).
class ShimmerList extends StatelessWidget {
  final int count;
  final double rowHeight;
  final double gap;
  final EdgeInsets padding;

  const ShimmerList({
    Key? key,
    this.count = 6,
    this.rowHeight = 64,
    this.gap = 8,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: List.generate(count, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : gap),
            child: ShimmerBox(height: rowHeight, borderRadius: 10),
          );
        }),
      ),
    );
  }
}

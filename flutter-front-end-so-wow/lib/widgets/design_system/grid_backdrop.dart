import 'package:flutter/material.dart';
import 'terminal_palette.dart';

/// Hair-thin diagonal grid painted behind cards. It's almost subliminal — the
/// point isn't to decorate, the point is to give the card a sense of being
/// calibrated ruled paper.
class GridBackdrop extends StatelessWidget {
  final double opacity;
  final double spacing;
  final Widget? child;

  const GridBackdrop({
    Key? key,
    this.opacity = 1.0,
    this.spacing = 14,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DiagonalGridPainter(
        color: TerminalPalette.gridLine,
        spacing: spacing,
        opacity: opacity,
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _DiagonalGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double opacity;

  _DiagonalGridPainter({
    required this.color,
    required this.spacing,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity((color.opacity * opacity).clamp(0.0, 1.0))
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Diagonal lines (↘) crossing the whole canvas.
    final diag = size.width + size.height;
    for (double d = -size.height; d < diag; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalGridPainter old) =>
      old.color != color || old.spacing != spacing || old.opacity != opacity;
}

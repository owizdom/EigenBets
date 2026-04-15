import 'package:flutter/material.dart';
import 'terminal_palette.dart';

/// Hair-thin line chart with an area fill — the micro-version used inside
/// card headers and row trailing slots. Renders fast via a single path
/// because it's shown in many places.
///
/// When [animate] is true, the line stroke draws from 0% → 100% on first
/// mount over [TerminalPalette.chartEntry].
class Sparkline extends StatefulWidget {
  final List<double> values;
  final Color color;
  final double height;
  final double width;
  final bool animate;
  final bool fill;

  const Sparkline({
    Key? key,
    required this.values,
    required this.color,
    this.width = 72,
    this.height = 22,
    this.animate = true,
    this.fill = true,
  }) : super(key: key);

  @override
  State<Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<Sparkline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TerminalPalette.chartEntry,
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant Sparkline old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _SparklinePainter(
            values: widget.values,
            color: widget.color,
            progress: _controller.value,
            fill: widget.fill,
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double progress;
  final bool fill;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.progress,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final yNorm = (values[i] - minV) / range; // 0..1
      final y = size.height - (yNorm * (size.height - 3)) - 1.5;
      points.add(Offset(x, y));
    }

    final totalLength = _pathLength(points);
    final visibleLength = totalLength * progress;

    // Build progress path by walking segments until we exceed visibleLength.
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    double drawn = 0;
    for (int i = 1; i < points.length; i++) {
      final segLen = (points[i] - points[i - 1]).distance;
      if (drawn + segLen <= visibleLength) {
        linePath.lineTo(points[i].dx, points[i].dy);
        drawn += segLen;
      } else {
        final t = (visibleLength - drawn) / segLen;
        final partial = Offset.lerp(points[i - 1], points[i], t)!;
        linePath.lineTo(partial.dx, partial.dy);
        break;
      }
    }

    // Area fill underneath the visible path.
    if (fill) {
      final areaPath = Path.from(linePath);
      final lastMetric = linePath.computeMetrics().isEmpty
          ? null
          : linePath.computeMetrics().last;
      if (lastMetric != null) {
        final end = lastMetric.getTangentForOffset(lastMetric.length)?.position ??
            points.first;
        areaPath
          ..lineTo(end.dx, size.height)
          ..lineTo(points[0].dx, size.height)
          ..close();
        canvas.drawPath(
          areaPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.26),
                color.withOpacity(0.0),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
      }
    }

    // Outer glow (hair-thin).
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color.withOpacity(0.45)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );

    // Crisp line on top.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  double _pathLength(List<Offset> pts) {
    double d = 0;
    for (int i = 1; i < pts.length; i++) {
      d += (pts[i] - pts[i - 1]).distance;
    }
    return d;
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.progress != progress ||
      old.fill != fill;
}

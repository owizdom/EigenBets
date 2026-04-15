import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'terminal_palette.dart';

/// A segmented probability meter — think audio level meter rather than a
/// smooth progress bar. [value] is 0..1; it maps to a number of lit cells
/// out of [segmentCount]. The last lit cell gets a subtle glow.
///
/// When [value] changes, lit cells animate in one-by-one left-to-right
/// ([TerminalPalette.cellCascade] per cell) so the meter reads as if the
/// data just updated on instrumentation.
class ProbabilityMeter extends StatefulWidget {
  final double value; // 0..1
  final Color color;
  final int segmentCount;
  final double height;
  final double gap;
  final bool showTick; // draws a small caret at the 50% mark

  const ProbabilityMeter({
    Key? key,
    required this.value,
    required this.color,
    this.segmentCount = 22,
    this.height = 8,
    this.gap = 2,
    this.showTick = false,
  }) : super(key: key);

  @override
  State<ProbabilityMeter> createState() => _ProbabilityMeterState();
}

class _ProbabilityMeterState extends State<ProbabilityMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TerminalPalette.meterSettle,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: TerminalPalette.meterCurve,
    );
    _previousValue = widget.value;
    _controller.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant ProbabilityMeter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previousValue = old.value;
      _controller.forward(from: 0.0);
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
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        final current = _previousValue + (widget.value - _previousValue) * t;
        return CustomPaint(
          size: Size.fromHeight(widget.height),
          painter: _MeterPainter(
            value: current.clamp(0.0, 1.0),
            color: widget.color,
            segmentCount: widget.segmentCount,
            gap: widget.gap,
            showTick: widget.showTick,
          ),
          child: SizedBox(height: widget.height),
        );
      },
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double value;
  final Color color;
  final int segmentCount;
  final double gap;
  final bool showTick;

  _MeterPainter({
    required this.value,
    required this.color,
    required this.segmentCount,
    required this.gap,
    required this.showTick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalGap = gap * (segmentCount - 1);
    final cellWidth = (size.width - totalGap) / segmentCount;
    final lit = (value * segmentCount).clamp(0.0, segmentCount.toDouble());

    final bgPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final edgePaint = Paint()
      ..color = color.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final litPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..imageFilter = null
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2.2);

    for (int i = 0; i < segmentCount; i++) {
      final x = i * (cellWidth + gap);
      final rect = Rect.fromLTWH(x, 0, cellWidth, size.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1.5));

      // Background cell outline — always drawn so inactive cells read as a faint "off" state.
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, edgePaint);

      if (i < lit.floor()) {
        canvas.drawRRect(rrect, litPaint);
      } else if (i < lit) {
        // Partial cell — the leading edge of progress.
        final partial = lit - i; // 0..1
        final partialRect = Rect.fromLTWH(x, 0, cellWidth * partial, size.height);
        final partialRRect = RRect.fromRectAndRadius(partialRect, const Radius.circular(1.5));
        canvas.drawRRect(partialRRect, litPaint);
      }

      // Glow on the last fully-lit cell so the leading edge reads as "hot".
      if (i == lit.floor() - 1 || (i < lit && i == lit.floor())) {
        canvas.drawRRect(rrect, glowPaint);
      }
    }

    if (showTick) {
      final tickX = size.width * 0.5;
      final tickPaint = Paint()
        ..color = AppTheme.textSecondary.withOpacity(0.35)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(tickX, -2),
        Offset(tickX, size.height + 2),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.value != value ||
      old.color != color ||
      old.segmentCount != segmentCount ||
      old.gap != gap ||
      old.showTick != showTick;
}

/// Labeled outcome row: micro-cap label on the left, meter in the middle,
/// tabular percentage on the right.
class OutcomeMeterRow extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final Color color;
  final String? symbol;
  final bool highlighted;

  const OutcomeMeterRow({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    this.symbol,
    this.highlighted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = (value * 100).clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: highlighted
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          )
                        ]
                      : const [],
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        highlighted ? FontWeight.w600 : FontWeight.w500,
                    color: theme.colorScheme.onSurface
                        .withOpacity(highlighted ? 0.95 : 0.82),
                  ),
                ),
              ),
              if (symbol != null) ...[
                Text(
                  symbol!,
                  style: TerminalPalette.microCap(context,
                      color: theme.colorScheme.onSurface.withOpacity(0.45)),
                ),
                const SizedBox(width: 10),
              ],
              SizedBox(
                width: 52,
                child: Text(
                  '${displayed.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TerminalPalette.mono(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ProbabilityMeter(value: value, color: color),
        ],
      ),
    );
  }
}

/// Picks the dominant outcome color from a list of (label, price) pairs.
Color dominantOutcomeColor(List<double> prices) {
  if (prices.isEmpty) return AppTheme.primaryColor;
  double maxPrice = -double.infinity;
  int maxIdx = 0;
  for (int i = 0; i < prices.length; i++) {
    if (prices[i] > maxPrice) {
      maxPrice = prices[i];
      maxIdx = i;
    }
  }
  // Binary conviction: green if YES >= 50%, red otherwise.
  if (prices.length == 2) {
    return prices[0] >= prices[1]
        ? TerminalPalette.ledGreen
        : TerminalPalette.ledRed;
  }
  return TerminalPalette.outcomeColorAt(maxIdx);
}

/// Gentler math helper for the main card to choose a conviction stripe color
/// based on dominant outcome strength.
Color convictionStripe({required double topPrice, required Color baseColor}) {
  // Stronger conviction = brighter color. Weak conviction = muted.
  final intensity = (topPrice - 0.45).clamp(0.0, 0.55) / 0.55;
  return Color.lerp(
        baseColor.withOpacity(0.45),
        baseColor,
        math.pow(intensity, 0.7).toDouble(),
      ) ??
      baseColor;
}

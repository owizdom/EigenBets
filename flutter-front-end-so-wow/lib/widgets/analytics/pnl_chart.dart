import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../models/user_analytics.dart';
import '../../services/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../design_system/empty_state.dart';
import '../design_system/shimmer_box.dart';

/// Production chart widget rendering the connected user's cumulative realized
/// + unrealized profit and loss as a smoothed `LineChart` with an area fill
/// below the line. Above the chart, a stat tile surfaces the current P&L and
/// the 30-day change. Consumes [AnalyticsProvider] for data, loading, error,
/// and source state. Colors are driven entirely by theme tokens — green when
/// the user is in profit, red when under water.
class PnlChart extends StatelessWidget {
  const PnlChart({Key? key}) : super(key: key);

  /// Window used to compute the "30-day change" delta next to the current P&L.
  static const Duration _deltaWindow = Duration(days: 30);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticsProvider>();
    final points = provider.pnl;
    final isLoading = provider.isLoading('pnl');
    final error = provider.errorFor('pnl');
    final source = provider.sourceFor('pnl');

    // Chronologically sorted copy so every downstream calculation and the
    // rendered line agree on ordering. `sortedPoints` is null iff not loaded.
    final sortedPoints = (points == null)
        ? null
        : (List<PnLPoint>.from(points)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)));

    final current = (sortedPoints == null || sortedPoints.isEmpty)
        ? 0.0
        : sortedPoints.last.cumulativePnl;
    final isPositive = current >= 0;
    final lineColor =
        isPositive ? AppTheme.successColor : AppTheme.errorColor;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, source, isPositive, lineColor),
            const SizedBox(height: 12),
            _buildBody(
              context,
              theme,
              provider,
              sortedPoints,
              isLoading,
              error,
              lineColor,
              isPositive,
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    ThemeData theme,
    AnalyticsSource? source,
    bool isPositive,
    Color accent,
  ) {
    // Leading icon flips between up/down to reinforce the P&L direction at a
    // glance. Primary color for up-state preserves brand continuity; error
    // color for down-state matches the chart fill.
    final leadingIcon =
        isPositive ? Icons.trending_up : Icons.trending_down;
    final leadingColor =
        isPositive ? theme.colorScheme.primary : AppTheme.errorColor;

    return Row(
      children: [
        Icon(leadingIcon, color: leadingColor, size: 20),
        const SizedBox(width: 8),
        Text('Cumulative P&L', style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        if (source != null) _SourceBadge(source: source),
        const Spacer(),
      ],
    );
  }

  // ── Body (state dispatch) ─────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AnalyticsProvider provider,
    List<PnLPoint>? points,
    bool isLoading,
    String? error,
    Color lineColor,
    bool isPositive,
  ) {
    // Loading: shimmer card matching chart region.
    if (points == null && isLoading) {
      return const SizedBox(
        height: 240,
        child: ShimmerBox(height: 240, borderRadius: 12),
      );
    }

    // Hard error with no fallback data.
    if (points == null && error != null) {
      return EmptyState(
        icon: Icons.sensors_off_rounded,
        headline: 'P&L unavailable',
        message: 'We lost the line to your trades — try again.',
        tint: theme.colorScheme.error,
        minHeight: 240,
        action: FilledButton.icon(
          onPressed: () => provider.loadPnl(),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      );
    }

    // Empty: loaded but no trades yet.
    if (points != null && points.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        headline: 'No trades on record',
        message: 'Place your first bet and P&L will chart itself here.',
        tint: AppTheme.successColor,
        minHeight: 240,
      );
    }

    // Success — data exists and is non-empty here.
    final series = points!;
    final current = series.last.cumulativePnl;
    final delta = _computeWindowDelta(series, _deltaWindow);

    final success = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatsRow(
          current: current,
          delta: delta,
          isPositive: isPositive,
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildChart(theme, series, lineColor),
        ),
      ],
    );

    // Soft error: data is present (likely dummy fallback) but the fetch
    // errored. Show the data plus a retry banner above.
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ErrorBanner(
            message: error,
            onRetry: () => provider.loadPnl(),
          ),
          const SizedBox(height: 8),
          success,
        ],
      );
    }

    return success;
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  Widget _buildChart(
    ThemeData theme,
    List<PnLPoint> series,
    Color lineColor,
  ) {
    final spots = <FlSpot>[
      for (final pt in series)
        FlSpot(
          pt.timestamp.millisecondsSinceEpoch.toDouble(),
          pt.cumulativePnl,
        ),
    ];

    // X-domain: min/max timestamps, guarded against degenerate (single point
    // or coincident) data.
    double minX = spots.first.x;
    double maxX = spots.last.x;
    if (!minX.isFinite || !maxX.isFinite || minX == maxX) {
      maxX = minX + 1;
    }

    // Y-domain: symmetric padding around the observed range so the zero line
    // is always visible even when the user is deeply positive or negative.
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = -1;
      maxY = 1;
    }
    if (minY == maxY) {
      // Flat series: give the axis a visible span.
      final base = minY.abs() < 1 ? 1.0 : minY.abs();
      minY -= base;
      maxY += base;
    }
    // Ensure zero is in view so the reference line is meaningful.
    if (minY > 0) minY = 0;
    if (maxY < 0) maxY = 0;
    final span = (maxY - minY).abs();
    final pad = span * 0.12;
    minY -= pad;
    maxY += pad;

    final horizontalInterval = _niceInterval(maxY - minY);
    final verticalInterval = (maxX - minX) / 4;

    final axisColor = theme.colorScheme.onSurface.withOpacity(0.55);
    final gridColor = theme.dividerColor.withOpacity(0.35);
    final zeroLineColor = theme.dividerColor;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.18,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withOpacity(0.30),
                  lineColor.withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: zeroLineColor,
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ],
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 0.6,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: horizontalInterval,
              getTitlesWidget: (value, meta) {
                // Suppress the absolute min/max rail labels to avoid clipping.
                if (value <= meta.min || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatCompactCurrency(value),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: axisColor,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: verticalInterval,
              getTitlesWidget: (value, meta) {
                if (value <= minX || value >= maxX) {
                  return const SizedBox.shrink();
                }
                final ts =
                    DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatDateLabel(ts),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: axisColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: gridColor, width: 1),
            bottom: BorderSide(color: gridColor, width: 1),
            top: BorderSide.none,
            right: BorderSide.none,
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                theme.colorScheme.surface.withOpacity(0.95),
            tooltipBorder: BorderSide(color: theme.dividerColor),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((spot) {
              final ts = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              return LineTooltipItem(
                '${_formatSignedCurrency(spot.y)}\n${_formatTooltipDate(ts)}',
                theme.textTheme.labelSmall!.copyWith(
                  color: lineColor,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Math helpers ──────────────────────────────────────────────────────────

  /// Cumulative change between the latest point and the earliest point still
  /// within [window] of `now`. Falls back to (last - first) if the series
  /// doesn't extend that far back.
  static double _computeWindowDelta(
    List<PnLPoint> sorted,
    Duration window,
  ) {
    if (sorted.isEmpty) return 0;
    final last = sorted.last;
    final cutoff = last.timestamp.subtract(window);
    PnLPoint anchor = sorted.first;
    for (final pt in sorted) {
      if (!pt.timestamp.isBefore(cutoff)) {
        anchor = pt;
        break;
      }
    }
    return last.cumulativePnl - anchor.cumulativePnl;
  }

  /// Pick a readable Y-axis grid interval (roughly 4-5 divisions) using a
  /// 1/2/5 magnitude scheme so the labels stay round.
  static double _niceInterval(double span) {
    if (span <= 0 || !span.isFinite) return 1;
    final target = span / 4;
    final magnitude = _pow10((_log10(target)).floor());
    final normalized = target / magnitude;
    double step;
    if (normalized < 1.5) {
      step = 1;
    } else if (normalized < 3.5) {
      step = 2;
    } else if (normalized < 7.5) {
      step = 5;
    } else {
      step = 10;
    }
    return step * magnitude;
  }

  static double _log10(double x) {
    // Avoid importing dart:math just for log10 — a single call suffices.
    const ln10 = 2.302585092994046;
    // Fall back to 0 for non-positive inputs to keep the interval picker safe.
    if (x <= 0) return 0;
    double y = x;
    int e = 0;
    while (y >= 10) {
      y /= 10;
      e++;
    }
    while (y < 1) {
      y *= 10;
      e--;
    }
    // Rough mantissa log via Taylor/series isn't needed; the integer exponent
    // is all the interval picker relies on.
    return e + (y - 1) / ln10;
  }

  static double _pow10(int exp) {
    double r = 1;
    if (exp >= 0) {
      for (int i = 0; i < exp; i++) {
        r *= 10;
      }
    } else {
      for (int i = 0; i < -exp; i++) {
        r /= 10;
      }
    }
    return r;
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  /// Compact currency label for Y-axis ticks, e.g. `$1.2k`, `-$850`, `$0`.
  static String _formatCompactCurrency(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    if (abs >= 1e9) {
      return '$sign\$${(abs / 1e9).toStringAsFixed(1)}b';
    }
    if (abs >= 1e6) {
      return '$sign\$${(abs / 1e6).toStringAsFixed(1)}m';
    }
    if (abs >= 1e3) {
      return '$sign\$${(abs / 1e3).toStringAsFixed(1)}k';
    }
    if (abs >= 100) {
      return '$sign\$${abs.toStringAsFixed(0)}';
    }
    return '$sign\$${abs.toStringAsFixed(1)}';
  }

  /// Full signed currency, used by the stat tiles and tooltips.
  /// Examples: `+$123.45`, `-$67.89`, `+$0.00`.
  static String _formatSignedCurrency(double v) {
    final sign = v < 0 ? '-' : '+';
    final abs = v.abs();
    return '$sign\$${abs.toStringAsFixed(2)}';
  }

  static String _formatDateLabel(DateTime ts) {
    final local = ts.toLocal();
    return '${local.month}/${local.day}';
  }

  static String _formatTooltipDate(DateTime ts) {
    final local = ts.toLocal();
    return '${local.month}/${local.day} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double current;
  final double delta;
  final bool isPositive;

  const _StatsRow({
    Key? key,
    required this.current,
    required this.delta,
    required this.isPositive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor =
        isPositive ? AppTheme.successColor : AppTheme.errorColor;
    final deltaColor =
        delta >= 0 ? AppTheme.successColor : AppTheme.errorColor;
    final deltaIcon =
        delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Current',
            value: PnlChart._formatSignedCurrency(current),
            valueStyle: theme.textTheme.titleLarge?.copyWith(
              color: currentColor,
              fontWeight: FontWeight.w700,
            ),
            leading: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: currentColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: '30-day change',
            value: PnlChart._formatSignedCurrency(delta),
            valueStyle: theme.textTheme.titleMedium?.copyWith(
              color: deltaColor,
              fontWeight: FontWeight.w700,
            ),
            leading: Icon(
              deltaIcon,
              size: 16,
              color: deltaColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? leading;

  const _StatTile({
    Key? key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final AnalyticsSource source;

  const _SourceBadge({Key? key, required this.source}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = source == AnalyticsSource.backend ||
        source == AnalyticsSource.contract;
    final label = isLive ? 'LIVE' : 'DEMO';
    final color =
        isLive ? theme.colorScheme.secondary : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../services/analytics_provider.dart';

/// Production chart widget showing probability-over-time for each outcome of
/// the currently selected prediction market. Consumes [AnalyticsProvider] and
/// renders an [fl_chart] `LineChart` with overlaid series and a time-range
/// selector. Handles loading / empty / error / success states.
class PriceHistoryChart extends StatelessWidget {
  const PriceHistoryChart({Key? key}) : super(key: key);

  static const List<String> _ranges = ['1H', '1D', '1W', '1M', 'ALL'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticsProvider>();
    final points = provider.priceHistory;
    final isLoading = provider.isLoading('priceHistory');
    final error = provider.errorFor('priceHistory');
    final source = provider.sourceFor('priceHistory');

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
            _buildHeader(context, theme, provider, source),
            const SizedBox(height: 12),
            _buildBody(context, theme, provider, points, isLoading, error),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AnalyticsProvider provider,
    AnalyticsSource? source,
  ) {
    return Row(
      children: [
        Icon(Icons.show_chart, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text('Price history', style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        if (source != null) _SourceBadge(source: source),
        const Spacer(),
        _RangeSelector(
          ranges: _ranges,
          selected: provider.range,
          onSelect: (r) {
            provider.setRange(r);
            provider.loadPriceHistory();
          },
        ),
      ],
    );
  }

  // ── Body (state dispatch) ─────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AnalyticsProvider provider,
    List<PriceHistoryPoint>? points,
    bool isLoading,
    String? error,
  ) {
    // Loading: no data yet and a fetch is in flight.
    if (points == null && isLoading) {
      return SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Empty: loaded but no points.
    if (points != null && points.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timeline_outlined,
                size: 40,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 8),
              Text(
                'No price history yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Success (possibly with an error banner above).
    final chart = (points == null || points.isEmpty)
        ? SizedBox(
            height: 240,
            child: Center(
              child: Text(
                'No data to display',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          )
        : AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildChart(theme, points, provider.range),
          );

    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ErrorBanner(
            message: error,
            onRetry: () => provider.loadPriceHistory(),
          ),
          const SizedBox(height: 8),
          chart,
        ],
      );
    }

    return chart;
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  Widget _buildChart(
    ThemeData theme,
    List<PriceHistoryPoint> points,
    String range,
  ) {
    final seriesColors = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];

    // Group points by outcome index, preserving insertion order.
    final grouped = <int, List<PriceHistoryPoint>>{};
    for (final pt in points) {
      grouped.putIfAbsent(pt.outcomeIndex, () => <PriceHistoryPoint>[]).add(pt);
    }
    // Sort each outcome's points chronologically.
    for (final list in grouped.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // X-domain: min/max timestamps across all series, in ms since epoch.
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    for (final pt in points) {
      final x = pt.timestamp.millisecondsSinceEpoch.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
    }
    if (!minX.isFinite || !maxX.isFinite || minX == maxX) {
      // Guard against degenerate domains.
      maxX = minX + 1;
    }

    // Y-domain: 0..1 probability with 5% padding.
    const double minY = -0.05;
    const double maxY = 1.05;

    final sortedOutcomes = grouped.keys.toList()..sort();
    final bars = <LineChartBarData>[
      for (final outcome in sortedOutcomes)
        _barForOutcome(
          theme,
          grouped[outcome]!,
          seriesColors[outcome % seriesColors.length],
        ),
    ];

    final axisColor = theme.colorScheme.onSurface.withOpacity(0.5);
    final gridColor = theme.dividerColor.withOpacity(0.4);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: bars,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: 0.1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 0.6,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.2,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toStringAsFixed(1),
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
              interval: (maxX - minX) / 4,
              getTitlesWidget: (value, meta) {
                // Skip edge labels to prevent clipping.
                if (value <= minX || value >= maxX) {
                  return const SizedBox.shrink();
                }
                final ts =
                    DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatXLabel(ts, range),
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
              final color = spot.bar.color ?? theme.colorScheme.primary;
              final ts = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              final pct = (spot.y * 100).clamp(0.0, 100.0);
              return LineTooltipItem(
                'Outcome ${spot.barIndex + 1}\n'
                '${pct.toStringAsFixed(1)}% · ${_formatTooltipTime(ts)}',
                theme.textTheme.labelSmall!.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  LineChartBarData _barForOutcome(
    ThemeData theme,
    List<PriceHistoryPoint> series,
    Color color,
  ) {
    final spots = <FlSpot>[
      for (final pt in series)
        FlSpot(
          pt.timestamp.millisecondsSinceEpoch.toDouble(),
          pt.probability.clamp(0.0, 1.0),
        ),
    ];
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.30),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  static String _formatXLabel(DateTime ts, String range) {
    final local = ts.toLocal();
    if (range == '1H' || range == '1D') {
      return '${_two(local.hour)}:${_two(local.minute)}';
    }
    return '${local.month}/${local.day}';
  }

  static String _formatTooltipTime(DateTime ts) {
    final local = ts.toLocal();
    return '${local.month}/${local.day} ${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  final List<String> ranges;
  final String selected;
  final ValueChanged<String> onSelect;

  const _RangeSelector({
    Key? key,
    required this.ranges,
    required this.selected,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in ranges)
            _RangeChip(
              label: r,
              selected: r == selected,
              onTap: () => onSelect(r),
            ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? theme.colorScheme.primary : Colors.transparent;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withOpacity(0.75);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
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

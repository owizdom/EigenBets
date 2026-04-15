import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../models/user_analytics.dart';
import '../../services/analytics_provider.dart';
import '../../theme/app_theme.dart';

/// Production analytics card showing portfolio value over time (filled area)
/// and cash flow (dashed line, no fill) with a prominent "Portfolio Value"
/// stat tile and 7-day change delta.
///
/// Consumes [AnalyticsProvider] for data, loading / error / source metadata,
/// and handles loading / empty / error-with-retry / success states.
class PortfolioValueChart extends StatelessWidget {
  const PortfolioValueChart({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticsProvider>();
    final snapshots = provider.portfolio;
    final isLoading = provider.isLoading('portfolio');
    final error = provider.errorFor('portfolio');
    final source = provider.sourceFor('portfolio');

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
            _buildHeader(theme, source),
            const SizedBox(height: 12),
            _buildBody(context, theme, provider, snapshots, isLoading, error),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, AnalyticsSource? source) {
    return Row(
      children: [
        Icon(
          Icons.pie_chart_outline,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text('Portfolio value', style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        if (source != null) _SourceBadge(source: source),
      ],
    );
  }

  // ── Body (state dispatch) ─────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AnalyticsProvider provider,
    List<PortfolioSnapshot>? snapshots,
    bool isLoading,
    String? error,
  ) {
    // Loading: no data yet and a fetch is in flight.
    if (snapshots == null && isLoading) {
      return SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Hard error with no fallback data: show retry.
    if (snapshots == null && error != null) {
      return SizedBox(
        height: 260,
        child: Center(
          child: _ErrorRetry(
            message: error,
            onRetry: () => provider.loadPortfolio(),
          ),
        ),
      );
    }

    // Empty: loaded but no snapshots.
    if (snapshots != null && snapshots.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 40,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 8),
              Text(
                'No portfolio history yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Success path. Clone + sort chronologically so stats & series align.
    final sorted = List<PortfolioSnapshot>.from(snapshots ?? const [])
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final latest = sorted.last;
    final sevenDayDelta = _sevenDayChange(sorted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          _ErrorBanner(
            message: error,
            onRetry: () => provider.loadPortfolio(),
          ),
          const SizedBox(height: 12),
        ],
        _StatTile(
          currentValue: latest.portfolioValue,
          sevenDayDelta: sevenDayDelta,
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildChart(theme, sorted),
        ),
        const SizedBox(height: 8),
        _Legend(
          portfolioColor: theme.colorScheme.primary,
          cashFlowColor: theme.colorScheme.secondary,
        ),
      ],
    );
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  Widget _buildChart(ThemeData theme, List<PortfolioSnapshot> snapshots) {
    final axisColor = theme.colorScheme.onSurface.withOpacity(0.5);
    final gridColor = theme.dividerColor.withOpacity(0.4);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    // Build spots for both series.
    final portfolioSpots = <FlSpot>[
      for (final s in snapshots)
        FlSpot(
          s.timestamp.millisecondsSinceEpoch.toDouble(),
          s.portfolioValue,
        ),
    ];
    final cashFlowSpots = <FlSpot>[
      for (final s in snapshots)
        FlSpot(
          s.timestamp.millisecondsSinceEpoch.toDouble(),
          s.cashFlow,
        ),
    ];

    // X-domain: min/max timestamp across the series.
    double minX = portfolioSpots.first.x;
    double maxX = portfolioSpots.last.x;
    if (!minX.isFinite || !maxX.isFinite || minX == maxX) {
      maxX = minX + 1;
    }

    // Y-domain: span both series with 10% padding.
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final spot in [...portfolioSpots, ...cashFlowSpots]) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yPad = (maxY - minY) * 0.1;
    minY -= yPad;
    maxY += yPad;

    final yInterval = _niceInterval(maxY - minY);

    final portfolioBar = LineChartBarData(
      spots: portfolioSpots,
      isCurved: true,
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      color: primary,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withOpacity(0.30),
            primary.withOpacity(0.02),
          ],
        ),
      ),
    );

    final cashFlowBar = LineChartBarData(
      spots: cashFlowSpots,
      isCurved: true,
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      color: secondary,
      barWidth: 2,
      isStrokeCapRound: true,
      dashArray: const [5, 3],
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: [portfolioBar, cashFlowBar],
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: yInterval,
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
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
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
              interval: (maxX - minX) / 4,
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
              final isPortfolio = spot.barIndex == 0;
              final color = isPortfolio ? primary : secondary;
              final label = isPortfolio ? 'Portfolio' : 'Cash flow';
              final ts =
                  DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              return LineTooltipItem(
                '$label\n'
                '${_formatCurrency(spot.y)} · ${_formatDateLabel(ts)}',
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

  // ── Calculations ──────────────────────────────────────────────────────────

  /// Portfolio value at the last snapshot minus the value ~7 days prior.
  /// Falls back to first snapshot when the series is shorter than 7 days.
  static double _sevenDayChange(List<PortfolioSnapshot> sorted) {
    if (sorted.length < 2) return 0;
    final latest = sorted.last;
    final cutoff = latest.timestamp.subtract(const Duration(days: 7));
    PortfolioSnapshot baseline = sorted.first;
    for (final s in sorted) {
      if (s.timestamp.isAfter(cutoff)) break;
      baseline = s;
    }
    return latest.portfolioValue - baseline.portfolioValue;
  }

  /// Pick a sensible grid interval for the given y-range by bucketing `raw`
  /// into the nearest {1, 2, 5} * 10^n step. Iterative, no `dart:math` needed.
  static double _niceInterval(double range) {
    if (range <= 0 || !range.isFinite) return 1;
    final raw = range / 4;
    // Find 10^n such that `raw` normalizes into [1, 10).
    double pow10 = 1;
    double normalized = raw;
    while (normalized >= 10) {
      normalized /= 10;
      pow10 *= 10;
    }
    while (normalized < 1) {
      normalized *= 10;
      pow10 /= 10;
    }
    double nice;
    if (normalized < 1.5) {
      nice = 1;
    } else if (normalized < 3.5) {
      nice = 2;
    } else if (normalized < 7.5) {
      nice = 5;
    } else {
      nice = 10;
    }
    final interval = nice * pow10;
    return interval > 0 ? interval : 1;
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  static String _formatCurrency(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    final whole = abs.truncate();
    final cents = ((abs - whole) * 100).round();
    final wholeStr = _withThousands(whole);
    final centsStr = cents.toString().padLeft(2, '0');
    return '$sign\$$wholeStr.$centsStr';
  }

  static String _formatCompactCurrency(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    if (abs >= 1e9) return '$sign\$${(abs / 1e9).toStringAsFixed(1)}B';
    if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(1)}M';
    if (abs >= 1e3) return '$sign\$${(abs / 1e3).toStringAsFixed(1)}K';
    return '$sign\$${abs.toStringAsFixed(0)}';
  }

  static String _formatSignedCurrency(double v) {
    final sign = v >= 0 ? '+' : '-';
    final abs = v.abs();
    final whole = abs.truncate();
    final cents = ((abs - whole) * 100).round();
    final wholeStr = _withThousands(whole);
    final centsStr = cents.toString().padLeft(2, '0');
    return '$sign\$$wholeStr.$centsStr';
  }

  static String _withThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromRight = s.length - i;
      buf.write(s[i]);
      if (posFromRight > 1 && posFromRight % 3 == 1) {
        buf.write(',');
      }
    }
    return buf.toString();
  }

  static String _formatDateLabel(DateTime ts) {
    final local = ts.toLocal();
    return '${local.month}/${local.day}';
  }
}

// ── Stat tile ───────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final double currentValue;
  final double sevenDayDelta;

  const _StatTile({
    Key? key,
    required this.currentValue,
    required this.sevenDayDelta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current value',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: captionColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                PortfolioValueChart._formatCurrency(currentValue),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        _DeltaChip(delta: sevenDayDelta),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double delta;

  const _DeltaChip({Key? key, required this.delta}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = delta >= 0;
    final color = isUp ? AppTheme.successColor : AppTheme.errorColor;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '7d change',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.35), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                PortfolioValueChart._formatSignedCurrency(delta),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Legend ──────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color portfolioColor;
  final Color cashFlowColor;

  const _Legend({
    Key? key,
    required this.portfolioColor,
    required this.cashFlowColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _LegendDot(color: portfolioColor),
        const SizedBox(width: 6),
        Text(
          'Portfolio',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.75),
          ),
        ),
        const SizedBox(width: 16),
        _LegendDot(color: cashFlowColor, dashed: true),
        const SizedBox(width: 6),
        Text(
          'Cash flow',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final bool dashed;

  const _LegendDot({Key? key, required this.color, this.dashed = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!dashed) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }
    // Dashed indicator: two pill segments.
    return SizedBox(
      width: 14,
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 5,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 5,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badges / banners ────────────────────────────────────────────────────────

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

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 36,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../services/analytics_provider.dart';
import '../design_system/shimmer_box.dart';

/// Daily trading volume (stacked by outcome) for the currently selected
/// prediction market. Reads its state from [AnalyticsProvider] and renders
/// loading / empty / error / success states consistently with the other
/// analytics cards.
class VolumeChart extends StatelessWidget {
  const VolumeChart({Key? key}) : super(key: key);

  static const List<String> _ranges = <String>['1H', '1D', '1W', '1M', 'ALL'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticsProvider>();

    final bool loading = provider.isLoading('volume');
    final String? error = provider.errorFor('volume');
    final AnalyticsSource? source = provider.sourceFor('volume');
    final List<VolumeBar>? bars = provider.volume;

    Widget body;
    if (loading && (bars == null || bars.isEmpty)) {
      body = const _VolumeLoading();
    } else if (bars == null || bars.isEmpty) {
      if (error != null) {
        body = _VolumeError(
          message: error,
          onRetry: () => provider.loadVolume(),
        );
      } else {
        body = const _VolumeEmpty();
      }
    } else {
      body = _VolumeBody(bars: bars);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _VolumeHeader(
            source: source,
            currentRange: provider.range,
            ranges: _ranges,
            onRangeSelected: (String r) {
              provider.setRange(r);
              provider.loadVolume();
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey<String>(_bodyKey(loading, bars, error)),
                child: body,
              ),
            ),
          ),
          if (error != null && bars != null && bars.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InlineErrorFooter(
                message: error,
                onRetry: () => provider.loadVolume(),
              ),
            ),
        ],
      ),
    );
  }

  String _bodyKey(bool loading, List<VolumeBar>? bars, String? error) {
    if (loading && (bars == null || bars.isEmpty)) return 'loading';
    if (bars == null || bars.isEmpty) {
      return error != null ? 'error' : 'empty';
    }
    return 'chart-${bars.length}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeHeader extends StatelessWidget {
  const _VolumeHeader({
    required this.source,
    required this.currentRange,
    required this.ranges,
    required this.onRangeSelected,
  });

  final AnalyticsSource? source;
  final String currentRange;
  final List<String> ranges;
  final ValueChanged<String> onRangeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.bar_chart, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Volume',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        _SourceBadge(source: source),
        const Spacer(),
        _RangeSelector(
          ranges: ranges,
          current: currentRange,
          onSelected: onRangeSelected,
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final AnalyticsSource? source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool live = source == AnalyticsSource.backend;
    final Color fg = live ? theme.colorScheme.primary : theme.colorScheme.outline;
    final Color bg = fg.withOpacity(0.12);
    final String label = live ? 'LIVE' : 'DEMO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.ranges,
    required this.current,
    required this.onSelected,
  });

  final List<String> ranges;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ranges.map((String r) {
          final bool selected = r == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: selected ? null : () => onSelected(r),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    r,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body variants
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeLoading extends StatelessWidget {
  const _VolumeLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: ShimmerBox(height: 200, borderRadius: 10),
    );
  }
}

class _VolumeEmpty extends StatelessWidget {
  const _VolumeEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.stacked_bar_chart_outlined,
            size: 32,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'No volume yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeError extends StatelessWidget {
  const _VolumeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline,
                color: theme.colorScheme.error, size: 28),
            const SizedBox(height: 8),
            Text(
              'Failed to load volume',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorFooter extends StatelessWidget {
  const _InlineErrorFooter({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(Icons.info_outline,
            size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Using fallback data: $message',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart body
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeBody extends StatelessWidget {
  const _VolumeBody({required this.bars});

  final List<VolumeBar> bars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _VolumeSeries series = _VolumeSeries.fromBars(bars);

    if (series.days.isEmpty) {
      return const _VolumeEmpty();
    }

    final List<Color> palette = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];

    final double maxY = series.maxTotal <= 0 ? 1 : series.maxTotal * 1.15;
    final double yInterval = _niceInterval(maxY);

    final List<BarChartGroupData> groups = <BarChartGroupData>[];
    for (int i = 0; i < series.days.length; i++) {
      final DateTime day = series.days[i];
      final Map<int, double> byOutcome = series.byDay[day] ?? <int, double>{};
      final List<int> sortedOutcomes = byOutcome.keys.toList()..sort();

      double cumulative = 0;
      final List<BarChartRodStackItem> stacks = <BarChartRodStackItem>[];
      for (final int outcomeIdx in sortedOutcomes) {
        final double value = byOutcome[outcomeIdx] ?? 0;
        if (value <= 0) continue;
        final Color color = palette[outcomeIdx % palette.length];
        stacks.add(BarChartRodStackItem(
          cumulative,
          cumulative + value,
          color,
        ));
        cumulative += value;
      }

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: cumulative,
              width: _barWidthFor(series.days.length),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              rodStackItems: stacks,
              color: stacks.isEmpty
                  ? theme.colorScheme.outline.withOpacity(0.2)
                  : null,
            ),
          ],
        ),
      );
    }

    final Widget chart = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barGroups: groups,
        groupsSpace: 8,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (double _) => FlLine(
            color: theme.dividerColor.withOpacity(0.35),
            strokeWidth: 1,
            dashArray: const <int>[4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _formatCompactUsd(value),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
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
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int idx = value.round();
                if (idx < 0 || idx >= series.days.length) {
                  return const SizedBox.shrink();
                }
                // Thin labels for wide date ranges to prevent overlap.
                final int step = _labelStepFor(series.days.length);
                if (idx % step != 0 && idx != series.days.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatDayMd(series.days[idx]),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tooltipMargin: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) =>
                theme.colorScheme.inverseSurface.withOpacity(0.96),
            getTooltipItem: (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              final DateTime day = series.days[group.x];
              final Map<int, double> usdByOutcome =
                  series.byDay[day] ?? <int, double>{};
              final Map<int, int> countByOutcome =
                  series.countsByDay[day] ?? <int, int>{};
              final List<int> sortedOutcomes = usdByOutcome.keys.toList()
                ..sort();
              final double total =
                  usdByOutcome.values.fold<double>(0, (a, b) => a + b);

              final TextStyle headStyle = TextStyle(
                color: theme.colorScheme.onInverseSurface,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              );
              final TextStyle subStyle = TextStyle(
                color:
                    theme.colorScheme.onInverseSurface.withOpacity(0.85),
                fontWeight: FontWeight.w400,
                fontSize: 11,
              );

              final List<TextSpan> children = <TextSpan>[
                TextSpan(
                  text: '\n${_formatUsd(total)} total\n',
                  style: subStyle,
                ),
              ];
              for (final int o in sortedOutcomes) {
                final double usd = usdByOutcome[o] ?? 0;
                final int n = countByOutcome[o] ?? 0;
                final Color color = palette[o % palette.length];
                children.add(TextSpan(
                  text: 'Outcome ${o + 1}: ',
                  style: subStyle.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ));
                children.add(TextSpan(
                  text:
                      '${_formatUsd(usd)}  (${n} ${n == 1 ? 'trade' : 'trades'})\n',
                  style: subStyle,
                ));
              }

              return BarTooltipItem(
                _formatTooltipDate(day),
                headStyle,
                children: children,
                textAlign: TextAlign.left,
              );
            },
          ),
        ),
      ),
    );

    // Favor AspectRatio when there's comfortable width; otherwise fill.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool canAspect = constraints.maxHeight >= 180 &&
            constraints.maxWidth >= 280;
        if (canAspect) {
          return Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: chart,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: chart,
        );
      },
    );
  }

  double _barWidthFor(int dayCount) {
    if (dayCount <= 7) return 22;
    if (dayCount <= 14) return 16;
    if (dayCount <= 30) return 10;
    return 6;
  }

  int _labelStepFor(int dayCount) {
    if (dayCount <= 7) return 1;
    if (dayCount <= 14) return 2;
    if (dayCount <= 30) return 5;
    return (dayCount / 8).ceil();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Series aggregation
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeSeries {
  _VolumeSeries({
    required this.days,
    required this.byDay,
    required this.countsByDay,
    required this.maxTotal,
  });

  final List<DateTime> days;
  final Map<DateTime, Map<int, double>> byDay;
  final Map<DateTime, Map<int, int>> countsByDay;
  final double maxTotal;

  static _VolumeSeries fromBars(List<VolumeBar> bars) {
    final Map<DateTime, Map<int, double>> byDay =
        <DateTime, Map<int, double>>{};
    final Map<DateTime, Map<int, int>> countsByDay =
        <DateTime, Map<int, int>>{};

    for (final VolumeBar b in bars) {
      final DateTime key = DateTime(b.day.year, b.day.month, b.day.day);
      final Map<int, double> usdMap =
          byDay.putIfAbsent(key, () => <int, double>{});
      usdMap[b.outcomeIndex] = (usdMap[b.outcomeIndex] ?? 0) + b.totalUsdc;
      final Map<int, int> countMap =
          countsByDay.putIfAbsent(key, () => <int, int>{});
      countMap[b.outcomeIndex] = (countMap[b.outcomeIndex] ?? 0) + b.count;
    }

    final List<DateTime> days = byDay.keys.toList()
      ..sort((DateTime a, DateTime b) => a.compareTo(b));

    double maxTotal = 0;
    for (final DateTime d in days) {
      final double sum =
          (byDay[d] ?? <int, double>{}).values.fold<double>(0, (a, b) => a + b);
      if (sum > maxTotal) maxTotal = sum;
    }

    return _VolumeSeries(
      days: days,
      byDay: byDay,
      countsByDay: countsByDay,
      maxTotal: maxTotal,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatting helpers (intl-free to avoid coupling to a specific locale setup)
// ─────────────────────────────────────────────────────────────────────────────

String _formatDayMd(DateTime d) => '${d.month}/${d.day}';

String _formatTooltipDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

String _formatCompactUsd(double v) {
  final double abs = v.abs();
  if (abs >= 1e9) return '\$${_trim(v / 1e9)}b';
  if (abs >= 1e6) return '\$${_trim(v / 1e6)}m';
  if (abs >= 1e3) return '\$${_trim(v / 1e3)}k';
  if (abs == 0) return '\$0';
  return '\$${v.toStringAsFixed(0)}';
}

String _formatUsd(double v) {
  if (v >= 1000) {
    final String whole = v.toStringAsFixed(0);
    final StringBuffer out = StringBuffer();
    int count = 0;
    for (int i = whole.length - 1; i >= 0; i--) {
      out.write(whole[i]);
      count++;
      if (count % 3 == 0 && i != 0) out.write(',');
    }
    return '\$${out.toString().split('').reversed.join()}';
  }
  return '\$${v.toStringAsFixed(2)}';
}

String _trim(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  if (v >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

/// Picks a clean y-axis step so grid lines land on round USD values.
double _niceInterval(double maxY) {
  if (maxY <= 0) return 1;
  final double rough = maxY / 4;
  final double mag = _pow10(rough == 0 ? 1 : rough.abs());
  final double normalized = rough / mag;
  double nice;
  if (normalized < 1.5) {
    nice = 1;
  } else if (normalized < 3) {
    nice = 2;
  } else if (normalized < 7) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * mag;
}

double _pow10(double v) {
  int exp = 0;
  double x = v;
  while (x >= 10) {
    x /= 10;
    exp++;
  }
  while (x < 1) {
    x *= 10;
    exp--;
  }
  double m = 1;
  if (exp >= 0) {
    for (int i = 0; i < exp; i++) {
      m *= 10;
    }
  } else {
    for (int i = 0; i < -exp; i++) {
      m /= 10;
    }
  }
  return m;
}

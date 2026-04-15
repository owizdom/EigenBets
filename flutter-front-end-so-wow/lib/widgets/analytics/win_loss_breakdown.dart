import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../models/user_analytics.dart';
import '../../services/analytics_provider.dart';
import '../../theme/app_theme.dart';

/// Production widget that visualizes a user's win / loss / open breakdown
/// as a donut chart with an accompanying stat grid. Reads from
/// [AnalyticsProvider] and honors its loading, error, and source states.
class WinLossBreakdown extends StatelessWidget {
  const WinLossBreakdown({Key? key}) : super(key: key);

  static const double _minHeight = 260;
  static const double _chartSize = 180;
  static const double _wideLayoutBreakpoint = 520;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticsProvider>();
    final stats = provider.winLoss;
    final isLoading = provider.isLoading('winLoss');
    final error = provider.errorFor('winLoss');
    final source = provider.sourceFor('winLoss');

    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TitleRow(source: source),
            const SizedBox(height: 16),
            SizedBox(
              height: _minHeight - 72,
              child: _buildBody(
                context: context,
                theme: theme,
                stats: stats,
                isLoading: isLoading,
                error: error,
                onRetry: () => provider.loadWinLoss(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ThemeData theme,
    required WinLossStats? stats,
    required bool isLoading,
    required String? error,
    required Future<void> Function() onRetry,
  }) {
    if (isLoading && stats == null) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (stats == null) {
      // Only show hard-error state when no fallback data exists. The
      // provider's hybrid strategy normally fills in dummy data on error,
      // so this path is reached only when the user is disconnected and no
      // dummy has been assigned yet.
      return _ErrorState(
        message: error ?? 'Unable to load win / loss data.',
        onRetry: onRetry,
      );
    }

    if (stats.totalMarkets == 0) {
      return _EmptyState(theme: theme);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
        final chart = _ChartSection(stats: stats, theme: theme);
        final statsPanel = _StatsGrid(stats: stats, theme: theme);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              chart,
              const SizedBox(width: 20),
              Expanded(child: statsPanel),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: chart),
              const SizedBox(height: 16),
              statsPanel,
            ],
          ),
        );
      },
    );
  }
}

// ── Building blocks ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: WinLossBreakdown._minHeight),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final AnalyticsSource? source;
  const _TitleRow({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.donut_large_outlined,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Win / loss',
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _SourceBadge(source: source),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final AnalyticsSource? source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    if (source == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isLive = source == AnalyticsSource.backend ||
        source == AnalyticsSource.contract;
    final label = isLive ? 'LIVE' : 'DEMO';
    final color = isLive
        ? AppTheme.successColor
        : theme.colorScheme.onSurface.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  final WinLossStats stats;
  final ThemeData theme;
  const _ChartSection({required this.stats, required this.theme});

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
      fontWeight: FontWeight.w700,
    );

    if (stats.wins > 0) {
      sections.add(
        PieChartSectionData(
          value: stats.wins.toDouble(),
          color: AppTheme.successColor,
          title: '${stats.wins}',
          radius: 40,
          titleStyle: labelStyle,
        ),
      );
    }
    if (stats.losses > 0) {
      sections.add(
        PieChartSectionData(
          value: stats.losses.toDouble(),
          color: AppTheme.errorColor,
          title: '${stats.losses}',
          radius: 40,
          titleStyle: labelStyle,
        ),
      );
    }
    if (stats.open > 0) {
      sections.add(
        PieChartSectionData(
          value: stats.open.toDouble(),
          color: theme.colorScheme.secondary,
          title: '${stats.open}',
          radius: 40,
          titleStyle: labelStyle,
        ),
      );
    }

    return SizedBox(
      width: WinLossBreakdown._chartSize,
      height: WinLossBreakdown._chartSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              startDegreeOffset: -90,
              borderData: FlBorderData(show: false),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${stats.totalMarkets}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'markets',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final WinLossStats stats;
  final ThemeData theme;
  const _StatsGrid({required this.stats, required this.theme});

  @override
  Widget build(BuildContext context) {
    final winRatePct = stats.winRate * 100;
    final winRateColor = stats.winRate >= 0.5
        ? AppTheme.successColor
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Win rate',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${winRatePct.toStringAsFixed(1)}%',
          style: theme.textTheme.titleLarge?.copyWith(
            color: winRateColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Wins',
                value: '${stats.wins}',
                valueColor: AppTheme.successColor,
                theme: theme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Losses',
                value: '${stats.losses}',
                valueColor: AppTheme.errorColor,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Open',
                value: '${stats.open}',
                valueColor: theme.colorScheme.secondary,
                theme: theme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Total',
                value: '${stats.totalMarkets}',
                valueColor: theme.colorScheme.onSurface,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final ThemeData theme;

  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
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
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 40,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'No resolved markets yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your win / loss breakdown will appear here.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 8),
          Text(
            'Could not load win / loss',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

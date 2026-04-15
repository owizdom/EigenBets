import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../services/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../design_system/shimmer_box.dart';

/// Production heatmap widget: a responsive grid of market cells colored by
/// 24h change (emerald for positive, rose for negative) reminiscent of a
/// classic equities market heatmap. Data, loading, error, and empty states
/// are all sourced from [AnalyticsProvider].
class MarketHeatMap extends StatelessWidget {
  const MarketHeatMap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AnalyticsProvider>();

    final cells = provider.heatMap;
    final isLoading = provider.isLoading('heatMap');
    final error = provider.errorFor('heatMap');
    final source = provider.sourceFor('heatMap');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(source: source),
          const SizedBox(height: 16),
          if (error != null) ...[
            _ErrorBanner(
              message: error,
              onRetry: provider.loadHeatMap,
            ),
            const SizedBox(height: 12),
          ],
          _Body(
            isLoading: isLoading,
            cells: cells,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.source});

  final AnalyticsSource? source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.grid_view_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Market heat map',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Last 24h activity',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        _SourceBadge(source: source),
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
    final isLive = source == AnalyticsSource.backend ||
        source == AnalyticsSource.contract;
    final label = isLive ? 'LIVE' : 'DEMO';
    final color = isLive ? AppTheme.successColor : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Heatmap falling back to sample data: $message',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              onRetry();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.isLoading,
    required this.cells,
    required this.theme,
  });

  final bool isLoading;
  final List<HeatMapCell>? cells;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (isLoading && (cells == null || cells!.isEmpty)) {
      return const _LoadingState();
    }

    final list = cells;
    if (list == null || list.isEmpty) {
      return const _EmptyState();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 268),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = _columnsForWidth(width);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: list
                .map((cell) => _HeatCell(cell: cell))
                .toList(growable: false),
          );
        },
      ),
    );
  }

  int _columnsForWidth(double width) {
    if (width < 500) return 2;
    if (width < 800) return 3;
    if (width < 1100) return 4;
    return 5;
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    // Render a tight grid of shimmer cells so the loading state previews the
    // real heat-map layout rather than a generic spinner.
    return SizedBox(
      height: 268,
      child: GridView.count(
        crossAxisCount: 4,
        childAspectRatio: 1.6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: List.generate(
          12,
          (_) => const ShimmerBox(height: 60, borderRadius: 10),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 268,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 36,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 10),
            Text(
              'No market activity in the last 24h',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.cell});

  final HeatMapCell cell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = cell.change24h;
    final magnitude = change.abs().clamp(0.0, 1.0);
    final isPositive = change >= 0;
    final tint = isPositive ? AppTheme.successColor : AppTheme.errorColor;
    final background =
        Color.lerp(theme.colorScheme.surface, tint, magnitude * 0.9) ??
            theme.colorScheme.surface;

    final useLightText = magnitude > 0.45;
    final primaryTextColor = useLightText
        ? Colors.white
        : theme.textTheme.bodyLarge?.color ?? Colors.white;
    final mutedTextColor = useLightText
        ? Colors.white.withOpacity(0.82)
        : theme.textTheme.bodySmall?.color ?? Colors.white70;

    final emphasize = magnitude > 0.5;
    final boxShadow = <BoxShadow>[
      if (emphasize)
        BoxShadow(
          color: theme.colorScheme.primary.withOpacity(0.25),
          blurRadius: 14,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
    ];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // TODO(phase4): navigate to market detail
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: emphasize
                  ? tint.withOpacity(0.7)
                  : theme.dividerColor,
              width: emphasize ? 1.2 : 1,
            ),
            boxShadow: boxShadow,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cell.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    isPositive
                        ? Icons.north_east_rounded
                        : Icons.south_east_rounded,
                    size: 16,
                    color: useLightText ? Colors.white : tint,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatChange(change),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: useLightText ? Colors.white : tint,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatUsdc(cell.totalUsdc)} · ${cell.bets} bets',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChange(double change) {
    final pct = (change * 100);
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  String _formatUsdc(double usdc) {
    if (usdc >= 1000000) {
      return '\$${(usdc / 1000000).toStringAsFixed(1)}M';
    }
    if (usdc >= 1000) {
      final thousands = usdc / 1000;
      final fixed = thousands >= 10
          ? thousands.toStringAsFixed(0)
          : thousands.toStringAsFixed(1);
      return '\$${fixed}k';
    }
    return '\$${usdc.toStringAsFixed(0)}';
  }
}

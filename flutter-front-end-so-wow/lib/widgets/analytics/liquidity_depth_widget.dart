import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../services/analytics_provider.dart';

/// Horizontal stacked-bar visualization of per-outcome liquidity for the
/// currently selected market. Reads depth data from [AnalyticsProvider] and
/// shows a total-liquidity stat tile followed by one bar per outcome. The
/// bar length is proportional to the largest `usdcInPool` across outcomes,
/// so the deepest pool visually dominates the card.
class LiquidityDepthWidget extends StatelessWidget {
  const LiquidityDepthWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AnalyticsProvider>(
      builder: (context, provider, _) {
        final depth = provider.depth;
        final isLoading = provider.isLoading('depth');
        final error = provider.errorFor('depth');
        final source = provider.sourceFor('depth');

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TitleRow(source: source),
                  const SizedBox(height: 12),
                  _buildBody(
                    context,
                    depth: depth,
                    isLoading: isLoading,
                    error: error,
                    onRetry: provider.loadDepth,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<DepthLevel>? depth,
    required bool isLoading,
    required String? error,
    required Future<void> Function() onRetry,
  }) {
    final theme = Theme.of(context);

    if (isLoading && (depth == null || depth.isEmpty)) {
      return SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (error != null && (depth == null || depth.isEmpty)) {
      return _ErrorBlock(message: error, onRetry: onRetry);
    }

    if (depth == null || depth.isEmpty) {
      return const _EmptyBlock();
    }

    final totalUsdc = depth.fold<double>(
      0,
      (acc, level) => acc + level.usdcInPool,
    );
    final maxUsdc = depth
        .map((l) => l.usdcInPool)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxIndex = _indexOfMax(depth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          _ErrorBlock(message: error, onRetry: onRetry, compact: true),
          const SizedBox(height: 12),
        ],
        _TotalTile(totalUsdc: totalUsdc),
        const SizedBox(height: 16),
        for (int i = 0; i < depth.length; i++) ...[
          _OutcomeRow(
            level: depth[i],
            color: _outcomeColor(context, depth[i].outcomeIndex),
            maxUsdc: maxUsdc,
            emphasized: i == maxIndex,
          ),
          if (i != depth.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  int _indexOfMax(List<DepthLevel> depth) {
    int idx = 0;
    double best = double.negativeInfinity;
    for (int i = 0; i < depth.length; i++) {
      if (depth[i].usdcInPool > best) {
        best = depth[i].usdcInPool;
        idx = i;
      }
    }
    return idx;
  }

  Color _outcomeColor(BuildContext context, int outcomeIndex) {
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
    ];
    return palette[outcomeIndex % palette.length];
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.source});

  final AnalyticsSource? source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.water_drop_outlined,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text('Liquidity depth', style: theme.textTheme.titleMedium),
        const Spacer(),
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
    final color = isLive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.totalUsdc});

  final double totalUsdc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Total USDC in pools: \$${_formatThousands(totalUsdc)}',
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.level,
    required this.color,
    required this.maxUsdc,
    required this.emphasized,
  });

  final DepthLevel level;
  final Color color;
  final double maxUsdc;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction =
        maxUsdc <= 0 ? 0.0 : (level.usdcInPool / maxUsdc).clamp(0.0, 1.0);
    final probabilityPct = (level.probability * 100).toStringAsFixed(1);

    final indexBadge = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(emphasized ? 0.9 : 0.7),
        shape: BoxShape.circle,
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Text(
        '${level.outcomeIndex}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            indexBadge,
            const SizedBox(width: 8),
            Text(
              'Outcome ${level.outcomeIndex}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (emphasized) ...[
              const SizedBox(width: 6),
              Icon(Icons.star_rounded, size: 14, color: color),
            ],
            const Spacer(),
            Text(
              '$probabilityPct%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: emphasized
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'USDC \$${_formatThousands(level.usdcInPool)} · '
          'Tokens: ${_formatThousands(level.tokensInPool)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_outlined,
              size: 36,
              color: theme.colorScheme.onSurface.withOpacity(0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Market has no pool liquidity',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final Future<void> Function() onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              compact ? 'Showing fallback data' : _shortenError(message),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    return compact
        ? content
        : SizedBox(
            height: 180,
            child: Center(child: content),
          );
  }

  String _shortenError(String message) {
    const prefix = 'Unable to load liquidity: ';
    final trimmed = message.replaceAll('Exception:', '').trim();
    if (trimmed.length > 120) {
      return '$prefix${trimmed.substring(0, 117)}...';
    }
    return '$prefix$trimmed';
  }
}

String _formatThousands(double value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$sign${buffer.toString()}';
}

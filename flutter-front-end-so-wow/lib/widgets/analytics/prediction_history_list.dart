import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/market_analytics.dart';
import '../../models/user_analytics.dart';
import '../../services/analytics_provider.dart';
import '../../theme/app_theme.dart';

/// Scrollable list of the user's past prediction-market actions
/// (buys, sells, claims, and resolve events). Reads from [AnalyticsProvider]
/// and renders loading / empty / error / success states consistent with the
/// other analytics cards. Supports a small action-type filter chip row.
class PredictionHistoryList extends StatefulWidget {
  const PredictionHistoryList({Key? key}) : super(key: key);

  @override
  State<PredictionHistoryList> createState() => _PredictionHistoryListState();
}

class _PredictionHistoryListState extends State<PredictionHistoryList> {
  static const String _filterAll = 'all';
  static const String _filterBuys = 'buy';
  static const String _filterSells = 'sell';
  static const String _filterClaims = 'claim';

  static const List<_FilterOption> _filters = <_FilterOption>[
    _FilterOption(value: _filterAll, label: 'All'),
    _FilterOption(value: _filterBuys, label: 'Buys'),
    _FilterOption(value: _filterSells, label: 'Sells'),
    _FilterOption(value: _filterClaims, label: 'Claims'),
  ];

  String _filter = _filterAll;

  List<PredictionHistoryItem> _applyFilter(
    List<PredictionHistoryItem> items,
  ) {
    if (_filter == _filterAll) return items;
    return items
        .where((PredictionHistoryItem it) => it.action == _filter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnalyticsProvider provider = context.watch<AnalyticsProvider>();

    final bool loading = provider.isLoading('predictions');
    final String? error = provider.errorFor('predictions');
    final AnalyticsSource? source = provider.sourceFor('predictions');
    final List<PredictionHistoryItem>? items = provider.predictions;

    // Loading state with no cached data — render the dedicated loading card.
    if (loading && (items == null || items.isEmpty)) {
      return _LoadingCard(theme: theme);
    }

    final List<PredictionHistoryItem> all = items ?? <PredictionHistoryItem>[];
    final List<PredictionHistoryItem> filtered = _applyFilter(all);

    Widget body;
    if (all.isEmpty) {
      if (error != null) {
        body = _ErrorState(
          message: error,
          onRetry: () => provider.loadPredictions(),
        );
      } else {
        body = const _EmptyState(
          message: 'No prediction history yet',
        );
      }
    } else if (filtered.isEmpty) {
      body = const _EmptyState(
        message: 'No entries match this filter',
      );
    } else {
      body = _HistoryList(items: filtered);
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 320, maxHeight: 500),
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
          _HeaderRow(
            filteredCount: filtered.length,
            totalCount: all.length,
            source: source,
          ),
          const SizedBox(height: 10),
          _FilterChipRow(
            filters: _filters,
            current: _filter,
            onSelected: (String value) {
              if (value == _filter) return;
              setState(() => _filter = value);
            },
          ),
          const SizedBox(height: 10),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey<String>(_bodyKey(all, filtered, error)),
                child: body,
              ),
            ),
          ),
          if (error != null && all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InlineErrorFooter(
                message: error,
                onRetry: () => provider.loadPredictions(),
              ),
            ),
        ],
      ),
    );
  }

  String _bodyKey(
    List<PredictionHistoryItem> all,
    List<PredictionHistoryItem> filtered,
    String? error,
  ) {
    if (all.isEmpty) return error != null ? 'error' : 'empty';
    if (filtered.isEmpty) return 'empty-filter-$_filter';
    return 'list-$_filter-${filtered.length}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.filteredCount,
    required this.totalCount,
    required this.source,
  });

  final int filteredCount;
  final int totalCount;
  final AnalyticsSource? source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color mutedColor = theme.colorScheme.onSurface.withOpacity(0.6);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.history, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Prediction history',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$filteredCount / $totalCount',
          style: theme.textTheme.labelSmall?.copyWith(
            color: mutedColor,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
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
    final ThemeData theme = Theme.of(context);
    final bool live = source == AnalyticsSource.backend;
    final Color fg =
        live ? theme.colorScheme.primary : theme.colorScheme.outline;
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

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip row
// ─────────────────────────────────────────────────────────────────────────────

class _FilterOption {
  const _FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.filters,
    required this.current,
    required this.onSelected,
  });

  final List<_FilterOption> filters;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((_FilterOption option) {
        final bool selected = option.value == current;
        return FilterChip(
          label: Text(option.label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onSelected(option.value),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          labelStyle: theme.textTheme.labelSmall?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: theme.colorScheme.surface,
          selectedColor: theme.colorScheme.primary,
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List body
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});

  final List<PredictionHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor,
        ),
        itemBuilder: (BuildContext context, int index) {
          return _HistoryTile(item: items[index]);
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final PredictionHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color mutedColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final _ActionVisual visual = _visualFor(theme, item.action);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // TODO(phase4): navigate to market detail
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: visual.backgroundColor,
                  child: Icon(
                    visual.icon,
                    size: 18,
                    color: visual.foregroundColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Market #${item.marketId} \u00B7 Outcome ${item.outcomeIndex}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _buildAmountLine(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _relative(item.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildAmountLine(PredictionHistoryItem it) {
    final String usdcSign = it.usdcDelta >= 0 ? '+' : '-';
    final String usdcAbs = it.usdcDelta.abs().toStringAsFixed(2);
    final String tokenSign = it.tokenDelta >= 0 ? '+' : '';
    final String tokenAmount = it.tokenDelta.toStringAsFixed(0);
    return '$usdcSign\$$usdcAbs \u00B7 $tokenSign$tokenAmount tokens';
  }
}

_ActionVisual _visualFor(ThemeData theme, String action) {
  switch (action) {
    case 'buy':
      return _ActionVisual(
        icon: Icons.arrow_upward,
        backgroundColor: AppTheme.successColor.withOpacity(0.85),
        foregroundColor: Colors.white,
      );
    case 'sell':
      return _ActionVisual(
        icon: Icons.arrow_downward,
        backgroundColor: AppTheme.errorColor.withOpacity(0.85),
        foregroundColor: Colors.white,
      );
    case 'claim':
      return _ActionVisual(
        icon: Icons.emoji_events,
        backgroundColor: AppTheme.highlightColor.withOpacity(0.85),
        foregroundColor: Colors.white,
      );
    case 'resolve':
      return _ActionVisual(
        icon: Icons.gavel,
        backgroundColor: theme.colorScheme.secondary.withOpacity(0.85),
        foregroundColor: theme.colorScheme.onSecondary,
      );
    default:
      return _ActionVisual(
        icon: Icons.help_outline,
        backgroundColor: theme.colorScheme.outline.withOpacity(0.4),
        foregroundColor: theme.colorScheme.onSurface,
      );
  }
}

class _ActionVisual {
  const _ActionVisual({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Relative timestamp helper
// ─────────────────────────────────────────────────────────────────────────────

String _relative(DateTime ts) {
  final DateTime now = DateTime.now();
  Duration diff = now.difference(ts);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

// ─────────────────────────────────────────────────────────────────────────────
// States: loading / empty / error
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.history, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Prediction history',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Expanded(
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color mutedColor = theme.colorScheme.onSurface.withOpacity(0.55);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 36, color: mutedColor),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 32,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load history',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
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
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.warning_amber_rounded,
          size: 14,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Showing cached data \u2014 $message',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

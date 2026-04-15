import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market_analytics.dart' show AnalyticsSource;
import '../services/social_provider.dart';
import '../widgets/social/leaderboard_entry.dart';

/// Production leaderboard screen.
///
/// Surfaces the top traders as ranked by [SocialProvider.leaderboardSort] over
/// the selected [SocialProvider.leaderboardPeriod]. Above the list:
///   • A muted caption ("Top traders · Updated …") reminds the user whether
///     they're looking at backend or demo data.
///   • Two [_SegmentedChips] rows — sort + period — each preceded by a muted
///     leading icon so the pair reads as labeled groups rather than floating
///     pills.
///   • A compact LIVE/DEMO [_SourceBadge] (same visual rule as the analytics
///     widgets) sitting between the chip row and the list.
///
/// Data-state dispatch mirrors the analytics screens:
///   • Null cache + fetch in flight → spinner.
///   • Hard error (no fallback rows loaded) → icon + retry button.
///   • Loaded-but-empty in the current window → empathy copy plus a shortcut
///     that switches the period to `alltime` and re-fetches.
///   • Populated → [ListView.separated] of [LeaderboardEntryWidget], wrapped
///     in a [RefreshIndicator] that calls [SocialProvider.loadLeaderboard].
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final entries = social.leaderboard;
    final error = social.errorFor('leaderboard');
    final source = social.sourceFor('leaderboard');
    final isBackend = source == AnalyticsSource.backend ||
        source == AnalyticsSource.contract;

    // Hard error: nothing loaded AND we have an error string. This gates the
    // rest of the screen; the chips, caption, and list are suppressed so the
    // user is drawn straight to the retry affordance.
    final hardError =
        error != null && (entries == null || entries.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCaption(isBackend: isBackend, hasSource: source != null),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
              const SizedBox(width: 6),
              _SegmentedChips(
                options: const ['pnl', 'winRate', 'volume'],
                labels: const ['P&L', 'Win rate', 'Volume'],
                selected: social.leaderboardSort,
                onChanged: (v) {
                  social.setLeaderboardSort(v);
                  social.loadLeaderboard();
                },
              ),
              const Spacer(),
              Icon(
                Icons.date_range_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
              const SizedBox(width: 6),
              _SegmentedChips(
                options: const ['weekly', 'monthly', 'alltime'],
                labels: const ['Week', 'Month', 'All'],
                selected: social.leaderboardPeriod,
                onChanged: (v) {
                  social.setLeaderboardPeriod(v);
                  social.loadLeaderboard();
                },
              ),
            ],
          ),
        ),
        if (!hardError && source != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _SourceBadge(source: source),
              ],
            ),
          ),
        Expanded(
          child: _buildBody(
            context,
            theme,
            social,
            entries,
            error,
            hardError,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    SocialProvider social,
    List<Map<String, dynamic>>? entries,
    String? error,
    bool hardError,
  ) {
    // Loading — nothing cached yet and a fetch is in flight. No error banner,
    // no chips duplication; just the spinner.
    if (entries == null && !hardError) {
      return const Center(child: CircularProgressIndicator());
    }

    // Hard error — no data to show. Single large retry card, theme-tinted.
    if (hardError) {
      return _ErrorState(
        message: error ?? 'Couldn\u2019t load leaderboard',
        onRetry: () => social.loadLeaderboard(),
      );
    }

    // Empty — loaded fine but the window has nothing. Suggest switching to
    // all-time, which is materially more likely to contain a result.
    if (entries != null && entries.isEmpty) {
      return _EmptyState(
        currentPeriod: social.leaderboardPeriod,
        onSwitchAllTime: () {
          social.setLeaderboardPeriod('alltime');
          social.loadLeaderboard();
        },
      );
    }

    // Success — populated list. Wrapped in a [RefreshIndicator]; pull-down
    // invokes the same loader as the chip selectors and the error retry.
    final list = entries!;
    return RefreshIndicator(
      onRefresh: () => social.loadLeaderboard(),
      color: theme.colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => LeaderboardEntryWidget(
          entry: list[i],
          sortBy: social.leaderboardSort,
        ),
      ),
    );
  }
}

/// "Top traders · Updated just now" caption above the chip row. The trailing
/// phrase flexes with the data source so the user knows whether they're
/// staring at real numbers or the seeded fallback set.
class _HeaderCaption extends StatelessWidget {
  final bool isBackend;
  final bool hasSource;
  const _HeaderCaption({
    required this.isBackend,
    required this.hasSource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suffix = !hasSource
        ? 'loading\u2026'
        : isBackend
            ? 'just now'
            : 'demo data';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        'Top traders \u00b7 Updated $suffix',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Compact LIVE/DEMO pill. Matches the visual rule used by the analytics
/// widgets: backend/contract sources glow primary, dummy fallbacks render in
/// the muted-error tone so the distinction is unmissable but not alarming.
class _SourceBadge extends StatelessWidget {
  final AnalyticsSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = source == AnalyticsSource.backend ||
        source == AnalyticsSource.contract;
    final label = isLive ? 'LIVE' : 'DEMO';
    final color =
        isLive ? theme.colorScheme.primary : theme.colorScheme.error;
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

/// Hard-error affordance. Centered icon + copy + a filled retry button that
/// re-triggers [SocialProvider.loadLeaderboard].
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: theme.colorScheme.error.withOpacity(0.8),
            ),
            const SizedBox(height: 12),
            Text(
              'Couldn\u2019t load leaderboard',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-window affordance. Instead of a dead-end caption, nudge the user
/// toward the `alltime` period — the bucket most likely to contain data.
class _EmptyState extends StatelessWidget {
  final String currentPeriod;
  final VoidCallback onSwitchAllTime;
  const _EmptyState({
    required this.currentPeriod,
    required this.onSwitchAllTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlreadyAllTime = currentPeriod == 'alltime';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 42,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              isAlreadyAllTime
                  ? 'No traders on the board yet'
                  : 'No traders in this window \u2014 try All-time?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
            if (!isAlreadyAllTime) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onSwitchAllTime,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Switch to All-time'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedChips extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SegmentedChips({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = options[i] == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: isSelected ? null : () => onChanged(options[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    labels[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/social_provider.dart';
import '../widgets/social/leaderboard_entry.dart';

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
        Expanded(
          child: entries == null
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? Center(
                      child: Text(
                        'No activity in this period yet',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => LeaderboardEntryWidget(
                        entry: entries[i],
                        sortBy: social.leaderboardSort,
                      ),
                    ),
        ),
      ],
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

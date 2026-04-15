import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market_analytics.dart';
import '../services/social_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/design_system/empty_state.dart';
import '../widgets/design_system/shimmer_box.dart';
import '../widgets/social/activity_feed_item.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({Key? key}) : super(key: key);

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletService>();
      final social = context.read<SocialProvider>();
      social.setAddress(wallet.walletAddress);
      social.loadGlobalFeed();
      social.loadFollowingFeed();
      social.loadYouFeed();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Global'),
            Tab(text: 'Following'),
            Tab(text: 'You'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _FeedListView(scope: 'global'),
              _FeedListView(scope: 'following'),
              _FeedListView(scope: 'you'),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedListView extends StatelessWidget {
  final String scope;
  const _FeedListView({required this.scope});

  String get _providerKey {
    switch (scope) {
      case 'following':
        return 'followingFeed';
      case 'you':
        return 'youFeed';
      case 'global':
      default:
        return 'globalFeed';
    }
  }

  Future<void> _reload(SocialProvider social) {
    switch (scope) {
      case 'following':
        return social.loadFollowingFeed();
      case 'you':
        return social.loadYouFeed();
      case 'global':
      default:
        return social.loadGlobalFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final wallet = context.watch<WalletService>();

    // Wallet gating for Following and You tabs.
    if ((scope == 'following' || scope == 'you') &&
        wallet.walletAddress == null) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        headline: scope == 'following' ? 'Follow your traders' : 'Your timeline',
        message: scope == 'following'
            ? 'Connect your wallet to see activity from the traders you follow.'
            : 'Connect your wallet to see your own bet history and comments.',
        tint: theme.colorScheme.primary,
      );
    }

    final items = scope == 'global'
        ? social.globalFeed
        : scope == 'following'
            ? social.followingFeed
            : social.youFeed;
    final error = social.errorFor(_providerKey);

    // Error state: error present and no data to show.
    if (error != null && (items == null || items.isEmpty)) {
      return EmptyState(
        icon: Icons.sensors_off_rounded,
        headline: "Feed unavailable",
        message: 'We couldn\'t reach the activity feed. Tap retry to try again.',
        tint: theme.colorScheme.error,
        action: FilledButton.icon(
          onPressed: () => _reload(social),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      );
    }

    // Loading state: shimmer placeholder rows that feel like instruments
    // warming up, replaces the generic CircularProgressIndicator.
    if (items == null) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: ShimmerList(count: 6, rowHeight: 58, gap: 8),
      );
    }

    final source = social.sourceFor(_providerKey);
    final badge = _SourceBadge(source: source);

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _reload(social),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(10),
          children: [
            Align(alignment: Alignment.centerLeft, child: badge),
            const SizedBox(height: 8),
            EmptyState(
              icon: scope == 'following'
                  ? Icons.rss_feed_rounded
                  : Icons.waves_rounded,
              headline: scope == 'following'
                  ? 'No one to watch yet'
                  : scope == 'you'
                      ? 'No moves yet'
                      : 'The wire is quiet',
              message: scope == 'following'
                  ? 'Follow traders on their profile to populate this feed.'
                  : scope == 'you'
                      ? 'Place your first bet to see your history here.'
                      : 'No market activity in the last hour — check back soon.',
              tint: theme.colorScheme.primary,
              minHeight: 280,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _reload(social),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Align(alignment: Alignment.centerLeft, child: badge);
          }
          return ActivityFeedItemWidget(item: items[i - 1]);
        },
      ),
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
    final isLive = source == AnalyticsSource.backend;
    final Color bg = isLive
        ? theme.colorScheme.primary.withOpacity(0.14)
        : theme.colorScheme.onSurface.withOpacity(0.08);
    final Color fg = isLive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.65);
    final String label = isLive ? 'LIVE' : 'DEMO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

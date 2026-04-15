import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market_analytics.dart';
import '../services/social_provider.dart';
import '../services/wallet_service.dart';
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Connect wallet to see your follows',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                "Couldn't load feed",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _reload(social),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (items == null) {
      return const Center(child: CircularProgressIndicator());
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  scope == 'following'
                      ? 'Follow users to see their activity here'
                      : 'No activity yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
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

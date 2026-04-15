import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            children: [
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

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final items = scope == 'global'
        ? social.globalFeed
        : scope == 'following'
            ? social.followingFeed
            : social.youFeed;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          scope == 'following' ? 'Follow users to see their activity here' : 'No activity yet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => ActivityFeedItemWidget(item: items[i]),
    );
  }
}

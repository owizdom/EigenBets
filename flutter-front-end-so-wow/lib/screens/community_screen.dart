import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/social_provider.dart';
import '../services/wallet_service.dart';
import 'activity_feed_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletService>();
      final social = context.read<SocialProvider>();
      social.setAddress(wallet.walletAddress);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            tooltip: 'Your profile',
            icon: const Icon(Icons.person_outline),
            onPressed: _openProfile,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.bolt_outlined), text: 'Feed'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ActivityFeedScreen(),
          LeaderboardScreen(),
        ],
      ),
    );
  }
}

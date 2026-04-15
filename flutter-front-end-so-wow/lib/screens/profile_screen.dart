import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/social_provider.dart';
import '../services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletService>();
      final social = context.read<SocialProvider>();
      social.setAddress(wallet.walletAddress);
      social.loadSelfProfile();
      social.loadYouFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final profile = social.selfProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              social.loadSelfProfile();
              social.loadYouFeed();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.shortName,
                              style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          SelectableText(profile.walletAddress,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              )),
                          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(profile.bio!, style: theme.textTheme.bodyMedium),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _statTile('Bets', '${profile.stats.totalBets}', theme),
                              _statTile('Wins', '${profile.stats.wins}', theme),
                              _statTile('Losses', '${profile.stats.losses}', theme),
                              _statTile(
                                'Win rate',
                                '${(profile.stats.winRate * 100).toStringAsFixed(1)}%',
                                theme,
                              ),
                              _statTile('Followers', '${profile.followerCount}', theme),
                              _statTile('Following', '${profile.followingCount}', theme),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Recent activity', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _ActivityShell(),
                ],
              ),
            ),
    );
  }

  Widget _statTile(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              )),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ActivityShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Your recent activity will appear here.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

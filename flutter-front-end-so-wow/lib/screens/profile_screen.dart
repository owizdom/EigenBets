import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/social_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/social/activity_feed_item.dart';

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
      if (!mounted) return;
      final wallet = context.read<WalletService>();
      final social = context.read<SocialProvider>();
      social.setAddress(wallet.walletAddress);
      if (wallet.walletAddress != null) {
        social.loadSelfProfile();
        social.loadYouFeed();
      }
    });
  }

  bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (!(lower.startsWith('http://') || lower.startsWith('https://'))) {
      return false;
    }
    final parsed = Uri.tryParse(url);
    return parsed != null && parsed.hasAuthority;
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final social = context.read<SocialProvider>();
    final profile = social.selfProfile;
    if (profile == null) return;

    final displayCtrl = TextEditingController(text: profile.displayName ?? '');
    final avatarCtrl = TextEditingController(text: profile.avatarUrl ?? '');
    final bioCtrl = TextEditingController(text: profile.bio ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return _EditProfileDialog(
          displayCtrl: displayCtrl,
          avatarCtrl: avatarCtrl,
          bioCtrl: bioCtrl,
          onSave: () async {
            await social.updateSelf(
              displayName: displayCtrl.text.trim(),
              avatarUrl: avatarCtrl.text.trim(),
              bio: bioCtrl.text.trim(),
            );
            if (social.errorFor('updateSelf') == null && ctx.mounted) {
              Navigator.of(ctx).pop();
            }
          },
        );
      },
    );

    displayCtrl.dispose();
    avatarCtrl.dispose();
    bioCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final wallet = context.watch<WalletService>();
    final profile = social.selfProfile;
    final walletAddress = wallet.walletAddress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (walletAddress != null && profile != null)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditDialog(context),
            ),
          if (walletAddress != null)
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
      body: _buildBody(context, theme, social, walletAddress, profile),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    SocialProvider social,
    String? walletAddress,
    dynamic profile,
  ) {
    if (walletAddress == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 56,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Connect your wallet to see your profile',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Head back to the home tab to connect.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading profile\u2026',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAvatar(theme, profile),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profile.shortName,
                              style: theme.textTheme.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              profile.walletAddress,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                      _statTile(
                          'Followers', '${profile.followerCount}', theme),
                      _statTile(
                          'Following', '${profile.followingCount}', theme),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Recent activity', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildActivitySection(theme, social),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, dynamic profile) {
    final avatarUrl = profile.avatarUrl as String?;
    if (_isHttpUrl(avatarUrl)) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    final String shortName = profile.shortName as String;
    final String initial =
        shortName.isNotEmpty ? shortName.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
      child: Text(
        initial,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActivitySection(ThemeData theme, SocialProvider social) {
    final feed = social.youFeed;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: SizedBox(
        height: 400,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildFeedContent(theme, feed),
        ),
      ),
    );
  }

  Widget _buildFeedContent(ThemeData theme, List<dynamic>? feed) {
    if (feed == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              "You haven't made any bets or comments yet",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: feed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => ActivityFeedItemWidget(item: feed[i]),
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

class _EditProfileDialog extends StatelessWidget {
  final TextEditingController displayCtrl;
  final TextEditingController avatarCtrl;
  final TextEditingController bioCtrl;
  final Future<void> Function() onSave;

  const _EditProfileDialog({
    Key? key,
    required this.displayCtrl,
    required this.avatarCtrl,
    required this.bioCtrl,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final saving = social.isLoading('updateSelf');
    final error = social.errorFor('updateSelf');

    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: displayCtrl,
              maxLength: 40,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'How should we call you?',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: avatarCtrl,
              maxLength: 500,
              enabled: !saving,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Avatar URL',
                hintText: 'https://…',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: bioCtrl,
              maxLength: 280,
              enabled: !saving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell the world about you',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : onSave,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

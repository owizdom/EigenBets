import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/social_provider.dart';
import '../widgets/social/follow_button.dart';

class PublicProfileScreen extends StatefulWidget {
  final String address;
  const PublicProfileScreen({Key? key, required this.address}) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _initialLoadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialProvider>().loadPublicProfile(widget.address);
      setState(() => _initialLoadRequested = true);
    });
  }

  bool _isHttpUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  String _avatarInitial(UserProfile profile) {
    final name = profile.shortName;
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final profile = social.publicProfiles[widget.address.toLowerCase()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SocialProvider>().loadPublicProfile(widget.address);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profile == null
          ? _buildPendingState(theme)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(theme, profile),
                  const SizedBox(height: 16),
                  Text('Recent activity', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildActivityPlaceholder(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildPendingState(ThemeData theme) {
    if (!_initialLoadRequested) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Loading…', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Profile unavailable',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, UserProfile profile) {
    return Card(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(theme, profile),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.shortName,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        profile.walletAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FollowButton(targetAddress: profile.walletAddress),
              ],
            ),
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
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
    );
  }

  Widget _buildAvatar(ThemeData theme, UserProfile profile) {
    if (_isHttpUrl(profile.avatarUrl)) {
      return CircleAvatar(
        radius: 36,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
        backgroundImage: NetworkImage(profile.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
      child: Text(
        _avatarInitial(profile),
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActivityPlaceholder(ThemeData theme) {
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
          'Recent activity from this trader will appear here soon.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
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
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

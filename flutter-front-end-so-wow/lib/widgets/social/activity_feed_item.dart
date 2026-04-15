import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_item.dart';
import '../../services/social_provider.dart';
import '../../theme/app_theme.dart';
import '../design_system/terminal_palette.dart';

/// Activity-feed row upgraded for the trading-terminal aesthetic.
///
///   - Entrance: 320ms fade + 6px translate-up, triggered once on first build
///     (stateful so it survives list reordering).
///   - Followed users get a cyan ring around their avatar; otherwise a muted
///     outline. Ring colour matches the SocialProvider state live.
///   - Type glyphs use LED accent colors (emerald/red/violet/cyan/amber) with
///     a soft halo, not plain icons on a tinted square.
///   - Headline in slightly tighter body text; metadata in monospace.
///   - Relative timestamp right-aligned in a thin mono numeric — feels like
///     a terminal timestamp column.
class ActivityFeedItemWidget extends StatefulWidget {
  final ActivityItem item;
  const ActivityFeedItemWidget({Key? key, required this.item}) : super(key: key);

  @override
  State<ActivityFeedItemWidget> createState() => _ActivityFeedItemWidgetState();
}

class _ActivityFeedItemWidgetState extends State<ActivityFeedItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _IconSpec spec = _iconFor(widget.item.type);
    final headline = _headline(widget.item);
    final detail = _detail(widget.item);

    // Followed-ring colour decided via SocialProvider.
    final social = context.watch<SocialProvider>();
    final isFollowed = social.selfProfile?.following
            .contains(widget.item.actorWallet.toLowerCase()) ??
        false;

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final t = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic)
            .value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 6),
            child: child,
          ),
        );
      },
      child: _Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AvatarRing(
              seed: widget.item.actorLabel,
              avatarUrl: widget.item.actorAvatarUrl,
              ring: isFollowed
                  ? TerminalPalette.ledCyan
                  : theme.dividerColor,
              ringOn: isFollowed,
            ),
            const SizedBox(width: 10),
            _GlyphBadge(spec: spec),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TerminalPalette.mono(
                        context,
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relative(widget.item.createdAt),
              style: TerminalPalette.microCap(
                context,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _IconSpec _iconFor(ActivityType type) {
    switch (type) {
      case ActivityType.betPlaced:
        return const _IconSpec(Icons.north_east, TerminalPalette.ledGreen);
      case ActivityType.betSold:
        return const _IconSpec(Icons.south_west, TerminalPalette.ledRed);
      case ActivityType.winningsClaimed:
        return const _IconSpec(Icons.emoji_events, TerminalPalette.ledAmber);
      case ActivityType.marketResolved:
        return const _IconSpec(Icons.gavel_rounded, TerminalPalette.ledViolet);
      case ActivityType.commentPosted:
        return const _IconSpec(
            Icons.mode_comment_outlined, AppTheme.primaryColor);
      case ActivityType.userFollowed:
        return const _IconSpec(
            Icons.rss_feed_rounded, TerminalPalette.ledCyan);
      case ActivityType.unknown:
        return const _IconSpec(Icons.circle_outlined, AppTheme.textSecondary);
    }
  }

  String _headline(ActivityItem item) {
    final actor = item.actorLabel;
    final market = item.marketId ?? '—';
    switch (item.type) {
      case ActivityType.betPlaced:
        final idx = item.metadata['outcomeIndex'];
        final suffix = idx is num ? ' · outcome ${idx.toInt()}' : '';
        return '$actor placed a bet on market #$market$suffix';
      case ActivityType.betSold:
        return '$actor exited position in market #$market';
      case ActivityType.winningsClaimed:
        return '$actor claimed winnings from market #$market';
      case ActivityType.marketResolved:
        return 'Market #$market resolved';
      case ActivityType.commentPosted:
        return '$actor commented on market #$market';
      case ActivityType.userFollowed:
        return '$actor started following ${_shortWallet(item.targetWallet)}';
      case ActivityType.unknown:
        return '$actor had activity';
    }
  }

  String? _detail(ActivityItem item) {
    final delta = item.metadata['usdcDelta'];
    if (delta is num) return _formatUsdc(delta.toDouble());
    return null;
  }

  String _formatUsdc(double value) {
    final sign = value >= 0 ? '+' : '-';
    final abs = value.abs();
    if (abs >= 1000) {
      return '$sign\$${(abs / 1000).toStringAsFixed(2)}K USDC';
    }
    return '$sign\$${abs.toStringAsFixed(2)} USDC';
  }

  String _shortWallet(String? wallet) {
    if (wallet == null || wallet.isEmpty) return 'a user';
    if (wallet.length < 10) return wallet;
    return '${wallet.substring(0, 6)}…${wallet.substring(wallet.length - 4)}';
  }

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 45) return 'NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M';
    if (diff.inHours < 24) return '${diff.inHours}H';
    if (diff.inDays < 7) return '${diff.inDays}D';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}W';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}MO';
    return '${(diff.inDays / 365).floor()}Y';
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor, width: 0.8),
      ),
      child: child,
    );
  }
}

class _GlyphBadge extends StatelessWidget {
  final _IconSpec spec;
  const _GlyphBadge({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: spec.color.withOpacity(0.12),
        border: Border.all(color: spec.color.withOpacity(0.42), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: spec.color.withOpacity(0.22),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(spec.icon, size: 15, color: spec.color),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String seed;
  final String? avatarUrl;
  final Color ring;
  final bool ringOn;

  const _AvatarRing({
    required this.seed,
    required this.avatarUrl,
    required this.ring,
    required this.ringOn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = seed.isNotEmpty ? seed.substring(0, 1).toUpperCase() : '?';
    final avatar = (avatarUrl != null && avatarUrl!.startsWith('http'))
        ? CircleAvatar(
            radius: 14,
            backgroundImage: NetworkImage(avatarUrl!),
            backgroundColor: AppTheme.cardColor,
          )
        : CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.18),
            child: Text(
              initial,
              style: TerminalPalette.mono(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          );
    return Container(
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ring,
          width: ringOn ? 1.4 : 0.8,
        ),
        boxShadow: ringOn
            ? [
                BoxShadow(
                  color: ring.withOpacity(0.45),
                  blurRadius: 7,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: avatar,
    );
  }
}

class _IconSpec {
  final IconData icon;
  final Color color;
  const _IconSpec(this.icon, this.color);
}

import 'package:flutter/material.dart';
import '../../models/activity_item.dart';
import '../../theme/app_theme.dart';

class ActivityFeedItemWidget extends StatelessWidget {
  final ActivityItem item;
  const ActivityFeedItemWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _IconSpec spec = _iconFor(item.type, theme);
    final String headline = _headline(item);
    final String? detail = _detail(item);

    return Card(
      color: theme.colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO(phase5): navigate to market/profile
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: spec.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(spec.icon, size: 18, color: spec.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                _relative(item.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _IconSpec _iconFor(ActivityType type, ThemeData theme) {
    switch (type) {
      case ActivityType.betPlaced:
        return _IconSpec(Icons.trending_up, AppTheme.successColor);
      case ActivityType.betSold:
        return _IconSpec(Icons.trending_down, AppTheme.errorColor);
      case ActivityType.winningsClaimed:
        return _IconSpec(Icons.emoji_events, AppTheme.highlightColor);
      case ActivityType.marketResolved:
        return _IconSpec(Icons.gavel, theme.colorScheme.secondary);
      case ActivityType.commentPosted:
        return _IconSpec(Icons.chat_bubble_outline, theme.colorScheme.primary);
      case ActivityType.userFollowed:
        return _IconSpec(
          Icons.person_add_alt_1_outlined,
          theme.colorScheme.primary,
        );
      case ActivityType.unknown:
        return _IconSpec(
          Icons.circle,
          theme.colorScheme.onSurface.withOpacity(0.4),
        );
    }
  }

  String _headline(ActivityItem item) {
    final String actor = item.actorLabel;
    final String market = item.marketId ?? '-';
    switch (item.type) {
      case ActivityType.betPlaced:
        final outcome = item.metadata['outcomeIndex'];
        final suffix = outcome is num ? ' (outcome ${outcome.toInt()})' : '';
        return '$actor placed a bet on market #$market$suffix';
      case ActivityType.betSold:
        return '$actor sold tokens in market #$market';
      case ActivityType.winningsClaimed:
        return '$actor claimed winnings in market #$market';
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
    if (delta is num) {
      return _formatUsdc(delta.toDouble());
    }
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
    if (diff.inSeconds < 45) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _IconSpec {
  final IconData icon;
  final Color color;
  const _IconSpec(this.icon, this.color);
}

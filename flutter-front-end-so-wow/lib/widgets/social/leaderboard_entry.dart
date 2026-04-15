import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/social_provider.dart';
import '../../theme/app_theme.dart';
import './follow_button.dart';

/// A single row in the social leaderboard list.
///
/// Renders rank (with medal icons for the top three), an avatar, a
/// display-name + shortened wallet block, a trailing metric that flexes on
/// [sortBy], and an optional [FollowButton]. The entry map mirrors the shape
/// produced by [SocialProvider.loadLeaderboard].
class LeaderboardEntryWidget extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String sortBy; // 'pnl' | 'winRate' | 'volume'
  const LeaderboardEntryWidget({
    Key? key,
    required this.entry,
    required this.sortBy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final rank = _asInt(entry['rank']);
    final wallet = (entry['user'] as String?) ?? '';
    final displayName = (entry['displayName'] as String?)?.trim();
    final resolvedName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : _shortenWallet(wallet);
    final avatarUrl = entry['avatarUrl'] as String?;

    final currentAddress = context.watch<SocialProvider>().currentAddress;
    final normalizedWallet = wallet.toLowerCase();
    final showFollow = wallet.isNotEmpty &&
        (currentAddress == null || currentAddress != normalizedWallet);

    return Card(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              child: _RankBadge(rank: rank, theme: theme),
            ),
            const SizedBox(width: 8),
            _Avatar(
              avatarUrl: avatarUrl,
              seed: resolvedName,
              colors: colors,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    resolvedName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortenWallet(wallet),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _TrailingMetric(
              entry: entry,
              sortBy: sortBy,
              theme: theme,
            ),
            if (showFollow) ...[
              const SizedBox(width: 10),
              FollowButton(targetAddress: wallet),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rank column: medal icon for the top three, `#N` text otherwise.
class _RankBadge extends StatelessWidget {
  final int rank;
  final ThemeData theme;
  const _RankBadge({required this.rank, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (rank >= 1 && rank <= 3) {
      final Color medalColor;
      switch (rank) {
        case 1:
          medalColor = AppTheme.warningColor;
          break;
        case 2:
          medalColor = theme.colorScheme.onSurface;
          break;
        default:
          medalColor = AppTheme.highlightColor;
      }
      return Center(
        child: Icon(
          Icons.emoji_events,
          color: medalColor,
          size: 22,
          semanticLabel: 'Rank $rank',
        ),
      );
    }
    return Center(
      child: Text(
        '#$rank',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Circular avatar, falling back to a coloured bubble with the first initial.
class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String seed;
  final ColorScheme colors;
  const _Avatar({
    required this.avatarUrl,
    required this.seed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: colors.surfaceVariant,
        backgroundImage: NetworkImage(url),
      );
    }
    final initial = seed.isNotEmpty ? seed.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: colors.primary.withOpacity(0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Right-aligned metric whose formatting depends on the active sort.
class _TrailingMetric extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String sortBy;
  final ThemeData theme;
  const _TrailingMetric({
    required this.entry,
    required this.sortBy,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    final String text;
    final Color color;
    final FontWeight weight;

    switch (sortBy) {
      case 'winRate':
        final rate = _asDouble(entry['winRate']);
        text = '${(rate * 100).toStringAsFixed(1)}%';
        color = colors.primary;
        weight = FontWeight.w700;
        break;
      case 'volume':
        final vol = _asDouble(entry['totalVolume']);
        text = '\$${_compact(vol)}';
        color = colors.onSurface;
        weight = FontWeight.w700;
        break;
      case 'pnl':
      default:
        final pnl = _asDouble(entry['totalPnl']);
        if (pnl >= 0) {
          text = '+\$${pnl.toStringAsFixed(2)}';
          color = AppTheme.successColor;
        } else {
          text = '-\$${pnl.abs().toStringAsFixed(2)}';
          color = AppTheme.errorColor;
        }
        weight = FontWeight.w700;
    }

    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ── helpers ────────────────────────────────────────────────────────────────

String _shortenWallet(String wallet) {
  if (wallet.length <= 10) return wallet;
  final first = wallet.substring(0, 6);
  final last = wallet.substring(wallet.length - 4);
  return '$first\u2026$last';
}

String _compact(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 1e9) {
    return '$sign${(abs / 1e9).toStringAsFixed(abs >= 1e10 ? 1 : 2)}B';
  }
  if (abs >= 1e6) {
    return '$sign${(abs / 1e6).toStringAsFixed(abs >= 1e7 ? 1 : 2)}M';
  }
  if (abs >= 1e3) {
    return '$sign${(abs / 1e3).toStringAsFixed(abs >= 1e4 ? 1 : 2)}k';
  }
  return '$sign${abs.toStringAsFixed(2)}';
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

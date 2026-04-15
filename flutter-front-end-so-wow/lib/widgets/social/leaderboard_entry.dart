import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/social_provider.dart';
import '../../theme/app_theme.dart';
import '../design_system/terminal_palette.dart';
import 'follow_button.dart';

/// A single leaderboard row with the trading-terminal look.
/// Top-3 rows receive a continuous shimmer sweep across the medal icon —
/// the only high-motion element on the screen, reserved for conviction.
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

    final social = context.watch<SocialProvider>();
    final currentAddress = social.currentAddress;
    final normalizedWallet = wallet.toLowerCase();
    final showFollow = wallet.isNotEmpty &&
        (currentAddress == null || currentAddress != normalizedWallet);
    final isFollowed = social.selfProfile?.following.contains(normalizedWallet) ?? false;

    final isTop3 = rank >= 1 && rank <= 3;
    final rowTint = switch (rank) {
      1 => TerminalPalette.ledAmber,
      2 => colors.onSurface,
      3 => TerminalPalette.ledViolet,
      _ => AppTheme.textSecondary,
    };

    return Container(
      decoration: BoxDecoration(
        color: isTop3
            ? rowTint.withOpacity(0.05)
            : AppTheme.surfaceColor.withOpacity(0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTop3
              ? rowTint.withOpacity(0.28)
              : theme.dividerColor,
          width: isTop3 ? 1 : 0.8,
        ),
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: rowTint.withOpacity(0.09),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: _RankBadge(rank: rank, color: rowTint, isTop3: isTop3),
          ),
          const SizedBox(width: 8),
          _Avatar(
            avatarUrl: avatarUrl,
            seed: resolvedName,
            followed: isFollowed,
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
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _shortenWallet(wallet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TerminalPalette.mono(
                    context,
                    fontSize: 10,
                    color: colors.onSurface.withOpacity(0.5),
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
    );
  }
}

/// Rank column: animated medal for top-3, tabular `#N` otherwise.
class _RankBadge extends StatefulWidget {
  final int rank;
  final Color color;
  final bool isTop3;
  const _RankBadge({
    required this.rank,
    required this.color,
    required this.isTop3,
  });

  @override
  State<_RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: TerminalPalette.medalSweep,
    );
    if (widget.isTop3) _sweep.repeat();
  }

  @override
  void didUpdateWidget(covariant _RankBadge old) {
    super.didUpdateWidget(old);
    if (widget.isTop3 && !_sweep.isAnimating) _sweep.repeat();
    if (!widget.isTop3 && _sweep.isAnimating) _sweep.stop();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTop3) {
      return Center(
        child: Text(
          '#${widget.rank}',
          style: TerminalPalette.mono(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.color,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        return SizedBox(
          width: 40,
          height: 28,
          child: CustomPaint(
            painter: _MedalSweepPainter(
              color: widget.color,
              progress: _sweep.value,
              rank: widget.rank,
            ),
            child: Center(
              child: Icon(
                Icons.emoji_events_rounded,
                color: widget.color,
                size: 20,
                shadows: [
                  Shadow(
                    color: widget.color.withOpacity(0.75),
                    blurRadius: 9,
                  ),
                ],
                semanticLabel: 'Rank ${widget.rank}',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MedalSweepPainter extends CustomPainter {
  final Color color;
  final double progress; // 0..1
  final int rank;

  _MedalSweepPainter({
    required this.color,
    required this.progress,
    required this.rank,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // A diagonal light-sweep band traversing left→right over the badge.
    final sweepWidth = size.width * 0.55;
    final totalPath = size.width + sweepWidth;
    final x = -sweepWidth + totalPath * progress;
    final rect = Rect.fromLTWH(x, 0, sweepWidth, size.height);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        color.withOpacity(0.45),
        Colors.white.withOpacity(0.85),
        color.withOpacity(0.45),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    ).createShader(rect);

    canvas.save();
    // Diagonal rotation for a more instrument-dashboard feel.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 12);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MedalSweepPainter old) =>
      old.color != color || old.progress != progress || old.rank != rank;
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String seed;
  final bool followed;
  const _Avatar({
    required this.avatarUrl,
    required this.seed,
    required this.followed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = avatarUrl?.trim();
    final avatar = (url != null && url.startsWith('http'))
        ? CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.surfaceVariant,
            backgroundImage: NetworkImage(url),
          )
        : CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Text(
              seed.isNotEmpty ? seed.substring(0, 1).toUpperCase() : '?',
              style: TerminalPalette.mono(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          );
    return Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: followed ? TerminalPalette.ledCyan : theme.dividerColor,
          width: followed ? 1.4 : 0.8,
        ),
        boxShadow: followed
            ? [
                BoxShadow(
                  color: TerminalPalette.ledCyan.withOpacity(0.45),
                  blurRadius: 7,
                ),
              ]
            : null,
      ),
      child: avatar,
    );
  }
}

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

    switch (sortBy) {
      case 'winRate':
        final rate = _asDouble(entry['winRate']);
        text = '${(rate * 100).toStringAsFixed(1)}%';
        color = colors.primary;
        break;
      case 'volume':
        final vol = _asDouble(entry['totalVolume']);
        text = '\$${_compact(vol)}';
        color = colors.onSurface;
        break;
      case 'pnl':
      default:
        final pnl = _asDouble(entry['totalPnl']);
        if (pnl >= 0) {
          text = '+\$${pnl.toStringAsFixed(2)}';
          color = TerminalPalette.ledGreen;
        } else {
          text = '-\$${pnl.abs().toStringAsFixed(2)}';
          color = TerminalPalette.ledRed;
        }
    }

    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ── helpers ────────────────────────────────────────────────────────────────

String _shortenWallet(String wallet) {
  if (wallet.isEmpty) return '—';
  if (wallet.length <= 10) return wallet;
  return '${wallet.substring(0, 6)}…${wallet.substring(wallet.length - 4)}';
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
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _compact(double n) {
  if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}

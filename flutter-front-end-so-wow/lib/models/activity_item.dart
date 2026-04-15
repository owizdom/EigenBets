import 'dart:math';

enum ActivityType {
  betPlaced,
  betSold,
  winningsClaimed,
  marketResolved,
  commentPosted,
  userFollowed,
  unknown;

  static ActivityType fromWire(String? s) {
    switch (s) {
      case 'bet_placed': return ActivityType.betPlaced;
      case 'bet_sold': return ActivityType.betSold;
      case 'winnings_claimed': return ActivityType.winningsClaimed;
      case 'market_resolved': return ActivityType.marketResolved;
      case 'comment_posted': return ActivityType.commentPosted;
      case 'user_followed': return ActivityType.userFollowed;
      default: return ActivityType.unknown;
    }
  }
}

class ActivityItem {
  final String id;
  final ActivityType type;
  final String actorWallet;
  final String? actorDisplayName;
  final String? actorAvatarUrl;
  final String? marketId;
  final String? targetWallet;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.actorWallet,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.marketId,
    this.targetWallet,
    this.metadata = const {},
    required this.createdAt,
  });

  String get actorLabel {
    if (actorDisplayName != null && actorDisplayName!.isNotEmpty) {
      return actorDisplayName!;
    }
    if (actorWallet.length < 10) return actorWallet;
    return '${actorWallet.substring(0, 6)}…${actorWallet.substring(actorWallet.length - 4)}';
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: (json['id'] ?? '').toString(),
      type: ActivityType.fromWire(json['type'] as String?),
      actorWallet: (json['actorWallet'] ?? '').toString().toLowerCase(),
      actorDisplayName: json['actorDisplayName'] as String?,
      actorAvatarUrl: json['actorAvatarUrl'] as String?,
      marketId: json['marketId']?.toString(),
      targetWallet: json['targetWallet']?.toString().toLowerCase(),
      metadata: (json['metadata'] is Map<String, dynamic>)
          ? json['metadata'] as Map<String, dynamic>
          : const {},
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class DummyActivity {
  static List<ActivityItem> feed({int count = 12}) {
    final rng = Random(11);
    final now = DateTime.now();
    final types = [
      ActivityType.betPlaced,
      ActivityType.betSold,
      ActivityType.winningsClaimed,
      ActivityType.marketResolved,
      ActivityType.commentPosted,
      ActivityType.userFollowed,
    ];
    return List.generate(count, (i) {
      final t = types[rng.nextInt(types.length)];
      return ActivityItem(
        id: 'dummy-$i',
        type: t,
        actorWallet: '0x${'${rng.nextInt(0xffffff).toRadixString(16)}'.padLeft(6, '0')}0000000000000000000000000000000000',
        actorDisplayName: 'Trader #${rng.nextInt(999)}',
        actorAvatarUrl: null,
        marketId: '${rng.nextInt(12)}',
        metadata: t == ActivityType.betPlaced || t == ActivityType.betSold
            ? {'usdcDelta': rng.nextDouble() * 1000, 'outcomeIndex': rng.nextInt(4)}
            : const {},
        createdAt: now.subtract(Duration(minutes: i * 17 + rng.nextInt(60))),
      );
    });
  }
}

class UserStats {
  final int totalBets;
  final int wins;
  final int losses;
  final double totalVolume;
  final double totalPnl;

  const UserStats({
    required this.totalBets,
    required this.wins,
    required this.losses,
    required this.totalVolume,
    required this.totalPnl,
  });

  double get winRate =>
      (wins + losses) == 0 ? 0.0 : wins / (wins + losses);

  factory UserStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserStats.empty();
    return UserStats(
      totalBets: (json['totalBets'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      totalVolume: double.tryParse('${json['totalVolume']}') ?? 0,
      totalPnl: double.tryParse('${json['totalPnl']}') ?? 0,
    );
  }

  const UserStats.empty()
      : totalBets = 0,
        wins = 0,
        losses = 0,
        totalVolume = 0,
        totalPnl = 0;
}

class UserProfile {
  final String walletAddress;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final UserStats stats;
  final List<String> following;
  final List<String> followers;

  const UserProfile({
    required this.walletAddress,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.stats = const UserStats.empty(),
    this.following = const [],
    this.followers = const [],
  });

  int get followerCount => followers.length;
  int get followingCount => following.length;

  String get shortName {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (walletAddress.length < 10) return walletAddress;
    return '${walletAddress.substring(0, 6)}…${walletAddress.substring(walletAddress.length - 4)}';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      walletAddress: (json['walletAddress'] ?? '').toString().toLowerCase(),
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>?),
      following: ((json['following'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toList(),
      followers: ((json['followers'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toList(),
    );
  }
}

class DummyUserProfile {
  static UserProfile self(String address) {
    return UserProfile(
      walletAddress: address.toLowerCase(),
      displayName: _shortName(address),
      avatarUrl: null,
      bio: 'Trader on EigenBets. Loves charts, fast news, and being right.',
      stats: const UserStats(
        totalBets: 12,
        wins: 7,
        losses: 3,
        totalVolume: 8450,
        totalPnl: 1235.5,
      ),
      following: const [
        '0x1111111111111111111111111111111111111111',
        '0x2222222222222222222222222222222222222222',
      ],
      followers: const [
        '0x3333333333333333333333333333333333333333',
      ],
    );
  }

  static UserProfile stranger(String address) {
    return UserProfile(
      walletAddress: address.toLowerCase(),
      displayName: _shortName(address),
      avatarUrl: null,
      bio: 'Prediction-market researcher.',
      stats: const UserStats(
        totalBets: 42,
        wins: 19,
        losses: 14,
        totalVolume: 32100,
        totalPnl: 4820,
      ),
      following: const [],
      followers: const [],
    );
  }

  static String _shortName(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}

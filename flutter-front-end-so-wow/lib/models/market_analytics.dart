import 'dart:math';

/// Source of analytics data at runtime. Widgets don't branch on this, but the
/// provider surfaces it so the UI can show "live / cached / offline" hints.
enum AnalyticsSource { backend, contract, dummy }

class PriceHistoryPoint {
  final DateTime timestamp;
  final int outcomeIndex;
  final double price; // 0..1 probability OR USDC-denominated price
  final double probability;

  const PriceHistoryPoint({
    required this.timestamp,
    required this.outcomeIndex,
    required this.price,
    required this.probability,
  });

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return PriceHistoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      outcomeIndex: (json['outcomeIndex'] as num?)?.toInt() ?? 0,
      price: double.tryParse('${json['price']}') ?? 0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VolumeBar {
  final DateTime day;
  final int outcomeIndex;
  final double totalUsdc;
  final int count;

  const VolumeBar({
    required this.day,
    required this.outcomeIndex,
    required this.totalUsdc,
    required this.count,
  });

  factory VolumeBar.fromJson(Map<String, dynamic> json) {
    return VolumeBar(
      day: DateTime.parse('${json['day']}T00:00:00Z'),
      outcomeIndex: (json['outcomeIndex'] as num?)?.toInt() ?? 0,
      totalUsdc: (json['totalUsdc'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DepthLevel {
  final int outcomeIndex;
  final double price;
  final double probability;
  final double usdcInPool;
  final double tokensInPool;

  const DepthLevel({
    required this.outcomeIndex,
    required this.price,
    required this.probability,
    required this.usdcInPool,
    required this.tokensInPool,
  });

  factory DepthLevel.fromJson(Map<String, dynamic> json) {
    return DepthLevel(
      outcomeIndex: (json['outcomeIndex'] as num?)?.toInt() ?? 0,
      price: double.tryParse('${json['price']}') ?? 0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0,
      usdcInPool: double.tryParse('${json['usdcInPool']}') ?? 0,
      tokensInPool: double.tryParse('${json['tokensInPool']}') ?? 0,
    );
  }
}

class HeatMapCell {
  final String marketId;
  final String title;
  final double totalUsdc;
  final int bets;
  final double change24h; // -1..1 (or arbitrary range used for color scaling)

  const HeatMapCell({
    required this.marketId,
    required this.title,
    required this.totalUsdc,
    required this.bets,
    required this.change24h,
  });

  factory HeatMapCell.fromJson(Map<String, dynamic> json) {
    return HeatMapCell(
      marketId: '${json['marketId']}',
      title: '${json['title'] ?? 'Market #${json['marketId']}'}',
      totalUsdc: (json['totalUsdc'] as num?)?.toDouble() ?? 0,
      bets: (json['bets'] as num?)?.toInt() ?? 0,
      change24h: (json['change24h'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Deterministic-seeded dummy data for day-one rendering when neither backend
/// nor contract state has populated yet. Never used in production data paths.
class DummyAnalyticsData {
  static List<PriceHistoryPoint> priceHistory({int outcomes = 2, int days = 14}) {
    final rng = Random(42);
    final now = DateTime.now();
    final points = <PriceHistoryPoint>[];
    for (int o = 0; o < outcomes; o++) {
      double p = 0.5 + (rng.nextDouble() - 0.5) * 0.2;
      for (int d = days; d >= 0; d--) {
        p = (p + (rng.nextDouble() - 0.5) * 0.08).clamp(0.05, 0.95);
        points.add(PriceHistoryPoint(
          timestamp: now.subtract(Duration(days: d)),
          outcomeIndex: o,
          price: p,
          probability: p,
        ));
      }
    }
    return points;
  }

  static List<VolumeBar> volume({int outcomes = 2, int days = 7}) {
    final rng = Random(99);
    final bars = <VolumeBar>[];
    final start = DateTime.now().subtract(Duration(days: days));
    for (int d = 0; d < days; d++) {
      for (int o = 0; o < outcomes; o++) {
        bars.add(VolumeBar(
          day: start.add(Duration(days: d)),
          outcomeIndex: o,
          totalUsdc: 1500 + rng.nextDouble() * 8500,
          count: 3 + rng.nextInt(30),
        ));
      }
    }
    return bars;
  }

  static List<DepthLevel> depth({int outcomes = 2}) {
    final rng = Random(7);
    return List.generate(outcomes, (i) {
      final p = 0.3 + rng.nextDouble() * 0.4;
      return DepthLevel(
        outcomeIndex: i,
        price: p,
        probability: p,
        usdcInPool: 25000 + rng.nextDouble() * 75000,
        tokensInPool: 100000 + rng.nextDouble() * 300000,
      );
    });
  }

  static List<HeatMapCell> heatMap({int count = 12}) {
    final rng = Random(13);
    return List.generate(count, (i) {
      return HeatMapCell(
        marketId: '$i',
        title: _dummyTitles[i % _dummyTitles.length],
        totalUsdc: 2000 + rng.nextDouble() * 95000,
        bets: 5 + rng.nextInt(120),
        change24h: (rng.nextDouble() - 0.5) * 2,
      );
    });
  }

  static const List<String> _dummyTitles = [
    'ETH > \$4k by EOM',
    'BTC halving aftermath',
    'Fed cuts in June',
    'GPT-5 before 2026',
    'OpenAI IPO this year',
    'Apple ships VR2',
    'USDC depeg risk',
    'Solana flips Ethereum',
    'Superbowl winner',
    'Election turnout > 65%',
    'Base TVL > \$10B',
    'Next unicorn IPO',
  ];
}

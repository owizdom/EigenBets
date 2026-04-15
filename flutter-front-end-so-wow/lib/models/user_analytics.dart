import 'dart:math';

class PnLPoint {
  final DateTime timestamp;
  final double cumulativePnl;
  final String action;
  final String? marketId;

  const PnLPoint({
    required this.timestamp,
    required this.cumulativePnl,
    required this.action,
    this.marketId,
  });

  factory PnLPoint.fromJson(Map<String, dynamic> json) {
    return PnLPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      cumulativePnl: (json['cumulativePnl'] as num?)?.toDouble() ?? 0,
      action: '${json['action'] ?? 'unknown'}',
      marketId: json['marketId']?.toString(),
    );
  }
}

class WinLossStats {
  final int wins;
  final int losses;
  final int open;
  final int totalMarkets;

  const WinLossStats({
    required this.wins,
    required this.losses,
    required this.open,
    required this.totalMarkets,
  });

  double get winRate =>
      (wins + losses) == 0 ? 0.0 : wins / (wins + losses);

  factory WinLossStats.fromJson(Map<String, dynamic> json) {
    return WinLossStats(
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      totalMarkets: (json['totalMarkets'] as num?)?.toInt() ?? 0,
    );
  }
}

class PortfolioSnapshot {
  final DateTime timestamp;
  final double portfolioValue;
  final double cashFlow;

  const PortfolioSnapshot({
    required this.timestamp,
    required this.portfolioValue,
    required this.cashFlow,
  });

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) {
    return PortfolioSnapshot(
      timestamp: DateTime.parse(json['timestamp'] as String),
      portfolioValue: (json['portfolioValue'] as num?)?.toDouble() ?? 0,
      cashFlow: (json['cashFlow'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PredictionHistoryItem {
  final String marketId;
  final int outcomeIndex;
  final String action;
  final double usdcDelta;
  final double tokenDelta;
  final DateTime timestamp;
  final String? txHash;

  const PredictionHistoryItem({
    required this.marketId,
    required this.outcomeIndex,
    required this.action,
    required this.usdcDelta,
    required this.tokenDelta,
    required this.timestamp,
    this.txHash,
  });

  factory PredictionHistoryItem.fromJson(Map<String, dynamic> json) {
    return PredictionHistoryItem(
      marketId: '${json['marketId']}',
      outcomeIndex: (json['outcomeIndex'] as num?)?.toInt() ?? 0,
      action: '${json['action'] ?? 'unknown'}',
      usdcDelta: double.tryParse('${json['usdcDelta']}') ?? 0,
      tokenDelta: double.tryParse('${json['tokenDelta']}') ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      txHash: json['txHash']?.toString(),
    );
  }
}

class DummyUserAnalytics {
  static List<PnLPoint> pnl({int days = 30}) {
    final rng = Random(17);
    final now = DateTime.now();
    double cum = 0;
    return List.generate(days, (i) {
      cum += (rng.nextDouble() - 0.45) * 120;
      return PnLPoint(
        timestamp: now.subtract(Duration(days: days - i)),
        cumulativePnl: cum,
        action: rng.nextBool() ? 'buy' : 'sell',
        marketId: '${rng.nextInt(8)}',
      );
    });
  }

  static WinLossStats winLoss() {
    return const WinLossStats(wins: 8, losses: 3, open: 4, totalMarkets: 15);
  }

  static List<PortfolioSnapshot> portfolio({int days = 30}) {
    final rng = Random(23);
    final now = DateTime.now();
    double value = 500;
    double cash = -500;
    return List.generate(days, (i) {
      value += (rng.nextDouble() - 0.4) * 60;
      cash += (rng.nextDouble() - 0.5) * 40;
      return PortfolioSnapshot(
        timestamp: now.subtract(Duration(days: days - i)),
        portfolioValue: value,
        cashFlow: cash,
      );
    });
  }

  static List<PredictionHistoryItem> history({int count = 10}) {
    final rng = Random(31);
    final now = DateTime.now();
    final actions = ['buy', 'sell', 'claim'];
    return List.generate(count, (i) {
      final action = actions[rng.nextInt(actions.length)];
      return PredictionHistoryItem(
        marketId: '${rng.nextInt(12)}',
        outcomeIndex: rng.nextInt(4),
        action: action,
        usdcDelta: (action == 'buy' ? -1 : 1) * (50 + rng.nextDouble() * 450),
        tokenDelta: rng.nextDouble() * 200,
        timestamp: now.subtract(Duration(hours: i * 6 + rng.nextInt(6))),
        txHash: '0xdummyhash${i.toRadixString(16)}',
      );
    });
  }
}

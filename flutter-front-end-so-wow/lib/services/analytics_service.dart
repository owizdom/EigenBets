import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/market_analytics.dart';
import '../models/user_analytics.dart';

/// Thin HTTP client wrapping the Execution_Service /analytics/* endpoints.
/// Each method throws on network/parse failure so callers (provider) can fall
/// back to contract reads or dummy data.
class AnalyticsService {
  static const String baseUrl = 'http://localhost:4003';
  static const Duration _timeout = Duration(seconds: 5);

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: {'Accept': 'application/json'})
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $path');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Bad envelope for $path');
    }
    if (body['error'] == true) {
      throw Exception('${body['message'] ?? 'Backend error'} for $path');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Missing data field for $path');
    }
    return data;
  }

  // ── Market-level ────────────────────────────────────────────────────────

  Future<List<PriceHistoryPoint>> priceHistory(String marketId,
      {String range = '1W'}) async {
    final data =
        await _get('/analytics/market/$marketId/price-history?range=$range');
    final points = (data['points'] as List?) ?? const [];
    return points
        .whereType<Map<String, dynamic>>()
        .map(PriceHistoryPoint.fromJson)
        .toList();
  }

  Future<List<VolumeBar>> volume(String marketId, {String range = '1W'}) async {
    final data = await _get('/analytics/market/$marketId/volume?range=$range');
    final bars = (data['bars'] as List?) ?? const [];
    return bars
        .whereType<Map<String, dynamic>>()
        .map(VolumeBar.fromJson)
        .toList();
  }

  Future<List<DepthLevel>> depth(String marketId) async {
    final data = await _get('/analytics/market/$marketId/depth');
    final levels = (data['levels'] as List?) ?? const [];
    return levels
        .whereType<Map<String, dynamic>>()
        .map(DepthLevel.fromJson)
        .toList();
  }

  Future<List<HeatMapCell>> heatMap({String window = '24h'}) async {
    final data = await _get('/analytics/markets/heatmap?window=$window');
    final cells = (data['cells'] as List?) ?? const [];
    return cells
        .whereType<Map<String, dynamic>>()
        .map(HeatMapCell.fromJson)
        .toList();
  }

  // ── User-level ──────────────────────────────────────────────────────────

  Future<List<PnLPoint>> pnl(String address) async {
    final data = await _get('/analytics/user/$address/pnl');
    final points = (data['points'] as List?) ?? const [];
    return points
        .whereType<Map<String, dynamic>>()
        .map(PnLPoint.fromJson)
        .toList();
  }

  Future<WinLossStats> winLoss(String address) async {
    final data = await _get('/analytics/user/$address/win-loss');
    return WinLossStats.fromJson(data);
  }

  Future<List<PortfolioSnapshot>> portfolioHistory(String address) async {
    final data = await _get('/analytics/user/$address/portfolio-history');
    final points = (data['points'] as List?) ?? const [];
    return points
        .whereType<Map<String, dynamic>>()
        .map(PortfolioSnapshot.fromJson)
        .toList();
  }

  Future<List<PredictionHistoryItem>> predictions(String address) async {
    final data = await _get('/analytics/user/$address/predictions');
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PredictionHistoryItem.fromJson)
        .toList();
  }
}

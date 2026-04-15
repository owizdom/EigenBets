import 'package:flutter/foundation.dart';

import '../models/market_analytics.dart';
import '../models/user_analytics.dart';
import 'analytics_service.dart';

/// ChangeNotifier that fronts the 8 analytics widgets. Per-widget hybrid
/// strategy: try backend → on failure, fall back to dummy. (Contract-direct
/// reads via web3dart can be added here later; widgets never branch on
/// source, but `sourceFor(...)` exposes it for subtle UI hints.)
class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider({AnalyticsService? service})
      : _service = service ?? AnalyticsService();

  final AnalyticsService _service;

  // ── Per-widget caches ───────────────────────────────────────────────────
  List<PriceHistoryPoint>? _priceHistory;
  List<VolumeBar>? _volume;
  List<DepthLevel>? _depth;
  List<HeatMapCell>? _heatMap;
  List<PnLPoint>? _pnl;
  WinLossStats? _winLoss;
  List<PortfolioSnapshot>? _portfolio;
  List<PredictionHistoryItem>? _predictions;

  // ── Per-widget status ───────────────────────────────────────────────────
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};
  final Map<String, AnalyticsSource> _sources = {};

  String? _currentMarketId;
  String? _currentAddress;
  String _range = '1W';

  String get range => _range;
  String? get currentMarketId => _currentMarketId;
  String? get currentAddress => _currentAddress;

  bool isLoading(String widget) => _loading[widget] ?? false;
  String? errorFor(String widget) => _errors[widget];
  AnalyticsSource? sourceFor(String widget) => _sources[widget];

  List<PriceHistoryPoint>? get priceHistory => _priceHistory;
  List<VolumeBar>? get volume => _volume;
  List<DepthLevel>? get depth => _depth;
  List<HeatMapCell>? get heatMap => _heatMap;
  List<PnLPoint>? get pnl => _pnl;
  WinLossStats? get winLoss => _winLoss;
  List<PortfolioSnapshot>? get portfolio => _portfolio;
  List<PredictionHistoryItem>? get predictions => _predictions;

  void setMarket(String? id) {
    if (_currentMarketId == id) return;
    _currentMarketId = id;
    _priceHistory = null;
    _volume = null;
    _depth = null;
    notifyListeners();
  }

  void setAddress(String? addr) {
    if (_currentAddress == addr) return;
    _currentAddress = addr;
    _pnl = null;
    _winLoss = null;
    _portfolio = null;
    _predictions = null;
    notifyListeners();
  }

  void setRange(String range) {
    if (_range == range) return;
    _range = range;
    _priceHistory = null;
    _volume = null;
    notifyListeners();
  }

  Future<void> _run<T>(
    String widget,
    Future<T> Function() backend,
    T Function() dummy,
    void Function(T value, AnalyticsSource source) assign,
  ) async {
    _loading[widget] = true;
    _errors[widget] = null;
    notifyListeners();
    try {
      final result = await backend();
      assign(result, AnalyticsSource.backend);
    } catch (err) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[analytics_provider] $widget fell back to dummy: $err');
      }
      assign(dummy(), AnalyticsSource.dummy);
      _errors[widget] = err.toString();
    } finally {
      _loading[widget] = false;
      _sources[widget] = _errors[widget] == null
          ? AnalyticsSource.backend
          : AnalyticsSource.dummy;
      notifyListeners();
    }
  }

  // ── Market-level loaders ────────────────────────────────────────────────

  Future<void> loadPriceHistory() async {
    final id = _currentMarketId;
    if (id == null) {
      _priceHistory = DummyAnalyticsData.priceHistory();
      _sources['priceHistory'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<PriceHistoryPoint>>(
      'priceHistory',
      () => _service.priceHistory(id, range: _range),
      () => DummyAnalyticsData.priceHistory(),
      (v, src) {
        _priceHistory = v;
        _sources['priceHistory'] = src;
      },
    );
  }

  Future<void> loadVolume() async {
    final id = _currentMarketId;
    if (id == null) {
      _volume = DummyAnalyticsData.volume();
      _sources['volume'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<VolumeBar>>(
      'volume',
      () => _service.volume(id, range: _range),
      () => DummyAnalyticsData.volume(),
      (v, src) {
        _volume = v;
        _sources['volume'] = src;
      },
    );
  }

  Future<void> loadDepth() async {
    final id = _currentMarketId;
    if (id == null) {
      _depth = DummyAnalyticsData.depth();
      _sources['depth'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<DepthLevel>>(
      'depth',
      () => _service.depth(id),
      () => DummyAnalyticsData.depth(),
      (v, src) {
        _depth = v;
        _sources['depth'] = src;
      },
    );
  }

  Future<void> loadHeatMap() async {
    await _run<List<HeatMapCell>>(
      'heatMap',
      () => _service.heatMap(),
      () => DummyAnalyticsData.heatMap(),
      (v, src) {
        _heatMap = v;
        _sources['heatMap'] = src;
      },
    );
  }

  // ── User-level loaders ──────────────────────────────────────────────────

  Future<void> loadPnl() async {
    final addr = _currentAddress;
    if (addr == null) {
      _pnl = DummyUserAnalytics.pnl();
      _sources['pnl'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<PnLPoint>>(
      'pnl',
      () => _service.pnl(addr),
      () => DummyUserAnalytics.pnl(),
      (v, src) {
        _pnl = v;
        _sources['pnl'] = src;
      },
    );
  }

  Future<void> loadWinLoss() async {
    final addr = _currentAddress;
    if (addr == null) {
      _winLoss = DummyUserAnalytics.winLoss();
      _sources['winLoss'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<WinLossStats>(
      'winLoss',
      () => _service.winLoss(addr),
      () => DummyUserAnalytics.winLoss(),
      (v, src) {
        _winLoss = v;
        _sources['winLoss'] = src;
      },
    );
  }

  Future<void> loadPortfolio() async {
    final addr = _currentAddress;
    if (addr == null) {
      _portfolio = DummyUserAnalytics.portfolio();
      _sources['portfolio'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<PortfolioSnapshot>>(
      'portfolio',
      () => _service.portfolioHistory(addr),
      () => DummyUserAnalytics.portfolio(),
      (v, src) {
        _portfolio = v;
        _sources['portfolio'] = src;
      },
    );
  }

  Future<void> loadPredictions() async {
    final addr = _currentAddress;
    if (addr == null) {
      _predictions = DummyUserAnalytics.history();
      _sources['predictions'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<PredictionHistoryItem>>(
      'predictions',
      () => _service.predictions(addr),
      () => DummyUserAnalytics.history(),
      (v, src) {
        _predictions = v;
        _sources['predictions'] = src;
      },
    );
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadPriceHistory(),
      loadVolume(),
      loadDepth(),
      loadHeatMap(),
      loadPnl(),
      loadWinLoss(),
      loadPortfolio(),
      loadPredictions(),
    ]);
  }
}

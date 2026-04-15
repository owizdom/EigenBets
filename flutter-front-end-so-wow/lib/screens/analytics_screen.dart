import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/analytics_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/analytics/price_history_chart.dart';
import '../widgets/analytics/volume_chart.dart';
import '../widgets/analytics/liquidity_depth_widget.dart';
import '../widgets/analytics/market_heat_map.dart';
import '../widgets/analytics/pnl_chart.dart';
import '../widgets/analytics/win_loss_breakdown.dart';
import '../widgets/analytics/portfolio_value_chart.dart';
import '../widgets/analytics/prediction_history_list.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletService>();
      final provider = context.read<AnalyticsProvider>();
      provider.setAddress(wallet.walletAddress);
      // Default market id "0" for demo heatmap markets until a user picks one.
      provider.setMarket('0');
      provider.refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = context.watch<WalletService>();
    final provider = context.watch<AnalyticsProvider>();

    // Keep provider's address in sync with wallet connection state.
    if (provider.currentAddress != wallet.walletAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setAddress(wallet.walletAddress);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshAll(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.insights_outlined), text: 'Market'),
            Tab(icon: Icon(Icons.account_circle_outlined), text: 'You'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MarketTab(),
          _UserTab(walletConnected: wallet.isConnected),
        ],
      ),
    );
  }
}

class _MarketTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return Column(
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: PriceHistoryChart()),
                  SizedBox(width: 16),
                  Expanded(child: VolumeChart()),
                ],
              )
            else ...const [
              PriceHistoryChart(),
              SizedBox(height: 16),
              VolumeChart(),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: LiquidityDepthWidget()),
                  SizedBox(width: 16),
                  Expanded(flex: 2, child: MarketHeatMap()),
                ],
              )
            else ...const [
              LiquidityDepthWidget(),
              SizedBox(height: 16),
              MarketHeatMap(),
            ],
          ],
        );
      }),
    );
  }
}

class _UserTab extends StatelessWidget {
  final bool walletConnected;
  const _UserTab({required this.walletConnected});

  @override
  Widget build(BuildContext context) {
    if (!walletConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Connect your wallet to see personal analytics',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'We render dummy data in the meantime — everything will populate as you place bets.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return Column(
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: PnlChart()),
                  SizedBox(width: 16),
                  Expanded(child: WinLossBreakdown()),
                ],
              )
            else ...const [
              PnlChart(),
              SizedBox(height: 16),
              WinLossBreakdown(),
            ],
            const SizedBox(height: 16),
            const PortfolioValueChart(),
            const SizedBox(height: 16),
            const PredictionHistoryList(),
          ],
        );
      }),
    );
  }
}

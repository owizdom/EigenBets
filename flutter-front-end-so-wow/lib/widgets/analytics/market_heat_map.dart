import 'package:flutter/material.dart';
import '_stub.dart';

class MarketHeatMap extends StatelessWidget {
  const MarketHeatMap({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Market heat map',
      subtitle: '24h activity across all markets',
      icon: Icons.grid_view_rounded,
      height: 300,
    );
  }
}

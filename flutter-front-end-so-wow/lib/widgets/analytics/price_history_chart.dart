import 'package:flutter/material.dart';
import '_stub.dart';

class PriceHistoryChart extends StatelessWidget {
  const PriceHistoryChart({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Price history',
      subtitle: 'Outcome probabilities over time',
      icon: Icons.show_chart,
    );
  }
}

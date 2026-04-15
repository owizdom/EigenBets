import 'package:flutter/material.dart';
import '_stub.dart';

class PortfolioValueChart extends StatelessWidget {
  const PortfolioValueChart({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Portfolio value',
      subtitle: 'Holdings valued at current prices',
      icon: Icons.pie_chart_outline,
      height: 260,
    );
  }
}

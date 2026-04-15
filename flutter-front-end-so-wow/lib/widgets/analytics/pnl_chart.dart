import 'package:flutter/material.dart';
import '_stub.dart';

class PnlChart extends StatelessWidget {
  const PnlChart({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Cumulative P&L',
      subtitle: 'Realized + unrealized gains over time',
      icon: Icons.trending_up,
    );
  }
}

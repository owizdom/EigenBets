import 'package:flutter/material.dart';
import '_stub.dart';

class PredictionHistoryList extends StatelessWidget {
  const PredictionHistoryList({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Prediction history',
      subtitle: 'Your past bets, outcomes, and realized P&L',
      icon: Icons.history,
      height: 320,
    );
  }
}

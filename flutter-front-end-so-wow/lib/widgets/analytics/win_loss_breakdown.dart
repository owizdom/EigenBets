import 'package:flutter/material.dart';
import '_stub.dart';

class WinLossBreakdown extends StatelessWidget {
  const WinLossBreakdown({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Win / loss',
      subtitle: 'Resolved outcomes breakdown',
      icon: Icons.donut_large_outlined,
    );
  }
}

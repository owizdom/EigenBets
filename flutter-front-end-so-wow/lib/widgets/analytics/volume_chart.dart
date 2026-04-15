import 'package:flutter/material.dart';
import '_stub.dart';

class VolumeChart extends StatelessWidget {
  const VolumeChart({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Volume',
      subtitle: 'Daily trading volume per outcome',
      icon: Icons.bar_chart,
    );
  }
}

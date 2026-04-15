import 'package:flutter/material.dart';
import '_stub.dart';

class LiquidityDepthWidget extends StatelessWidget {
  const LiquidityDepthWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const AnalyticsStubCard(
      title: 'Liquidity depth',
      subtitle: 'Pool reserves per outcome',
      icon: Icons.water_drop_outlined,
    );
  }
}

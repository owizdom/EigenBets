import 'package:flutter/material.dart';
import '_stub.dart';

class MarketComments extends StatelessWidget {
  final String marketId;
  const MarketComments({Key? key, required this.marketId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SocialStubCard(
      title: 'Market comments',
      subtitle: 'Threaded discussion, post box, likes, replies',
      icon: Icons.forum_outlined,
      height: 320,
    );
  }
}

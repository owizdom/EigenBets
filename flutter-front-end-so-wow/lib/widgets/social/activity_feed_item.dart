import 'package:flutter/material.dart';
import '../../models/activity_item.dart';
import '_stub.dart';

class ActivityFeedItemWidget extends StatelessWidget {
  final ActivityItem item;
  const ActivityFeedItemWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SocialStubCard(
      title: 'Activity item',
      subtitle: 'Actor avatar, icon-per-type, text summary, timestamp',
      icon: Icons.bolt_outlined,
      height: 80,
    );
  }
}

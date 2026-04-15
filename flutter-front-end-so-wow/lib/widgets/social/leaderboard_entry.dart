import 'package:flutter/material.dart';
import '_stub.dart';

class LeaderboardEntryWidget extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String sortBy;
  const LeaderboardEntryWidget({Key? key, required this.entry, required this.sortBy}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SocialStubCard(
      title: 'Leaderboard row',
      subtitle: 'Rank, avatar, name, metric, medal icons',
      icon: Icons.emoji_events_outlined,
      height: 80,
    );
  }
}

import 'package:flutter/material.dart';
import '_stub.dart';

class FollowButton extends StatelessWidget {
  final String targetAddress;
  const FollowButton({Key? key, required this.targetAddress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SocialStubCard(
      title: 'Follow',
      subtitle: 'Toggle follow state for a wallet',
      icon: Icons.person_add_alt_1_outlined,
      height: 64,
    );
  }
}

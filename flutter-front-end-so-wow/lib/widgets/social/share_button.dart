import 'package:flutter/material.dart';
import '_stub.dart';

class ShareButton extends StatelessWidget {
  final String marketId;
  final String? marketTitle;
  const ShareButton({Key? key, required this.marketId, this.marketTitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SocialStubCard(
      title: 'Share',
      subtitle: 'Share market link to clipboard or native share',
      icon: Icons.share_outlined,
      height: 64,
    );
  }
}

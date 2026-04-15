import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/social_provider.dart';
import '../widgets/social/follow_button.dart';

class PublicProfileScreen extends StatefulWidget {
  final String address;
  const PublicProfileScreen({Key? key, required this.address}) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().loadPublicProfile(widget.address);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = context.watch<SocialProvider>();
    final profile = social.publicProfiles[widget.address.toLowerCase()];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(profile.shortName,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  SelectableText(profile.walletAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      )),
                  const SizedBox(height: 12),
                  if (profile.bio != null && profile.bio!.isNotEmpty)
                    Text(profile.bio!, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  FollowButton(targetAddress: profile.walletAddress),
                ],
              ),
            ),
    );
  }
}

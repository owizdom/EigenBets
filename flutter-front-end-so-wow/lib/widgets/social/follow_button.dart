import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../services/social_provider.dart';

/// Compact toggle button for following or unfollowing a wallet address.
///
/// Renders four states driven by [SocialProvider]:
///   * no wallet connected -> disabled "Connect to follow" pill
///   * viewing own profile -> disabled "You" pill
///   * not following target -> tonal "Follow" button
///   * already following   -> outlined "Following" button (tap to unfollow)
///
/// While a toggle is in flight the leading icon is swapped for a small
/// [CircularProgressIndicator]. Styling is derived entirely from the ambient
/// [Theme] so the button adapts to light/dark palettes without hex literals.
class FollowButton extends StatelessWidget {
  final String targetAddress;
  const FollowButton({Key? key, required this.targetAddress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final normalizedTarget = targetAddress.toLowerCase();
    final loadingKey = 'toggleFollow:$normalizedTarget';

    return Consumer<SocialProvider>(
      builder: (context, provider, _) {
        final currentAddress = provider.currentAddress;
        final isBusy = provider.isLoading(loadingKey);
        final hasError = provider.errorFor(loadingKey) != null;

        // State 1: no wallet connected.
        if (currentAddress == null) {
          return _DisabledPill(
            icon: Icons.login,
            label: 'Connect to follow',
            foreground: colors.onSurface.withOpacity(0.6),
            borderColor: colors.outlineVariant,
          );
        }

        // State 2: viewing own profile.
        if (currentAddress == normalizedTarget) {
          return _DisabledPill(
            icon: Icons.person_outline,
            label: 'You',
            foreground: colors.onSurface.withOpacity(0.6),
            borderColor: colors.outlineVariant,
          );
        }

        final isFollowing =
            provider.selfProfile?.following.contains(normalizedTarget) ?? false;

        final leadingIcon = isBusy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFollowing ? colors.primary : colors.onSecondaryContainer,
                  ),
                ),
              )
            : Icon(
                isFollowing
                    ? Icons.check
                    : Icons.person_add_alt_1_outlined,
                size: 18,
              );

        final label = Text(isFollowing ? 'Following' : 'Follow');

        Future<void> onTap() async {
          if (isBusy) return;
          await provider.toggleFollow(normalizedTarget);
        }

        final button = isFollowing
            ? OutlinedButton.icon(
                onPressed: isBusy ? null : onTap,
                icon: leadingIcon,
                label: label,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary.withOpacity(0.6)),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.labelLarge,
                ),
              )
            : FilledButton.tonalIcon(
                onPressed: isBusy ? null : onTap,
                icon: leadingIcon,
                label: label,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.labelLarge,
                ),
              );

        if (!hasError) return button;

        // Surface a subtle error affordance without stealing the layout slot.
        return Tooltip(
          message: provider.errorFor(loadingKey) ?? 'Follow action failed',
          child: button,
        );
      },
    );
  }
}

/// Disabled stadium-shaped pill used for "Connect to follow" and "You" states.
class _DisabledPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color borderColor;

  const _DisabledPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        disabledForegroundColor: foreground,
        foregroundColor: foreground,
        side: BorderSide(color: borderColor),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(),
        textStyle: theme.textTheme.labelLarge,
      ),
    );
  }
}

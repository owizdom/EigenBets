import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact share affordance for a prediction market.
///
/// Copies a shareable URL to the system clipboard and confirms via a
/// [SnackBar]. A native share sheet would require `share_plus`, which is
/// intentionally not added here to avoid introducing a new dependency.
class ShareButton extends StatelessWidget {
  final String marketId;
  final String? marketTitle;
  const ShareButton({Key? key, required this.marketId, this.marketTitle})
      : super(key: key);

  static const String _baseUrl = 'https://eigenbets.app/market';

  String _buildShareText() {
    final url = '$_baseUrl/$marketId';
    final title = marketTitle?.trim();
    if (title == null || title.isEmpty) {
      return url;
    }
    return '$title \u2014 $url';
  }

  Future<void> _handleShare(BuildContext context) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final shareText = _buildShareText();

    try {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (messenger == null) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Link copied',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondary,
            ),
          ),
          backgroundColor: theme.colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (messenger == null) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not copy link',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          backgroundColor: theme.colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: 'Share',
      splashRadius: 20,
      icon: Icon(
        Icons.ios_share,
        color: theme.colorScheme.primary,
        size: 20,
      ),
      onPressed: () => _handleShare(context),
    );
  }
}

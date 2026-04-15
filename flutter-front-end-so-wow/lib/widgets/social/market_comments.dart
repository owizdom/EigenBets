import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/comment_data.dart';
import '../../models/market_analytics.dart' show AnalyticsSource;
import '../../services/social_provider.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';

/// Threaded discussion card for a single market.
///
/// Mounts a compose box (when wallet is connected), sort toggle, LIVE/DEMO
/// badge, and a list of root comments with their embedded replies. All state
/// lives behind [SocialProvider]; this widget is `Stateful` only because it
/// owns the compose [TextEditingController], the reply-target id, and the
/// compose [FocusNode].
class MarketComments extends StatefulWidget {
  final String marketId;
  const MarketComments({Key? key, required this.marketId}) : super(key: key);

  @override
  State<MarketComments> createState() => _MarketCommentsState();
}

class _MarketCommentsState extends State<MarketComments> {
  final TextEditingController _composeController = TextEditingController();
  final FocusNode _composeFocus = FocusNode();
  String? _replyTargetId;
  String? _inlineError;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _composeController.addListener(_onComposeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialProvider>().loadComments(widget.marketId);
    });
  }

  @override
  void dispose() {
    _composeController.removeListener(_onComposeChanged);
    _composeController.dispose();
    _composeFocus.dispose();
    super.dispose();
  }

  void _onComposeChanged() {
    // Rebuild so the Post button enable-state tracks the text controller.
    if (mounted) setState(() {});
  }

  void _setReplyTarget(String? id) {
    setState(() {
      _replyTargetId = id;
    });
    if (id != null) {
      FocusScope.of(context).requestFocus(_composeFocus);
    }
  }

  Future<void> _handlePost(SocialProvider provider) async {
    final text = _composeController.text.trim();
    if (text.isEmpty || _isPosting) return;
    setState(() {
      _isPosting = true;
      _inlineError = null;
    });
    try {
      await provider.postComment(
        marketId: widget.marketId,
        content: text,
        parentCommentId: _replyTargetId,
      );
      if (!mounted) return;
      _composeController.clear();
      setState(() {
        _replyTargetId = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _inlineError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _handleSort(SocialProvider provider, String sort) async {
    if (provider.commentSort == sort) return;
    provider.setCommentSort(sort);
    await provider.loadComments(widget.marketId);
  }

  CommentData? _lookupComment(List<CommentData> items, String id) {
    for (final c in items) {
      if (c.id == id) return c;
      for (final r in c.replies) {
        if (r.id == id) return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer2<SocialProvider, WalletService>(
      builder: (context, provider, wallet, _) {
        final items = provider.commentsFor(widget.marketId);
        final loadingKey = 'comments:${widget.marketId}';
        final isLoading = provider.isLoading(loadingKey);
        final source = provider.sourceFor(loadingKey);
        final rootItems =
            (items ?? const <CommentData>[]).where((c) => c.parentCommentId == null).toList();

        return Card(
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  count: rootItems.length,
                  sort: provider.commentSort,
                  source: source,
                  onSort: (s) => _handleSort(provider, s),
                ),
                const SizedBox(height: 12),
                if (wallet.isConnected)
                  _ComposeSection(
                    controller: _composeController,
                    focusNode: _composeFocus,
                    replyTargetId: _replyTargetId,
                    replyTargetShort: _replyTargetId == null
                        ? null
                        : _lookupComment(items ?? const [], _replyTargetId!)?.authorShort,
                    onCancelReply: () => _setReplyTarget(null),
                    isPosting: _isPosting,
                    inlineError: _inlineError,
                    onPost: () => _handlePost(provider),
                  )
                else
                  _ConnectHint(),
                const SizedBox(height: 16),
                Divider(color: theme.dividerColor, height: 1),
                const SizedBox(height: 12),
                _Body(
                  isLoading: isLoading,
                  hasCached: items != null,
                  rootItems: rootItems,
                  provider: provider,
                  marketId: widget.marketId,
                  onReply: _setReplyTarget,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => provider.loadMoreComments(widget.marketId),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: const Text('Load more'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────── Header ─────────────────────────────

class _Header extends StatelessWidget {
  final int count;
  final String sort;
  final AnalyticsSource? source;
  final ValueChanged<String> onSort;

  const _Header({
    required this.count,
    required this.sort,
    required this.source,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.forum_outlined, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Discussion', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                '$count comments',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        _SortToggle(current: sort, onChanged: onSort),
        if (source != null) ...[
          const SizedBox(width: 8),
          _SourceBadge(source: source!),
        ],
      ],
    );
  }
}

class _SortToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _SortToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortChip(
            label: 'Newest',
            active: current == 'newest',
            onTap: () => onChanged('newest'),
          ),
          _SortChip(
            label: 'Top',
            active: current == 'liked',
            onTap: () => onChanged('liked'),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.primary.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: active ? colors.primary : colors.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final AnalyticsSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = source == AnalyticsSource.backend ||
        source == AnalyticsSource.contract;
    final label = isLive ? 'LIVE' : 'DEMO';
    final color = isLive ? theme.colorScheme.secondary : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────── Compose box ───────────────────────────

class _ComposeSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyTargetId;
  final String? replyTargetShort;
  final VoidCallback onCancelReply;
  final bool isPosting;
  final String? inlineError;
  final VoidCallback onPost;

  const _ComposeSection({
    required this.controller,
    required this.focusNode,
    required this.replyTargetId,
    required this.replyTargetShort,
    required this.onCancelReply,
    required this.isPosting,
    required this.inlineError,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEmpty = controller.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyTargetId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(
                  'Replying to @${replyTargetShort ?? "…"}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                avatar: Icon(
                  Icons.reply,
                  size: 14,
                  color: colors.primary,
                ),
                backgroundColor: colors.primary.withOpacity(0.12),
                side: BorderSide(color: colors.primary.withOpacity(0.4)),
                deleteIcon: const Icon(Icons.close, size: 14),
                deleteIconColor: colors.primary,
                onDeleted: onCancelReply,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: 3,
          minLines: 1,
          maxLength: 500,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Share your take...',
            counterText: '',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${controller.text.characters.length}/500',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withOpacity(0.5),
              ),
            ),
            const Spacer(),
            if (inlineError != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    inlineError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: (isEmpty || isPosting) ? null : onPost,
              icon: isPosting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 16),
              label: Text(isPosting ? 'Posting…' : 'Post'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: colors.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connect a wallet to join the discussion.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Body ────────────────────────────

class _Body extends StatelessWidget {
  final bool isLoading;
  final bool hasCached;
  final List<CommentData> rootItems;
  final SocialProvider provider;
  final String marketId;
  final ValueChanged<String> onReply;

  const _Body({
    required this.isLoading,
    required this.hasCached,
    required this.rootItems,
    required this.provider,
    required this.marketId,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && !hasCached) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasCached && rootItems.isEmpty) {
      return _EmptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rootItems.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _CommentTile(
            comment: rootItems[i],
            provider: provider,
            marketId: marketId,
            onReply: onReply,
            isReply: false,
          ),
          for (final reply in rootItems[i].replies) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _CommentTile(
                comment: reply,
                provider: provider,
                marketId: marketId,
                onReply: onReply,
                isReply: true,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: colors.onSurface.withOpacity(0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Single comment ───────────────────────────

class _CommentTile extends StatelessWidget {
  final CommentData comment;
  final SocialProvider provider;
  final String marketId;
  final ValueChanged<String> onReply;
  final bool isReply;

  const _CommentTile({
    required this.comment,
    required this.provider,
    required this.marketId,
    required this.onReply,
    required this.isReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentAddress = provider.currentAddress;
    final liked = comment.likedBy(currentAddress);
    final canInteract = currentAddress != null;
    final likeLoading = provider.isLoading('like:${comment.id}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(wallet: comment.authorWallet),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.labelMedium,
                  children: [
                    TextSpan(
                      text: comment.authorShort,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: ' · ${_relative(comment.createdAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _ActionButton(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    label: '${comment.likeCount}',
                    color: liked
                        ? AppTheme.successColor
                        : colors.onSurface.withOpacity(0.6),
                    busy: likeLoading,
                    onTap: canInteract
                        ? () => provider.toggleLike(
                              marketId,
                              comment.id,
                              liked,
                            )
                        : null,
                  ),
                  if (!isReply) ...[
                    const SizedBox(width: 4),
                    _ActionButton(
                      icon: Icons.reply_outlined,
                      label: 'Reply',
                      color: colors.onSurface.withOpacity(0.6),
                      onTap: canInteract ? () => onReply(comment.id) : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String wallet;
  const _Avatar({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final char = _initial(wallet);
    return CircleAvatar(
      radius: 14,
      backgroundColor: colors.surfaceVariant,
      child: Text(
        char.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withOpacity(0.8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initial(String wallet) {
    // First hex char of the wallet (skipping the 0x prefix when present).
    if (wallet.toLowerCase().startsWith('0x') && wallet.length > 2) {
      return wallet.substring(2, 3);
    }
    if (wallet.isNotEmpty) return wallet.substring(0, 1);
    return '?';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Helpers ───────────────────────────

String _relative(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'now';
  if (diff.inSeconds < 45) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

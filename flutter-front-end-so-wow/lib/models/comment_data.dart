import 'dart:math';

class CommentData {
  final String id;
  final String marketId;
  final String authorWallet;
  final String content;
  final String? parentCommentId;
  final List<String> likes;
  final int likeCount;
  final DateTime createdAt;
  final List<CommentData> replies;

  const CommentData({
    required this.id,
    required this.marketId,
    required this.authorWallet,
    required this.content,
    this.parentCommentId,
    this.likes = const [],
    this.likeCount = 0,
    required this.createdAt,
    this.replies = const [],
  });

  bool likedBy(String? wallet) {
    if (wallet == null) return false;
    return likes.contains(wallet.toLowerCase());
  }

  String get authorShort {
    if (authorWallet.length < 10) return authorWallet;
    return '${authorWallet.substring(0, 6)}…${authorWallet.substring(authorWallet.length - 4)}';
  }

  factory CommentData.fromJson(Map<String, dynamic> json) {
    return CommentData(
      id: (json['id'] ?? '').toString(),
      marketId: (json['marketId'] ?? '').toString(),
      authorWallet: (json['authorWallet'] ?? '').toString().toLowerCase(),
      content: (json['content'] ?? '').toString(),
      parentCommentId: json['parentCommentId']?.toString(),
      likes: ((json['likes'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toList(),
      likeCount: (json['likeCount'] as num?)?.toInt() ??
          ((json['likes'] as List?)?.length ?? 0),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      replies: ((json['replies'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CommentData.fromJson)
          .toList(),
    );
  }
}

class DummyComments {
  static List<CommentData> thread(String marketId, {int count = 6}) {
    final rng = Random(29);
    final now = DateTime.now();
    final samples = [
      'ETH just bounced off support; flipping bullish on this outcome.',
      'I disagree — the macro backdrop still favors the no side.',
      'Are we counting the resolver oracle or just the AI verifier here?',
      'Good entry price even if it resolves 50/50.',
      'This market is underpriced. Doubled down.',
      'News wire shows a third-party confirmation already.',
    ];
    return List.generate(count, (i) {
      return CommentData(
        id: 'dummy-$marketId-$i',
        marketId: marketId,
        authorWallet:
            '0x${'${rng.nextInt(0xffffff).toRadixString(16)}'.padLeft(6, '0')}0000000000000000000000000000000000',
        content: samples[i % samples.length],
        likeCount: rng.nextInt(20),
        createdAt: now.subtract(Duration(hours: i * 2 + rng.nextInt(3))),
        replies: i == 0
            ? [
                CommentData(
                  id: 'dummy-$marketId-$i-r',
                  marketId: marketId,
                  authorWallet:
                      '0x${'${rng.nextInt(0xffffff).toRadixString(16)}'.padLeft(6, '0')}0000000000000000000000000000000000',
                  content: 'Agree — I entered on the same catalyst.',
                  parentCommentId: 'dummy-$marketId-$i',
                  likeCount: 2,
                  createdAt: now.subtract(const Duration(hours: 1)),
                )
              ]
            : const [],
      );
    });
  }
}

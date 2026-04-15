import 'package:flutter/foundation.dart';

import '../models/activity_item.dart';
import '../models/comment_data.dart';
import '../models/market_analytics.dart' show AnalyticsSource;
import '../models/user_profile.dart';
import 'social_service.dart';

/// ChangeNotifier for all Phase 4 social features. Mirrors Phase 3's
/// [AnalyticsProvider] hybrid strategy (backend → dummy). Reuses
/// [AnalyticsSource] so the LIVE/DEMO badge convention stays consistent.
class SocialProvider extends ChangeNotifier {
  SocialProvider({SocialService? service})
      : _service = service ?? SocialService();

  final SocialService _service;

  // ── Per-feature caches ─────────────────────────────────────────────────
  UserProfile? _selfProfile;
  final Map<String, UserProfile> _publicProfiles = {};
  final Map<String, List<CommentData>> _commentsByMarket = {};
  final Map<String, String?> _commentCursors = {};
  String _commentSort = 'newest';
  List<ActivityItem>? _globalFeed;
  List<ActivityItem>? _followingFeed;
  List<ActivityItem>? _youFeed;
  List<Map<String, dynamic>>? _leaderboard;
  String _leaderboardSort = 'pnl';
  String _leaderboardPeriod = 'monthly';

  // ── Per-feature status ─────────────────────────────────────────────────
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};
  final Map<String, AnalyticsSource> _sources = {};

  String? _address;

  String? get currentAddress => _address;
  UserProfile? get selfProfile => _selfProfile;
  Map<String, UserProfile> get publicProfiles => _publicProfiles;
  List<ActivityItem>? get globalFeed => _globalFeed;
  List<ActivityItem>? get followingFeed => _followingFeed;
  List<ActivityItem>? get youFeed => _youFeed;
  List<Map<String, dynamic>>? get leaderboard => _leaderboard;
  String get leaderboardSort => _leaderboardSort;
  String get leaderboardPeriod => _leaderboardPeriod;
  String get commentSort => _commentSort;

  List<CommentData>? commentsFor(String marketId) => _commentsByMarket[marketId];

  bool isLoading(String key) => _loading[key] ?? false;
  String? errorFor(String key) => _errors[key];
  AnalyticsSource? sourceFor(String key) => _sources[key];

  void setAddress(String? addr) {
    final normalized = addr?.toLowerCase();
    if (_address == normalized) return;
    _address = normalized;
    _selfProfile = null;
    _followingFeed = null;
    _youFeed = null;
    notifyListeners();
  }

  void setCommentSort(String sort) {
    if (_commentSort == sort) return;
    _commentSort = sort;
    _commentsByMarket.clear();
    _commentCursors.clear();
    notifyListeners();
  }

  void setLeaderboardSort(String sortBy) {
    if (_leaderboardSort == sortBy) return;
    _leaderboardSort = sortBy;
    _leaderboard = null;
    notifyListeners();
  }

  void setLeaderboardPeriod(String period) {
    if (_leaderboardPeriod == period) return;
    _leaderboardPeriod = period;
    _leaderboard = null;
    notifyListeners();
  }

  Future<void> _run<T>(
    String key,
    Future<T> Function() backend,
    T Function() dummy,
    void Function(T value, AnalyticsSource source) assign,
  ) async {
    _loading[key] = true;
    _errors[key] = null;
    notifyListeners();
    try {
      final result = await backend();
      assign(result, AnalyticsSource.backend);
      _sources[key] = AnalyticsSource.backend;
      _errors[key] = null;
    } catch (err) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[social_provider] $key fell back to dummy: $err');
      }
      assign(dummy(), AnalyticsSource.dummy);
      _sources[key] = AnalyticsSource.dummy;
      _errors[key] = err.toString();
    } finally {
      _loading[key] = false;
      notifyListeners();
    }
  }

  // ── Profiles ───────────────────────────────────────────────────────────

  Future<void> loadSelfProfile() async {
    final addr = _address;
    if (addr == null) {
      _selfProfile = DummyUserProfile.self('0x0000000000000000000000000000000000000000');
      _sources['selfProfile'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<UserProfile>(
      'selfProfile',
      () => _service.getUser(addr),
      () => DummyUserProfile.self(addr),
      (v, _) { _selfProfile = v; },
    );
  }

  Future<void> loadPublicProfile(String address) async {
    await _run<UserProfile>(
      'publicProfile:$address',
      () => _service.getUser(address),
      () => DummyUserProfile.stranger(address),
      (v, _) { _publicProfiles[address.toLowerCase()] = v; },
    );
  }

  Future<void> updateSelf({String? displayName, String? avatarUrl, String? bio}) async {
    final addr = _address;
    if (addr == null) return;
    try {
      _loading['updateSelf'] = true;
      _errors['updateSelf'] = null;
      notifyListeners();
      _selfProfile = await _service.updateUser(
        addr,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
      );
      _sources['selfProfile'] = AnalyticsSource.backend;
    } catch (err) {
      _errors['updateSelf'] = err.toString();
    } finally {
      _loading['updateSelf'] = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String target) async {
    final actor = _address;
    if (actor == null) return;
    final normalizedTarget = target.toLowerCase();
    final self = _selfProfile;
    final isFollowing = self?.following.contains(normalizedTarget) ?? false;
    try {
      if (isFollowing) {
        await _service.unfollow(normalizedTarget, actor);
      } else {
        await _service.follow(normalizedTarget, actor);
      }
      await loadSelfProfile();
      if (_publicProfiles.containsKey(normalizedTarget)) {
        await loadPublicProfile(normalizedTarget);
      }
    } catch (err) {
      _errors['toggleFollow:$normalizedTarget'] = err.toString();
      notifyListeners();
    }
  }

  // ── Comments ───────────────────────────────────────────────────────────

  Future<void> loadComments(String marketId) async {
    await _run<List<CommentData>>(
      'comments:$marketId',
      () async {
        final page = await _service.getComments(marketId, sort: _commentSort);
        _commentCursors[marketId] = page.nextCursor;
        return page.items;
      },
      () => DummyComments.thread(marketId),
      (v, _) { _commentsByMarket[marketId] = v; },
    );
  }

  Future<void> loadMoreComments(String marketId) async {
    final cursor = _commentCursors[marketId];
    if (cursor == null) return;
    try {
      final page = await _service.getComments(marketId,
          sort: _commentSort, cursor: cursor);
      final existing = _commentsByMarket[marketId] ?? const [];
      _commentsByMarket[marketId] = [...existing, ...page.items];
      _commentCursors[marketId] = page.nextCursor;
      notifyListeners();
    } catch (err) {
      _errors['comments:$marketId'] = err.toString();
      notifyListeners();
    }
  }

  Future<void> postComment({
    required String marketId,
    required String content,
    String? parentCommentId,
  }) async {
    final actor = _address;
    if (actor == null) throw StateError('wallet not connected');
    final created = await _service.postComment(
      marketId: marketId,
      actor: actor,
      content: content,
      parentCommentId: parentCommentId,
    );
    final existing = _commentsByMarket[marketId] ?? const [];
    if (parentCommentId == null) {
      _commentsByMarket[marketId] = [created, ...existing];
    } else {
      _commentsByMarket[marketId] = existing.map((c) {
        if (c.id == parentCommentId) {
          return CommentData(
            id: c.id,
            marketId: c.marketId,
            authorWallet: c.authorWallet,
            content: c.content,
            parentCommentId: c.parentCommentId,
            likes: c.likes,
            likeCount: c.likeCount,
            createdAt: c.createdAt,
            replies: [...c.replies, created],
          );
        }
        return c;
      }).toList();
    }
    notifyListeners();
  }

  Future<void> toggleLike(String marketId, String commentId, bool currentlyLiked) async {
    final actor = _address;
    if (actor == null) return;
    try {
      final newCount = currentlyLiked
          ? await _service.unlikeComment(commentId, actor)
          : await _service.likeComment(commentId, actor);
      final existing = _commentsByMarket[marketId] ?? const [];
      _commentsByMarket[marketId] = existing.map((c) {
        if (c.id == commentId) {
          final nextLikes = List<String>.from(c.likes);
          if (currentlyLiked) {
            nextLikes.remove(actor);
          } else if (!nextLikes.contains(actor)) {
            nextLikes.add(actor);
          }
          return CommentData(
            id: c.id,
            marketId: c.marketId,
            authorWallet: c.authorWallet,
            content: c.content,
            parentCommentId: c.parentCommentId,
            likes: nextLikes,
            likeCount: newCount,
            createdAt: c.createdAt,
            replies: c.replies,
          );
        }
        return c;
      }).toList();
      notifyListeners();
    } catch (err) {
      _errors['like:$commentId'] = err.toString();
      notifyListeners();
    }
  }

  // ── Leaderboard ────────────────────────────────────────────────────────

  Future<void> loadLeaderboard() async {
    await _run<List<Map<String, dynamic>>>(
      'leaderboard',
      () => _service.leaderboard(sortBy: _leaderboardSort, period: _leaderboardPeriod),
      () => _dummyLeaderboard(),
      (v, _) { _leaderboard = v; },
    );
  }

  // ── Activity feeds ─────────────────────────────────────────────────────

  Future<void> loadGlobalFeed() async {
    await _run<List<ActivityItem>>(
      'globalFeed',
      () => _service.globalActivity(),
      () => DummyActivity.feed(),
      (v, _) { _globalFeed = v; },
    );
  }

  Future<void> loadFollowingFeed() async {
    final addr = _address;
    if (addr == null) {
      _followingFeed = const [];
      _sources['followingFeed'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<ActivityItem>>(
      'followingFeed',
      () => _service.followingActivity(addr),
      () => DummyActivity.feed(count: 6),
      (v, _) { _followingFeed = v; },
    );
  }

  Future<void> loadYouFeed() async {
    final addr = _address;
    if (addr == null) {
      _youFeed = const [];
      _sources['youFeed'] = AnalyticsSource.dummy;
      notifyListeners();
      return;
    }
    await _run<List<ActivityItem>>(
      'youFeed',
      () => _service.userActivity(addr),
      () => DummyActivity.feed(count: 8),
      (v, _) { _youFeed = v; },
    );
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadSelfProfile(),
      loadLeaderboard(),
      loadGlobalFeed(),
      loadFollowingFeed(),
      loadYouFeed(),
    ]);
  }

  List<Map<String, dynamic>> _dummyLeaderboard() {
    return List.generate(10, (i) => {
      'rank': i + 1,
      'user': '0x${(i + 1).toRadixString(16).padLeft(40, '0')}',
      'displayName': 'Trader #${100 + i}',
      'avatarUrl': null,
      'totalPnl': 5000 - i * 450 + (i * 37 % 200).toDouble(),
      'totalVolume': 20000 - i * 1600,
      'wins': 15 - i,
      'losses': i,
      'winRate': i == 0 ? 0.93 : (15 - i) / (15 - i + i).toDouble(),
      'totalActions': 40 - i * 2,
    });
  }
}

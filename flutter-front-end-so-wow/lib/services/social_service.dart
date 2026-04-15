import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/activity_item.dart';
import '../models/comment_data.dart';
import '../models/user_profile.dart';

/// Thin HTTP client over the /api/v1/* social endpoints. Each method throws
/// on non-200 / parse failure so [SocialProvider] can fall back to dummy.
class SocialService {
  static const String baseUrl = 'http://localhost:4003';
  static const String prefix = '/api/v1';
  static const Duration _timeout = Duration(seconds: 5);

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http
        .get(Uri.parse('$baseUrl$prefix$path'),
            headers: {'Accept': 'application/json'})
        .timeout(_timeout);
    return _parse(res, path);
  }

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$prefix$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    http.Response res;
    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: encoded).timeout(_timeout);
        break;
      case 'PUT':
        res = await http.put(uri, headers: headers, body: encoded).timeout(_timeout);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: headers, body: encoded).timeout(_timeout);
        break;
      default:
        throw Exception('Unsupported method: $method');
    }
    return _parse(res, path);
  }

  Map<String, dynamic> _parse(http.Response res, String path) {
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $path: ${res.body}');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) throw Exception('Bad envelope for $path');
    if (body['error'] == true) {
      throw Exception('${body['message'] ?? 'Backend error'} for $path');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Missing data field for $path');
    }
    return data;
  }

  // ── Users / follows ─────────────────────────────────────────────────────

  Future<UserProfile> getUser(String address) async {
    final data = await _get('/users/$address');
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateUser(String address, {
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final data = await _send('PUT', '/users/$address', body: {
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (bio != null) 'bio': bio,
    });
    return UserProfile.fromJson(data);
  }

  Future<void> follow(String target, String actor) async {
    await _send('POST', '/users/$target/follow', body: {'actor': actor});
  }

  Future<void> unfollow(String target, String actor) async {
    await _send('DELETE', '/users/$target/follow', body: {'actor': actor});
  }

  // ── Comments ────────────────────────────────────────────────────────────

  Future<CommentsPage> getComments(String marketId, {
    String sort = 'newest',
    String? cursor,
    int limit = 20,
  }) async {
    final qs = StringBuffer('?sort=$sort&limit=$limit');
    if (cursor != null) qs.write('&cursor=$cursor');
    final data = await _get('/markets/$marketId/comments${qs.toString()}');
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CommentData.fromJson)
        .toList();
    return CommentsPage(items: items, nextCursor: data['nextCursor'] as String?);
  }

  Future<CommentData> postComment({
    required String marketId,
    required String actor,
    required String content,
    String? parentCommentId,
  }) async {
    final data = await _send('POST', '/markets/$marketId/comments', body: {
      'actor': actor,
      'content': content,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    });
    return CommentData.fromJson(data);
  }

  Future<int> likeComment(String commentId, String actor) async {
    final data = await _send('POST', '/comments/$commentId/like',
        body: {'actor': actor});
    return (data['likeCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> unlikeComment(String commentId, String actor) async {
    final data = await _send('DELETE', '/comments/$commentId/like',
        body: {'actor': actor});
    return (data['likeCount'] as num?)?.toInt() ?? 0;
  }

  // ── Leaderboard ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> leaderboard({
    String sortBy = 'pnl',
    String period = 'monthly',
    int limit = 50,
  }) async {
    final data = await _get(
        '/leaderboard?sortBy=$sortBy&period=$period&limit=$limit');
    return ((data['entries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // ── Activity ────────────────────────────────────────────────────────────

  Future<List<ActivityItem>> globalActivity({String? cursor, int limit = 30}) async {
    final qs = StringBuffer('?limit=$limit');
    if (cursor != null) qs.write('&cursor=$cursor');
    final data = await _get('/activity${qs.toString()}');
    return ((data['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ActivityItem.fromJson)
        .toList();
  }

  Future<List<ActivityItem>> followingActivity(String actor,
      {String? cursor, int limit = 30}) async {
    final qs = StringBuffer('?actor=$actor&limit=$limit');
    if (cursor != null) qs.write('&cursor=$cursor');
    final data = await _get('/activity/following${qs.toString()}');
    return ((data['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ActivityItem.fromJson)
        .toList();
  }

  Future<List<ActivityItem>> userActivity(String address,
      {String? cursor, int limit = 30}) async {
    final qs = StringBuffer('?limit=$limit');
    if (cursor != null) qs.write('&cursor=$cursor');
    final data = await _get('/activity/user/$address${qs.toString()}');
    return ((data['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ActivityItem.fromJson)
        .toList();
  }
}

class CommentsPage {
  final List<CommentData> items;
  final String? nextCursor;
  CommentsPage({required this.items, this.nextCursor});
}

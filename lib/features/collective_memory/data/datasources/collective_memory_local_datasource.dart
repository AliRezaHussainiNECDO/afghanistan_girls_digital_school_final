import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/memory_comment.dart';
import '../../domain/entities/memory_post.dart';

/// قرارداد مشترک DataSource «حافظه جمعی» — Local (این فایل) و Remote (سرور)
/// هر دو آن را پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class CollectiveMemoryDataSource {
  Future<List<MemoryPost>> getPosts();
  Future<MemoryPost> createPost({
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
    required List<String> imagesBase64,
  });
  Future<MemoryPost> updatePost({
    required String postId,
    required String body,
    required List<String> imagesBase64,
  });
  Future<void> deletePost(String postId);
  Future<MemoryPost> toggleReaction({
    required String postId,
    required String emoji,
    required String userId,
  });
  Future<List<MemoryComment>> getComments(String postId);
  Future<MemoryComment> addComment({
    required String postId,
    String? parentCommentId,
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
  });
  Future<void> deleteComment(String commentId);
}

/// ذخیرهٔ محلی «حافظه جمعی» (JSON در SharedPreferences) — حالت آفلاین/تست.
/// طبق درخواست کاربر: بخشی ماندگار و تاریخی برای روایت دختران و زنان
/// افغانستان، با ادیت/دیلیت/کامنت/ریپلای/واکنش.
class CollectiveMemoryLocalDataSource implements CollectiveMemoryDataSource {
  static const _postsKey = 'collective_memory_posts_v1';
  static const _commentsKey = 'collective_memory_comments_v1';
  static const _seededKey = 'collective_memory_seeded_v1';

  Future<List<MemoryPost>> _readPosts() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureSeeded(prefs);
    final raw = prefs.getString(_postsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => MemoryPost.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writePosts(List<MemoryPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_postsKey, jsonEncode(posts.map((p) => p.toJson()).toList()));
  }

  Future<List<MemoryComment>> _readComments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_commentsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => MemoryComment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeComments(List<MemoryComment> comments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_commentsKey, jsonEncode(comments.map((c) => c.toJson()).toList()));
  }

  /// اولین بار که این بخش باز می‌شود، چند روایت نمونهٔ محترمانه (بدون
  /// جزئیات آسیب‌زا) کاشته می‌شود تا فضای خالی نباشد و منطق نمایش قابل
  /// آزمایش باشد — دقیقاً مثل الگوی داده‌های Mock در باقی اپ.
  Future<void> _ensureSeeded(SharedPreferences prefs) async {
    if (prefs.getBool(_seededKey) == true) return;
    final now = DateTime.now();
    final seed = [
      MemoryPost(
        id: 'seed_post_1',
        authorId: 'seed_admin',
        authorName: 'مدیریت مکتب دیجیتال',
        authorIsAdmin: true,
        body:
            'به «حافظهٔ جمعی» خوش آمدید 🌸 این‌جا فضایی امن برای روایت تجربه‌ها، بازدیدها و صدای دختران و زنان افغانستان است. هر داستانی که این‌جا می‌نویسید، بخشی از تاریخ ماندگار می‌شود.',
        imagesBase64: const [],
        createdAt: now.subtract(const Duration(days: 3)),
        reactions: const {'🌸': ['seed_admin'], '🙏': ['seed_admin']},
      ),
      MemoryPost(
        id: 'seed_post_2',
        authorId: 'seed_student_1',
        authorName: 'یکی از دانش‌آموزان',
        authorIsAdmin: false,
        body:
            'وقتی مکتب برایم بسته شد، فکر کردم راه یادگیری‌ام تمام شده. اما حالا هر شب با همین گوشی درس می‌خوانم و به آیندهٔ خودم امیدوارترم. هیچ‌وقت یادگیری را متوقف نکنید، خواهرها.',
        imagesBase64: const [],
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        reactions: const {'💪': ['seed_admin', 'seed_student_1'], '❤️': ['seed_admin']},
      ),
    ];
    await prefs.setString(_postsKey, jsonEncode(seed.map((p) => p.toJson()).toList()));
    await prefs.setBool(_seededKey, true);
  }

  @override
  Future<List<MemoryPost>> getPosts() async {
    final all = await _readPosts();
    return all..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<MemoryPost> createPost({
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
    required List<String> imagesBase64,
  }) async {
    final post = MemoryPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName,
      authorIsAdmin: authorIsAdmin,
      authorAvatarBase64: authorAvatarBase64,
      body: body,
      imagesBase64: imagesBase64,
      createdAt: DateTime.now(),
    );
    final all = await _readPosts();
    all.add(post);
    await _writePosts(all);
    return post;
  }

  @override
  Future<MemoryPost> updatePost({
    required String postId,
    required String body,
    required List<String> imagesBase64,
  }) async {
    final all = await _readPosts();
    final idx = all.indexWhere((p) => p.id == postId);
    if (idx == -1) throw Exception('پست یافت نشد');
    final updated = all[idx].copyWith(
      body: body,
      imagesBase64: imagesBase64,
      updatedAt: DateTime.now(),
    );
    all[idx] = updated;
    await _writePosts(all);
    return updated;
  }

  @override
  Future<void> deletePost(String postId) async {
    final all = await _readPosts();
    all.removeWhere((p) => p.id == postId);
    await _writePosts(all);
    // کامنت‌های وابسته به این پست هم پاک شوند تا یتیم نمانند.
    final comments = await _readComments();
    comments.removeWhere((c) => c.postId == postId);
    await _writeComments(comments);
  }

  @override
  Future<MemoryPost> toggleReaction({
    required String postId,
    required String emoji,
    required String userId,
  }) async {
    final all = await _readPosts();
    final idx = all.indexWhere((p) => p.id == postId);
    if (idx == -1) throw Exception('پست یافت نشد');
    final post = all[idx];
    final reactions = Map<String, List<String>>.from(
      post.reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    final list = reactions.putIfAbsent(emoji, () => []);
    if (list.contains(userId)) {
      list.remove(userId);
      if (list.isEmpty) reactions.remove(emoji);
    } else {
      list.add(userId);
    }
    final updated = post.copyWith(reactions: reactions);
    all[idx] = updated;
    await _writePosts(all);
    return updated;
  }

  @override
  Future<List<MemoryComment>> getComments(String postId) async {
    final all = await _readComments();
    return all.where((c) => c.postId == postId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<MemoryComment> addComment({
    required String postId,
    String? parentCommentId,
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
  }) async {
    final comment = MemoryComment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      parentCommentId: parentCommentId,
      authorId: authorId,
      authorName: authorName,
      authorIsAdmin: authorIsAdmin,
      authorAvatarBase64: authorAvatarBase64,
      body: body,
      createdAt: DateTime.now(),
    );
    final all = await _readComments();
    all.add(comment);
    await _writeComments(all);
    return comment;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final all = await _readComments();
    // اگر این کامنت اصلی است، پاسخ‌های آن هم پاک شوند (بدون یتیم ماندن Reply).
    all.removeWhere((c) => c.id == commentId || c.parentCommentId == commentId);
    await _writeComments(all);
  }
}

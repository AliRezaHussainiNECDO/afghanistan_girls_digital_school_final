import '../../../../core/network/api_client.dart';
import '../../domain/entities/memory_comment.dart';
import '../../domain/entities/memory_post.dart';
import 'collective_memory_local_datasource.dart' show CollectiveMemoryDataSource;

/// پیاده‌سازی واقعی «حافظه جمعی» روی سرور (روتر `/api/v1/memory/*`).
///
/// هویت نویسنده در سرور از JWT گرفته می‌شود؛ فیلدهای authorId/authorName/
/// authorIsAdmin که در امضای مشترک هستند در حالت Remote نادیده گرفته می‌شوند
/// (فقط عکس نویسنده به‌عنوان کمکِ نمایش ارسال می‌شود). این تضمین می‌کند که
/// کاربر نتواند هویت جعلی ثبت کند (اصل بخش ۴).
class CollectiveMemoryRemoteDataSource implements CollectiveMemoryDataSource {
  final ApiClient _api;
  CollectiveMemoryRemoteDataSource(this._api);

  Map<String, dynamic> _map(dynamic d) =>
      d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map);

  @override
  Future<List<MemoryPost>> getPosts() async {
    final data = _map(await _api.get('/memory/posts'));
    final list = (data['posts'] as List? ?? []);
    return list.map((e) => MemoryPost.fromJson(_map(e))).toList();
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
    final data = _map(await _api.post('/memory/posts', data: {
      'body': body,
      'imagesBase64': imagesBase64,
      if (authorAvatarBase64 != null) 'authorAvatarBase64': authorAvatarBase64,
    }));
    return MemoryPost.fromJson(_map(data['post']));
  }

  @override
  Future<MemoryPost> updatePost({
    required String postId,
    required String body,
    required List<String> imagesBase64,
  }) async {
    final data = _map(await _api.patch('/memory/posts/$postId', data: {
      'body': body,
      'imagesBase64': imagesBase64,
    }));
    return MemoryPost.fromJson(_map(data['post']));
  }

  @override
  Future<void> deletePost(String postId) async {
    await _api.delete('/memory/posts/$postId');
  }

  @override
  Future<MemoryPost> toggleReaction({
    required String postId,
    required String emoji,
    required String userId,
  }) async {
    final data = _map(await _api.post('/memory/posts/$postId/reactions', data: {'emoji': emoji}));
    return MemoryPost.fromJson(_map(data['post']));
  }

  @override
  Future<List<MemoryComment>> getComments(String postId) async {
    final data = _map(await _api.get('/memory/posts/$postId/comments'));
    final list = (data['comments'] as List? ?? []);
    return list.map((e) => MemoryComment.fromJson(_map(e))).toList();
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
    final data = _map(await _api.post('/memory/posts/$postId/comments', data: {
      'body': body,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      if (authorAvatarBase64 != null) 'authorAvatarBase64': authorAvatarBase64,
    }));
    return MemoryComment.fromJson(_map(data['comment']));
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _api.delete('/memory/comments/$commentId');
  }
}

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/memory_comment.dart';
import '../entities/memory_post.dart';

abstract class CollectiveMemoryRepository {
  Future<Either<Failure, List<MemoryPost>>> getPosts();

  Future<Either<Failure, MemoryPost>> createPost({
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
    required List<String> imagesBase64,
  });

  Future<Either<Failure, MemoryPost>> updatePost({
    required String postId,
    required String body,
    required List<String> imagesBase64,
  });

  Future<Either<Failure, Unit>> deletePost(String postId);

  Future<Either<Failure, MemoryPost>> toggleReaction({
    required String postId,
    required String emoji,
    required String userId,
  });

  Future<Either<Failure, List<MemoryComment>>> getComments(String postId);

  Future<Either<Failure, MemoryComment>> addComment({
    required String postId,
    String? parentCommentId,
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
  });

  Future<Either<Failure, Unit>> deleteComment(String commentId);
}

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/memory_comment.dart';
import '../../domain/entities/memory_post.dart';
import '../../domain/repositories/collective_memory_repository.dart';
import '../datasources/collective_memory_local_datasource.dart'
    show CollectiveMemoryDataSource;

class CollectiveMemoryRepositoryImpl implements CollectiveMemoryRepository {
  final CollectiveMemoryDataSource dataSource;
  CollectiveMemoryRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<MemoryPost>>> getPosts() async {
    try {
      return Right(await dataSource.getPosts());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MemoryPost>> createPost({
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
    required List<String> imagesBase64,
  }) async {
    try {
      return Right(await dataSource.createPost(
        authorId: authorId,
        authorName: authorName,
        authorIsAdmin: authorIsAdmin,
        authorAvatarBase64: authorAvatarBase64,
        body: body,
        imagesBase64: imagesBase64,
      ));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MemoryPost>> updatePost({
    required String postId,
    required String body,
    required List<String> imagesBase64,
  }) async {
    try {
      return Right(await dataSource.updatePost(postId: postId, body: body, imagesBase64: imagesBase64));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePost(String postId) async {
    try {
      await dataSource.deletePost(postId);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MemoryPost>> toggleReaction({
    required String postId,
    required String emoji,
    required String userId,
  }) async {
    try {
      return Right(await dataSource.toggleReaction(postId: postId, emoji: emoji, userId: userId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MemoryComment>>> getComments(String postId) async {
    try {
      return Right(await dataSource.getComments(postId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MemoryComment>> addComment({
    required String postId,
    String? parentCommentId,
    required String authorId,
    required String authorName,
    required bool authorIsAdmin,
    String? authorAvatarBase64,
    required String body,
  }) async {
    try {
      return Right(await dataSource.addComment(
        postId: postId,
        parentCommentId: parentCommentId,
        authorId: authorId,
        authorName: authorName,
        authorIsAdmin: authorIsAdmin,
        authorAvatarBase64: authorAvatarBase64,
        body: body,
      ));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) async {
    try {
      await dataSource.deleteComment(commentId);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}

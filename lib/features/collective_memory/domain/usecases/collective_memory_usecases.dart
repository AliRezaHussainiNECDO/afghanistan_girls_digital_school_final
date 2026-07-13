import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/memory_comment.dart';
import '../entities/memory_post.dart';
import '../repositories/collective_memory_repository.dart';

class GetPostsUseCase implements UseCase<List<MemoryPost>, NoParams> {
  final CollectiveMemoryRepository repository;
  GetPostsUseCase(this.repository);
  @override
  Future<Either<Failure, List<MemoryPost>>> call(NoParams params) => repository.getPosts();
}

class CreatePostParams extends Equatable {
  final String authorId;
  final String authorName;
  final bool authorIsAdmin;
  final String? authorAvatarBase64;
  final String body;
  final List<String> imagesBase64;
  const CreatePostParams({
    required this.authorId,
    required this.authorName,
    required this.authorIsAdmin,
    this.authorAvatarBase64,
    required this.body,
    required this.imagesBase64,
  });
  @override
  List<Object?> get props => [authorId, body, imagesBase64];
}

class CreatePostUseCase implements UseCase<MemoryPost, CreatePostParams> {
  final CollectiveMemoryRepository repository;
  CreatePostUseCase(this.repository);
  @override
  Future<Either<Failure, MemoryPost>> call(CreatePostParams params) => repository.createPost(
        authorId: params.authorId,
        authorName: params.authorName,
        authorIsAdmin: params.authorIsAdmin,
        authorAvatarBase64: params.authorAvatarBase64,
        body: params.body,
        imagesBase64: params.imagesBase64,
      );
}

class UpdatePostParams extends Equatable {
  final String postId;
  final String body;
  final List<String> imagesBase64;
  const UpdatePostParams({required this.postId, required this.body, required this.imagesBase64});
  @override
  List<Object?> get props => [postId, body, imagesBase64];
}

class UpdatePostUseCase implements UseCase<MemoryPost, UpdatePostParams> {
  final CollectiveMemoryRepository repository;
  UpdatePostUseCase(this.repository);
  @override
  Future<Either<Failure, MemoryPost>> call(UpdatePostParams params) => repository.updatePost(
        postId: params.postId,
        body: params.body,
        imagesBase64: params.imagesBase64,
      );
}

class DeletePostUseCase implements UseCase<Unit, String> {
  final CollectiveMemoryRepository repository;
  DeletePostUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String postId) => repository.deletePost(postId);
}

class ToggleReactionParams extends Equatable {
  final String postId;
  final String emoji;
  final String userId;
  const ToggleReactionParams({required this.postId, required this.emoji, required this.userId});
  @override
  List<Object?> get props => [postId, emoji, userId];
}

class ToggleReactionUseCase implements UseCase<MemoryPost, ToggleReactionParams> {
  final CollectiveMemoryRepository repository;
  ToggleReactionUseCase(this.repository);
  @override
  Future<Either<Failure, MemoryPost>> call(ToggleReactionParams params) =>
      repository.toggleReaction(postId: params.postId, emoji: params.emoji, userId: params.userId);
}

class GetCommentsUseCase implements UseCase<List<MemoryComment>, String> {
  final CollectiveMemoryRepository repository;
  GetCommentsUseCase(this.repository);
  @override
  Future<Either<Failure, List<MemoryComment>>> call(String postId) => repository.getComments(postId);
}

class AddCommentParams extends Equatable {
  final String postId;
  final String? parentCommentId;
  final String authorId;
  final String authorName;
  final bool authorIsAdmin;
  final String? authorAvatarBase64;
  final String body;
  const AddCommentParams({
    required this.postId,
    this.parentCommentId,
    required this.authorId,
    required this.authorName,
    required this.authorIsAdmin,
    this.authorAvatarBase64,
    required this.body,
  });
  @override
  List<Object?> get props => [postId, parentCommentId, authorId, body];
}

class AddCommentUseCase implements UseCase<MemoryComment, AddCommentParams> {
  final CollectiveMemoryRepository repository;
  AddCommentUseCase(this.repository);
  @override
  Future<Either<Failure, MemoryComment>> call(AddCommentParams params) => repository.addComment(
        postId: params.postId,
        parentCommentId: params.parentCommentId,
        authorId: params.authorId,
        authorName: params.authorName,
        authorIsAdmin: params.authorIsAdmin,
        authorAvatarBase64: params.authorAvatarBase64,
        body: params.body,
      );
}

class DeleteCommentUseCase implements UseCase<Unit, String> {
  final CollectiveMemoryRepository repository;
  DeleteCommentUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String commentId) => repository.deleteComment(commentId);
}

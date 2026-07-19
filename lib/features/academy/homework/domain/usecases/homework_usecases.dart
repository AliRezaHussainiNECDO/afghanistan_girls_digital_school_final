import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/homework.dart';
import '../repositories/homework_repository.dart';

class GetHomeworksParams extends Equatable {
  final HomeworkStatus? status;
  /// فقط برای نمای مدیر روی پروندهٔ یک شاگرد مشخص — در حالت عادی (شاگرد
  /// خودش) خالی می‌ماند.
  final String? studentId;
  const GetHomeworksParams({this.status, this.studentId});
  @override
  List<Object?> get props => [status, studentId];
}

class GetHomeworksUseCase implements UseCase<HomeworkListResult, GetHomeworksParams> {
  final HomeworkRepository repository;
  GetHomeworksUseCase(this.repository);
  @override
  Future<Either<Failure, HomeworkListResult>> call(GetHomeworksParams params) =>
      repository.getHomeworks(status: params.status, studentId: params.studentId);
}

class GetHomeworkByIdUseCase implements UseCase<Homework, String> {
  final HomeworkRepository repository;
  GetHomeworkByIdUseCase(this.repository);
  @override
  Future<Either<Failure, Homework>> call(String id) => repository.getHomeworkById(id);
}

class GetHomeworkRepliesUseCase implements UseCase<List<HomeworkReply>, String> {
  final HomeworkRepository repository;
  GetHomeworkRepliesUseCase(this.repository);
  @override
  Future<Either<Failure, List<HomeworkReply>>> call(String homeworkId) =>
      repository.getReplies(homeworkId);
}

class SubmitHomeworkPhotoParams extends Equatable {
  final String homeworkId;
  final List<int> bytes;
  final String fileName;
  final String contentType;
  const SubmitHomeworkPhotoParams({
    required this.homeworkId,
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });
  @override
  List<Object?> get props => [homeworkId, fileName, bytes.length];
}

/// ارسال عکس دست‌خط شاگرد — قلب این ویژگی: عکس روی R2 ذخیره و با Vision
/// نمره‌دهی می‌شود (طبق `POST /homework/:id/submit`).
class SubmitHomeworkPhotoUseCase implements UseCase<Homework, SubmitHomeworkPhotoParams> {
  final HomeworkRepository repository;
  SubmitHomeworkPhotoUseCase(this.repository);
  @override
  Future<Either<Failure, Homework>> call(SubmitHomeworkPhotoParams params) => repository.submitPhoto(
        homeworkId: params.homeworkId,
        bytes: params.bytes,
        fileName: params.fileName,
        contentType: params.contentType,
      );
}

class SendHomeworkReplyParams extends Equatable {
  final String homeworkId;
  final String text;
  const SendHomeworkReplyParams({required this.homeworkId, required this.text});
  @override
  List<Object?> get props => [homeworkId, text];
}

class SendHomeworkReplyUseCase implements UseCase<List<HomeworkReply>, SendHomeworkReplyParams> {
  final HomeworkRepository repository;
  SendHomeworkReplyUseCase(this.repository);
  @override
  Future<Either<Failure, List<HomeworkReply>>> call(SendHomeworkReplyParams params) =>
      repository.sendReply(homeworkId: params.homeworkId, text: params.text);
}

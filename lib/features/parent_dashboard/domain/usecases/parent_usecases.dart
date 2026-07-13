import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repository.dart';

class GetLinkedChildrenUseCase implements UseCase<List<LinkedChild>, String> {
  final ParentRepository repository;
  GetLinkedChildrenUseCase(this.repository);
  @override
  Future<Either<Failure, List<LinkedChild>>> call(String parentId) =>
      repository.getLinkedChildren(parentId);
}

class GetChildSummaryUseCase implements UseCase<ChildSummary, String> {
  final ParentRepository repository;
  GetChildSummaryUseCase(this.repository);
  @override
  Future<Either<Failure, ChildSummary>> call(String studentId) => repository.getChildSummary(studentId);
}

/// خروجی موفق = نام فرزند لینک‌شده (برای پیام «فرزند شما اضافه شد»).
class SubmitInviteCodeUseCase implements UseCase<String, SubmitInviteParams> {
  final ParentRepository repository;
  SubmitInviteCodeUseCase(this.repository);
  @override
  Future<Either<Failure, String>> call(SubmitInviteParams params) =>
      repository.submitInviteCode(params);
}

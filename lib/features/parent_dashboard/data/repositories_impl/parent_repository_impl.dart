import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/repositories/parent_repository.dart';
import '../datasources/parent_remote_datasource.dart' show ParentDataSource;

class ParentRepositoryImpl implements ParentRepository {
  final ParentDataSource dataSource;
  ParentRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<LinkedChild>>> getLinkedChildren(String parentId) async {
    try {
      return Right(await dataSource.getLinkedChildren(parentId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChildSummary>> getChildSummary(String studentId) async {
    try {
      return Right(await dataSource.getChildSummary(studentId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> submitInviteCode(SubmitInviteParams params) async {
    try {
      return Right(await dataSource.submitInviteCode(params.parentId, params.code,
          parentName: params.parentName));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      // GuardianLinkStore (Mock) پیام‌های خطای خوانا را به‌صورت String پرتاب می‌کند.
      return Left(ValidationFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : ValidationFailure(e.message);
}

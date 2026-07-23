/// پیاده‌سازی Concrete از Interface لایهٔ domain (بخش ۲۴.۳).

library;
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/student_entities.dart';
import '../../domain/repositories/student_management_repository.dart';
import '../datasources/remote/student_management_remote_datasource.dart';

class StudentManagementRepositoryImpl implements StudentManagementRepository {
  final StudentManagementRemoteDataSource remote;
  const StudentManagementRepositoryImpl(this.remote);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      if (e.response?.statusCode == 403) return const Left(PermissionFailure());
      return Left(ServerFailure(
          e.response?.data?['message']?.toString() ?? e.message ?? e.toString(),
          code: e.response?.statusCode?.toString()));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));

  @override
  Future<Either<Failure, PagedStudents>> getStudents(
          StudentListFilter filter) =>
      _guard(() => remote.fetchStudents(filter));

  @override
  Future<Either<Failure, StudentDetail>> getStudentDetail(String studentId) =>
      _guard(() => remote.fetchStudentDetail(studentId));

  @override
  Future<Either<Failure, AiTeacherReport>> getAiReport(String studentId) =>
      _guard(() => remote.fetchAiReport(studentId));

  @override
  Future<Either<Failure, void>> updateStatus(
          String studentId, AccountStatus status, String reason) =>
      _guard(() => remote.patchStatus(studentId, status, reason));

  @override
  Future<Either<Failure, void>> softDelete(String studentId, String reason) =>
      _guard(() => remote.softDelete(studentId, reason));

  @override
  Future<Either<Failure, void>> sendPasswordResetLink(String studentId) =>
      _guard(() => remote.sendPasswordResetLink(studentId));

  @override
  Future<Either<Failure, int>> promoteStudent(String studentId) =>
      _guard(() => remote.promoteGrade(studentId));

  @override
  Future<Either<Failure, int>> demoteStudent(String studentId) =>
      _guard(() => remote.demoteGrade(studentId));
}

import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/homework.dart';
import '../../domain/repositories/homework_repository.dart';
import '../datasources/homework_datasource.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  final HomeworkDataSource dataSource;
  HomeworkRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, HomeworkListResult>> getHomeworks({HomeworkStatus? status, String? studentId}) async {
    try {
      return Right(await dataSource.getHomeworks(status: status, studentId: studentId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Homework>> getHomeworkById(String id) async {
    try {
      return Right(await dataSource.getHomeworkById(id));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HomeworkReply>>> getReplies(String homeworkId) async {
    try {
      return Right(await dataSource.getReplies(homeworkId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Homework>> submitPhoto({
    required String homeworkId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    try {
      return Right(await dataSource.submitPhoto(
        homeworkId: homeworkId,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      ));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      // آپلود چندبخشی از `Dio.raw` می‌آید و ممکن است `DioException` خام
      // پرتاب شود (نه `ApiException`) — این‌جا هم Fail-safe می‌ماند تا کاربر
      // به‌جای Crash، پیام خطای خوانا ببیند.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HomeworkReply>>> sendReply({
    required String homeworkId,
    required String text,
  }) async {
    try {
      return Right(await dataSource.sendReply(homeworkId: homeworkId, text: text));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}

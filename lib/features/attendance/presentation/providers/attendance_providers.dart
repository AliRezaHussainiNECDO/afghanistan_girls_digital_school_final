import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/attendance_mock_datasource.dart';
import '../../data/datasources/attendance_remote_datasource.dart';
import '../../data/repositories_impl/attendance_repository_impl.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/get_attendance_summary_usecase.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final attendanceDataSourceProvider = Provider<AttendanceDataSource>((ref) {
  if (kUseLiveBackend) {
    return AttendanceRemoteDataSource(ref.watch(apiClientProvider));
  }
  return AttendanceMockDataSource();
});
final attendanceRepositoryProvider =
    Provider<AttendanceRepository>((ref) => AttendanceRepositoryImpl(ref.watch(attendanceDataSourceProvider)));
final getAttendanceSummaryUseCaseProvider =
    Provider((ref) => GetAttendanceSummaryUseCase(ref.watch(attendanceRepositoryProvider)));

final attendanceSummaryProvider = FutureProvider.family<AttendanceSummary, String>((ref, studentId) async {
  final result = await ref.read(getAttendanceSummaryUseCaseProvider).call(studentId);
  return result.fold((f) => throw f, (v) => v);
});

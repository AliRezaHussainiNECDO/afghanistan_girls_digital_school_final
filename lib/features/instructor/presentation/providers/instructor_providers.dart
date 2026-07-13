import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../shared_models/seminar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/instructor_mock_datasource.dart';
import '../../data/datasources/instructor_remote_datasource.dart';
import '../../data/repositories_impl/instructor_repository_impl.dart';
import '../../domain/repositories/instructor_repository.dart';
import '../../domain/usecases/instructor_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final instructorDataSourceProvider = Provider<InstructorDataSource>((ref) {
  if (kUseLiveBackend) {
    return InstructorRemoteDataSource(ref.watch(apiClientProvider));
  }
  return InstructorMockDataSource();
});

final instructorRepositoryProvider = Provider<InstructorRepository>(
  (ref) => InstructorRepositoryImpl(ref.watch(instructorDataSourceProvider)),
);

final getMySeminarsUseCaseProvider =
    Provider((ref) => GetMySeminarsUseCase(ref.watch(instructorRepositoryProvider)));

final createSeminarUseCaseProvider =
    Provider((ref) => CreateSeminarUseCase(ref.watch(instructorRepositoryProvider)));

final updateSeminarUseCaseProvider =
    Provider((ref) => UpdateSeminarUseCase(ref.watch(instructorRepositoryProvider)));

final deleteSeminarUseCaseProvider =
    Provider((ref) => DeleteSeminarUseCase(ref.watch(instructorRepositoryProvider)));

final setSeminarStatusUseCaseProvider =
    Provider((ref) => SetSeminarStatusUseCase(ref.watch(instructorRepositoryProvider)));

/// سمینارهای خود استاد واردشده.
final myInstructorSeminarsProvider = FutureProvider.autoDispose<List<Seminar>>((ref) async {
  final user = ref.watch(authSessionProvider);
  final result = await ref.read(getMySeminarsUseCaseProvider).call(user?.id ?? '');
  return result.fold((f) => throw f, (v) => v);
});

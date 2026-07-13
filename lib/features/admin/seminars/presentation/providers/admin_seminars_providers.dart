import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../shared_models/seminar.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/admin_seminars_mock_datasource.dart';
import '../../data/datasources/admin_seminars_remote_datasource.dart';
import '../../data/repositories_impl/admin_seminars_repository_impl.dart';
import '../../domain/repositories/admin_seminars_repository.dart';
import '../../domain/usecases/admin_seminars_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final adminSeminarsDataSourceProvider = Provider<AdminSeminarsDataSource>((ref) {
  if (kUseLiveBackend) {
    return AdminSeminarsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return AdminSeminarsMockDataSource();
});

final adminSeminarsRepositoryProvider = Provider<AdminSeminarsRepository>(
  (ref) => AdminSeminarsRepositoryImpl(ref.watch(adminSeminarsDataSourceProvider)),
);

final getAdminSeminarsUseCaseProvider =
    Provider((ref) => GetAdminSeminarsUseCase(ref.watch(adminSeminarsRepositoryProvider)));

final createAdminSeminarUseCaseProvider =
    Provider((ref) => CreateAdminSeminarUseCase(ref.watch(adminSeminarsRepositoryProvider)));

final updateAdminSeminarUseCaseProvider =
    Provider((ref) => UpdateAdminSeminarUseCase(ref.watch(adminSeminarsRepositoryProvider)));

final deleteAdminSeminarUseCaseProvider =
    Provider((ref) => DeleteAdminSeminarUseCase(ref.watch(adminSeminarsRepositoryProvider)));

final setAdminSeminarStatusUseCaseProvider =
    Provider((ref) => SetAdminSeminarStatusUseCase(ref.watch(adminSeminarsRepositoryProvider)));

final adminSeminarsProvider = FutureProvider.autoDispose<List<Seminar>>((ref) async {
  final result = await ref.read(getAdminSeminarsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

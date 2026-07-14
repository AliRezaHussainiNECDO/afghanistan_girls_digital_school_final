import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/system_health_mock_datasource.dart';
import '../../data/datasources/system_health_remote_datasource.dart';
import '../../data/repositories_impl/system_health_repository_impl.dart';
import '../../domain/entities/system_health.dart';
import '../../domain/repositories/system_health_repository.dart';
import '../../domain/usecases/get_system_health_usecase.dart';

final systemHealthDataSourceProvider = Provider<SystemHealthDataSource>((ref) {
  if (kUseLiveBackend) {
    return SystemHealthRemoteDataSource(ref.watch(apiClientProvider));
  }
  return SystemHealthMockDataSource();
});

final systemHealthRepositoryProvider = Provider<SystemHealthRepository>(
  (ref) => SystemHealthRepositoryImpl(ref.watch(systemHealthDataSourceProvider)),
);

final getSystemHealthUseCaseProvider =
    Provider((ref) => GetSystemHealthUseCase(ref.watch(systemHealthRepositoryProvider)));

final systemHealthProvider = FutureProvider.autoDispose<SystemHealth>((ref) async {
  final result = await ref.read(getSystemHealthUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final systemHealthAutoRefreshProvider = StateProvider.autoDispose<bool>((ref) => true);

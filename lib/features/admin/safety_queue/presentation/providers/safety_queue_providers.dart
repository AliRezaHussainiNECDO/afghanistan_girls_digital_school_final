import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/safety_queue_mock_datasource.dart';
import '../../data/datasources/safety_queue_remote_datasource.dart';
import '../../data/repositories_impl/safety_queue_repository_impl.dart';
import '../../domain/entities/safety_queue_item.dart';
import '../../domain/repositories/safety_queue_repository.dart';
import '../../domain/usecases/safety_queue_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final safetyQueueDataSourceProvider = Provider<SafetyQueueDataSource>((ref) {
  if (kUseLiveBackend) {
    return SafetyQueueRemoteDataSource(ref.watch(apiClientProvider));
  }
  return SafetyQueueMockDataSource();
});
final safetyQueueRepositoryProvider = Provider<SafetyQueueRepository>(
  (ref) => SafetyQueueRepositoryImpl(ref.watch(safetyQueueDataSourceProvider)),
);
final getSafetyQueueUseCaseProvider =
    Provider((ref) => GetSafetyQueueUseCase(ref.watch(safetyQueueRepositoryProvider)));
final resolveSafetyItemUseCaseProvider =
    Provider((ref) => ResolveSafetyItemUseCase(ref.watch(safetyQueueRepositoryProvider)));

final safetyQueueProvider = FutureProvider<List<SafetyQueueItem>>((ref) async {
  final result = await ref.read(getSafetyQueueUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

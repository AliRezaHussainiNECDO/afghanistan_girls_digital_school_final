import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/admin_dashboard_mock_datasource.dart';
import '../../data/datasources/admin_dashboard_remote_datasource.dart';
import '../../data/repositories_impl/admin_dashboard_repository_impl.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';
import '../../domain/usecases/get_admin_stats_usecase.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final adminDashboardDataSourceProvider = Provider<AdminDashboardDataSource>((ref) {
  if (kUseLiveBackend) {
    return AdminDashboardRemoteDataSource(ref.watch(apiClientProvider));
  }
  return AdminDashboardMockDataSource();
});
final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>(
  (ref) => AdminDashboardRepositoryImpl(ref.watch(adminDashboardDataSourceProvider)),
);
final getAdminStatsUseCaseProvider =
    Provider((ref) => GetAdminStatsUseCase(ref.watch(adminDashboardRepositoryProvider)));

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final result = await ref.read(getAdminStatsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

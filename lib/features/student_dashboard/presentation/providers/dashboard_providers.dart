import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/dashboard_mock_datasource.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories_impl/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary_usecase.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final dashboardDataSourceProvider = Provider<DashboardDataSource>((ref) {
  if (kUseLiveBackend) {
    return DashboardRemoteDataSource(ref.watch(apiClientProvider));
  }
  return DashboardMockDataSource();
});

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.watch(dashboardDataSourceProvider)),
);

final getDashboardSummaryUseCaseProvider =
    Provider((ref) => GetDashboardSummaryUseCase(ref.watch(dashboardRepositoryProvider)));

final dashboardSummaryProvider = FutureProvider.family<DashboardSummary, String>((ref, studentId) async {
  final result = await ref.read(getDashboardSummaryUseCaseProvider).call(studentId);
  return result.fold((failure) => throw failure, (summary) => summary);
});

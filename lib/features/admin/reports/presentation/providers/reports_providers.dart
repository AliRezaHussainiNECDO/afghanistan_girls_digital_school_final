import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/reports_mock_datasource.dart';
import '../../data/datasources/reports_remote_datasource.dart';
import '../../data/repositories_impl/reports_repository_impl.dart';
import '../../domain/entities/report_row.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../domain/usecases/get_summary_report_usecase.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final reportsDataSourceProvider = Provider<ReportsDataSource>((ref) {
  if (kUseLiveBackend) {
    return ReportsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ReportsMockDataSource();
});
final reportsRepositoryProvider =
    Provider<ReportsRepository>((ref) => ReportsRepositoryImpl(ref.watch(reportsDataSourceProvider)));
final getSummaryReportUseCaseProvider =
    Provider((ref) => GetSummaryReportUseCase(ref.watch(reportsRepositoryProvider)));

final summaryReportProvider = FutureProvider<List<ReportRow>>((ref) async {
  final result = await ref.read(getSummaryReportUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

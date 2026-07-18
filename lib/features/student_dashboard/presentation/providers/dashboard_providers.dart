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

// رفع اشکال «پیشرفت/امتیاز خانهٔ شاگرد به‌روز نمی‌شود»: این Provider نه
// `autoDispose` بود نه هیچ‌جای برنامه بعد از رویدادهای امتیازآور (دیدن درس،
// تکمیل فصل، امتحان) invalidate می‌شد — یعنی بعد از باز شدن اولین‌بارهٔ خانهٔ
// شاگرد در یک نشست برنامه، «پیشرفت کلی» و «امتیاز» تا وقتی برنامه کاملاً
// بسته/باز نمی‌شد ثابت می‌ماندند، حتی اگر شاگرد همان لحظه چند درس را تمام
// کرده و امتیاز واقعی گرفته باشد. با `autoDispose`، هر بار که این صفحه از
// درخت ویجت خارج شود (مثلاً رفتن به تب دیگر که خانه را کاملاً dispose کند)
// و دوباره باز شود، دوباره از سرور خوانده می‌شود؛ علاوه بر آن، محل واقعیِ
// «دیدن درس» (`lesson_detail_screen.dart`) اکنون صریحاً همین Provider را هم
// invalidate می‌کند تا حتی وقتی خانه در پس‌زمینه (تب) زنده مانده، بلافاصله
// به‌روز شود.
final dashboardSummaryProvider = FutureProvider.autoDispose.family<DashboardSummary, String>((ref, studentId) async {
  final result = await ref.watch(getDashboardSummaryUseCaseProvider).call(studentId);
  return result.fold((failure) => throw failure, (summary) => summary);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared_models/app_notification.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/notifications_mock_datasource.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/repositories_impl/notifications_repository_impl.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/notifications_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final notificationsDataSourceProvider = Provider<NotificationsDataSource>((ref) {
  if (kUseLiveBackend) {
    return NotificationsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return NotificationsMockDataSource();
});
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(ref.watch(notificationsDataSourceProvider)),
);
final getNotificationsUseCaseProvider =
    Provider((ref) => GetNotificationsUseCase(ref.watch(notificationsRepositoryProvider)));
final markNotificationReadUseCaseProvider =
    Provider((ref) => MarkNotificationReadUseCase(ref.watch(notificationsRepositoryProvider)));

/// رفع اشکال امنیتی «نشتِ اعلان بین حساب‌ها»: این Provider اکنون به
/// `authSessionProvider` وابسته است (`ref.watch`) — یعنی با هر ورود/خروج یا
/// تعویض حساب روی همان دستگاه، خودکار دوباره اجرا می‌شود و [NotificationCenter]
/// را با شناسهٔ مالکِ تازه هماهنگ می‌کند تا اعلان‌های حساب قبلی (به‌ویژه
/// موارد حساس مثل نمره، پیام خصوصی/چت، اعلان حساب) هرگز روی صفحهٔ کاربر تازه
/// نمانَد. وقتی کاربری نشستهٔ فعال ندارد (مثلاً هنوز وارد نشده)، فهرست خالی
/// برمی‌گردد — هیچ درخواستی به سرور نمی‌رود.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(authSessionProvider);
  NotificationCenter.instance.setOwner(user?.id);
  if (user == null) return const [];
  final result = await ref.read(getNotificationsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

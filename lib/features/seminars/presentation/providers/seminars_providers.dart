import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../shared_models/seminar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/seminars_mock_datasource.dart';
import '../../data/datasources/seminars_remote_datasource.dart';
import '../../data/services/seminar_live_service.dart';
import '../../data/services/seminar_registrations_service.dart';
import '../../data/repositories_impl/seminars_repository_impl.dart';
import '../../domain/repositories/seminars_repository.dart';
import '../../domain/usecases/seminars_usecases.dart';

/// نگاشت پیام‌های خطای منبع دادهٔ Mock فاز ۱ (`SeminarStore`) به کلیدهای
/// ترجمه — در فاز ۲ که با کد خطای سرور واقعی جایگزین شود، این نگاشت هم به
/// همان کدها منتقل می‌شود.
String localizeSeminarFailureMessage(BuildContext context, String raw) {
  switch (raw) {
    case 'سمینار یافت نشد':
      return context.tr('seminars.notFound');
    case 'شما قبلاً در این سمینار ثبت‌نام کرده‌اید':
      return context.tr('seminars.alreadyRegistered');
    case 'این سمینار پایان یافته است':
      return context.tr('seminars.hasEndedError');
    case 'ثبت‌نام این سمینار بسته شده است':
      return context.tr('seminars.registrationClosedError');
    case 'ظرفیت این سمینار تکمیل شده است':
      return context.tr('seminars.capacityFullError');
    default:
      return raw;
  }
}

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final seminarsDataSourceProvider = Provider<SeminarsDataSource>((ref) {
  if (kUseLiveBackend) {
    return SeminarsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return SeminarsMockDataSource();
});
final seminarsRepositoryProvider =
    Provider<SeminarsRepository>((ref) => SeminarsRepositoryImpl(ref.watch(seminarsDataSourceProvider)));
final getUpcomingSeminarsUseCaseProvider =
    Provider((ref) => GetUpcomingSeminarsUseCase(ref.watch(seminarsRepositoryProvider)));
final getSeminarByIdUseCaseProvider =
    Provider((ref) => GetSeminarByIdUseCase(ref.watch(seminarsRepositoryProvider)));
final registerSeminarUseCaseProvider =
    Provider((ref) => RegisterSeminarUseCase(ref.watch(seminarsRepositoryProvider)));
final setSeminarStatusUseCaseProvider =
    Provider((ref) => SetSeminarStatusUseCase(ref.watch(seminarsRepositoryProvider)));

/// سرویس پخش زندهٔ Cloudflare Stream (شروع/پایان پخش توسط استاد/مدیر).
final seminarLiveServiceProvider = Provider<SeminarLiveService>(
  (ref) => SeminarLiveService(ref.watch(apiClientProvider)),
);

/// سرویس فهرست ثبت‌نامی‌های سمینار (فقط استاد/مدیر).
final seminarRegistrationsServiceProvider = Provider<SeminarRegistrationsService>(
  (ref) => SeminarRegistrationsService(ref.watch(apiClientProvider)),
);

/// فهرست ثبت‌نامی‌های یک سمینار — بارگذاری تنبل هنگام باز کردن دیالوگ مدیر.
final seminarRegistrationsProvider =
    FutureProvider.autoDispose.family<List<SeminarRegistrant>, String>((ref, seminarId) async {
  return ref.read(seminarRegistrationsServiceProvider).getRegistrations(seminarId);
});

/// سمینارهای شاگردان (مخاطب: students).
final upcomingSeminarsProvider = FutureProvider.autoDispose<List<Seminar>>((ref) async {
  final result =
      await ref.read(getUpcomingSeminarsUseCaseProvider).call(SeminarAudience.students);
  return result.fold((f) => throw f, (v) => v);
});

/// سمینارهای ویژهٔ والدین (مخاطب: parents) — والد فقط همین‌ها را می‌بیند.
final parentSeminarsProvider = FutureProvider.autoDispose<List<Seminar>>((ref) async {
  final result =
      await ref.read(getUpcomingSeminarsUseCaseProvider).call(SeminarAudience.parents);
  return result.fold((f) => throw f, (v) => v);
});

/// جزئیات یک سمینار (اتاق کنفرانس).
final seminarByIdProvider =
    FutureProvider.autoDispose.family<Seminar, String>((ref, id) async {
  final result = await ref.read(getSeminarByIdUseCaseProvider).call(id);
  return result.fold((f) => throw f, (v) => v);
});

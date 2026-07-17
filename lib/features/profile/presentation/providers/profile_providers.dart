import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_mock_datasource.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories_impl/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/generate_guardian_invite_code_usecase.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final profileDataSourceProvider = Provider<ProfileDataSource>((ref) {
  if (kUseLiveBackend) {
    return ProfileRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ProfileMockDataSource();
});
final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepositoryImpl(ref.watch(profileDataSourceProvider)));
final generateGuardianInviteCodeUseCaseProvider =
    Provider((ref) => GenerateGuardianInviteCodeUseCase(ref.watch(profileRepositoryProvider)));

/// پیش‌نمایش فوری/محلیِ عکس پروفایل (Optimistic UI) بلافاصله پس از انتخاب
/// عکس — آپلود واقعی و ماندگار روی سرور (R2) از طریق
/// `AuthSessionNotifier.uploadAvatar` انجام می‌شود که `avatarUrl` واقعی را
/// در `authSessionProvider` ذخیره می‌کند؛ همان مقدار است که در همهٔ
/// دستگاه‌ها/بخش‌ها دیده می‌شود. این Provider فقط برای نمایش آنیِ محلی است.
final profilePhotoProvider = StateProvider<Uint8List?>((ref) => null);

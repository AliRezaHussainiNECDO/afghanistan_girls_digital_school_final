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

/// عکس پروفایل کاربر واردشده — فاز ۱: فقط در حافظه (per session)، بدون
/// آپلود واقعی به سرور. با خروج از حساب پاک می‌شود (به‌صورت دستی ری‌ست کنید).
final profilePhotoProvider = StateProvider<Uint8List?>((ref) => null);

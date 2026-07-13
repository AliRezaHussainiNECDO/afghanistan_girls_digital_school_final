import '../../../../core/network/api_client.dart';
import '../../../../core/student/guardian_link_store.dart';
import '../../domain/repositories/profile_repository.dart';

/// قرارداد مشترک DataSource پروفایل — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class ProfileDataSource {
  Future<GuardianInviteCode> generateGuardianInviteCode(GuardianInviteParams params);
}

/// پیاده‌سازی واقعی — `POST /api/v1/students/me/guardian-code` (بخش ۲.۴).
/// کد ۶ رقمی روی سرور تولید و ذخیره می‌شود تا والد بتواند با آن پیوند بزند.
class ProfileRemoteDataSource implements ProfileDataSource {
  final ApiClient _api;
  ProfileRemoteDataSource(this._api);

  @override
  Future<GuardianInviteCode> generateGuardianInviteCode(GuardianInviteParams params) async {
    final data = await _api.post('/students/me/guardian-code');
    final now = DateTime.now();
    return GuardianInviteCode(
      code: data['code'] as String,
      studentId: params.studentId,
      studentName: params.studentName,
      grade: params.grade,
      issuedAt: now,
      expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? '') ??
          now.add(const Duration(hours: 72)),
    );
  }
}

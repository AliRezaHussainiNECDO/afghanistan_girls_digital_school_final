import '../../../../core/mock/guardian_link_mock_store.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_remote_datasource.dart' show ProfileDataSource;

/// منبع دادهٔ پروفایل (فقط حالت Mock) — کد دعوت والد را در
/// `GuardianLinkMockStore` (زیرساخت مشترکِ Mock بین profile/parent_dashboard،
/// نه منبع واقعی) ثبت می‌کند تا در حالت نمایشی، والد بتواند با همین کد
/// متصل شود. در حالت Live این مسیر اصلاً اجرا نمی‌شود —
/// `ProfileRemoteDataSource` مستقیماً `POST /students/me/guardian-code` را
/// صدا می‌زند.
class ProfileMockDataSource implements ProfileDataSource {
  @override
  Future<GuardianInviteCode> generateGuardianInviteCode(GuardianInviteParams params) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return GuardianLinkMockStore.instance.issueCode(
      studentId: params.studentId,
      studentName: params.studentName,
      grade: params.grade,
    );
  }
}

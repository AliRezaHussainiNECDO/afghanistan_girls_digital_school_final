import '../../../../core/student/guardian_link_store.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_remote_datasource.dart' show ProfileDataSource;

/// منبع دادهٔ پروفایل — کد دعوت والد را در `GuardianLinkStore` (منبع واحد
/// حقیقت پیوند والد-فرزند) ثبت می‌کند تا والد واقعاً بتواند با همین کد
/// متصل شود؛ نه یک کد تصادفیِ ثبت‌نشده.
class ProfileMockDataSource implements ProfileDataSource {
  @override
  Future<GuardianInviteCode> generateGuardianInviteCode(GuardianInviteParams params) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return GuardianLinkStore.instance.issueCode(
      studentId: params.studentId,
      studentName: params.studentName,
      grade: params.grade,
    );
  }
}

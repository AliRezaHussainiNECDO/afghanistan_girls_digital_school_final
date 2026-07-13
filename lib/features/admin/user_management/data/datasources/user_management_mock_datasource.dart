import '../../../../../core/instructor/instructor_directory.dart';
import '../../../../../core/student/student_directory.dart';
import '../../domain/entities/admin_user_row.dart';
import 'user_management_remote_datasource.dart' show UserManagementDataSource;

/// لیست کاربران پنل مدیر — بازنویسی‌شده تا از **منابع واحد حقیقت** ساخته
/// شود (StudentDirectory + InstructorDirectory)، نه لیست ثابت ساختگی
/// نسخهٔ قبل. هر شاگرد/استادی که راجستر شود، اینجا هم ظاهر می‌شود.
class UserManagementMockDataSource implements UserManagementDataSource {
  /// والد نمایشی (بخش ۳.۵ سند) — تنها نقشی که هنوز Directory مستقل ندارد.
  bool _demoParentSuspended = false;

  List<AdminUserRow> _build() {
    final students = StudentDirectory.instance.all.map((s) => AdminUserRow(
          id: s.id,
          name: s.fullName,
          email: s.email,
          role: 'student',
          suspended: s.status != StudentAccountStatus.active,
        ));
    final instructors = InstructorDirectory.instance.all.map((i) => AdminUserRow(
          id: i.id,
          name: i.fullName,
          email: i.email,
          role: 'seminar_instructor',
          suspended: i.suspended,
        ));
    return [
      ...students,
      ...instructors,
      AdminUserRow(
        id: 'u-parent-demo',
        name: 'خانم کریمی',
        email: 'parent@demo.com',
        role: 'parent',
        suspended: _demoParentSuspended,
      ),
    ];
  }

  @override
  Future<List<AdminUserRow>> getUsers(String query) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final users = _build();
    if (query.trim().isEmpty) return users;
    return users
        .where((u) => u.name.contains(query) || u.email.contains(query))
        .toList();
  }

  @override
  Future<void> toggleSuspend(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final student = StudentDirectory.instance.byId(userId);
    if (student != null) {
      StudentDirectory.instance.setStatus(
        userId,
        student.status == StudentAccountStatus.active
            ? StudentAccountStatus.suspended
            : StudentAccountStatus.active,
      );
      return;
    }
    final instructor = InstructorDirectory.instance.byId(userId);
    if (instructor != null) {
      InstructorDirectory.instance.setSuspended(userId, !instructor.suspended);
      return;
    }
    if (userId == 'u-parent-demo') {
      _demoParentSuspended = !_demoParentSuspended;
    }
  }
}

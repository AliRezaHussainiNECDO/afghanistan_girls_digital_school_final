import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/page_transitions.dart';
import '../../features/advisor/presentation/screens/advisor_screen.dart';
import '../../features/academy/presentation/screens/admin_submissions_screen.dart';
import '../../features/academy/presentation/screens/parent_scores_screen.dart';
import '../../features/admin/ai_teacher_management/presentation/screens/ai_teacher_management_screen.dart';
import '../../features/admin/chat_monitoring/presentation/screens/admin_chat_monitoring_screen.dart';
import '../../features/admin/chat_monitoring/presentation/screens/admin_chat_thread_screen.dart';
import '../../features/admin/chat_monitoring/presentation/screens/admin_class_chats_screen.dart';
import '../../features/admin/cms/presentation/screens/cms_screen.dart';
import '../../features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/exams_management/presentation/screens/admin_exams_screen.dart';
import '../../features/admin/reports/presentation/screens/reports_screen.dart';
import '../../features/admin/audit_logs/presentation/screens/admin_audit_logs_screen.dart';
import '../../features/admin/safety_queue/presentation/screens/safety_queue_screen.dart';
import '../../features/admin/seminars/presentation/screens/admin_seminars_screen.dart';
import '../../features/admin/user_management/presentation/screens/instructor_detail_screen.dart';
import '../../features/admin/user_management/presentation/screens/instructor_list_screen.dart';
import '../../features/admin/user_management/presentation/screens/student_detail_screen.dart';
import '../../features/admin/parent_management/presentation/screens/parent_detail_screen.dart';
import '../../features/admin/parent_management/presentation/screens/parent_list_screen.dart';
import '../../features/certificates/presentation/screens/my_certificates_screen.dart';
import '../../features/curriculum_library/presentation/screens/bulk_import_screen.dart';
import '../../features/study_plan/presentation/screens/weekly_plan_screen.dart';
import '../../features/admin/user_management/presentation/screens/student_list_screen.dart';
import '../../features/admin/user_management/presentation/screens/user_management_screen.dart';
import '../../features/ai_teacher/presentation/screens/ai_teacher_screen.dart';
import '../../features/academy/homework/presentation/screens/homework_dashboard_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_instructor_screen.dart';
import '../../features/auth/presentation/screens/register_parent_screen.dart';
import '../../features/auth/presentation/screens/register_role_select_screen.dart';
import '../../features/auth/presentation/screens/register_student_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/chat_thread_screen.dart';
import '../../features/chat/presentation/screens/contact_admin_screen.dart';
import '../../features/collective_memory/presentation/screens/collective_memory_screen.dart';
import '../../features/curriculum/presentation/screens/chapters_screen.dart';
import '../../features/curriculum/presentation/screens/curriculum_screen.dart';
import '../../features/curriculum/presentation/screens/lesson_detail_screen.dart';
import '../../features/curriculum/presentation/screens/lessons_screen.dart';
import '../../features/exams/presentation/screens/exam_taking_screen.dart';
import '../../features/exams/presentation/screens/exam_result_review_screen.dart';
import '../../features/exams/presentation/screens/exams_screen.dart';
import '../../features/grade_map/presentation/screens/grade_map_screen.dart';
import '../../features/instructor/presentation/screens/instructor_home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/providers/language_select_providers.dart';
import '../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/language_select_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/parent_dashboard/presentation/screens/parent_dashboard_screen.dart';
import '../../features/parent_dashboard/presentation/screens/parent_homework_screen.dart';
import '../../features/parent_dashboard/presentation/screens/parent_seminars_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/seminars/presentation/screens/seminar_room_screen.dart';
import '../../features/seminars/presentation/screens/seminar_live_player_screen.dart';
import '../../features/seminars/presentation/screens/seminars_screen.dart';
import '../../features/student_dashboard/presentation/screens/student_dashboard_screen.dart';
import 'app_routes.dart';

/// روتر مرکزی اپ — طبق بخش ۲۴.۴ سند (`app/router/`).
/// شامل منطق Redirect بر اساس وضعیت نشست (Session) و نقش کاربر (RBAC)،
/// طوری‌که کاربر واردنشده هرگز به صفحات محافظت‌شده دسترسی ندارد و
/// هر نقش تنها به مسیرهای مجاز خودش هدایت می‌شود (بخش ۳ و ۵ سند).
///
/// همهٔ صفحات با انتقال محو+لغزش ملایم (`fadeSlidePage`) باز می‌شوند تا
/// حرکت بین صفحات نرم و دلپذیر باشد به‌جای تعویض ناگهانی.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final user = ref.read(authSessionProvider);
      final loggingIn = state.matchedLocation == AppRoutes.languageSelect ||
          state.matchedLocation == AppRoutes.welcome ||
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.registerRoleSelect ||
          state.matchedLocation == AppRoutes.registerStudent ||
          state.matchedLocation == AppRoutes.registerParent ||
          state.matchedLocation == AppRoutes.registerInstructor ||
          state.matchedLocation == AppRoutes.forgotPassword;

      if (user == null) {
        // طبق درخواست صریح کاربر: در اولین بار باز کردن برنامه پس از نصب،
        // پیش از هر صفحهٔ دیگری — حتی پیش از خوش‌آمدید — باید زبان برنامه
        // پرسیده شود. تا وقتی این پرچم false نشده (یعنی هنوز از حافظه
        // خوانده نشده یا صراحتاً false است)، کاربر اینجا نگه داشته می‌شود.
        final languageChosen = ref.read(languageChosenProvider);
        if (languageChosen == false && state.matchedLocation != AppRoutes.languageSelect) {
          return AppRoutes.languageSelect;
        }
        // برای کاربران کاملاً جدید (که هنوز صفحهٔ خوش‌آمدید را ندیده‌اند)،
        // پیش از صفحهٔ ورود، صفحهٔ معرفی برنامه نشان داده می‌شود.
        final onboardingSeen = ref.read(onboardingSeenProvider);
        if (state.matchedLocation == AppRoutes.login && onboardingSeen == false) {
          return AppRoutes.welcome;
        }
        return loggingIn ? null : AppRoutes.login;
      }

      if (loggingIn) {
        return _homeForRole(user.role);
      }

      // RBAC: جلوگیری از دسترسی نقش‌ها به بخش‌های دیگر (بخش ۵ سند).
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isParentRoute = state.matchedLocation.startsWith('/parent');
      final isInstructorRoute = state.matchedLocation.startsWith('/instructor');
      final isStudentRoute = state.matchedLocation.startsWith('/student');

      if (isAdminRoute && user.role != AppUserRole.superAdmin) {
        return _homeForRole(user.role);
      }
      if (isParentRoute && user.role != AppUserRole.parent) {
        return _homeForRole(user.role);
      }
      if (isInstructorRoute && user.role != AppUserRole.seminarInstructor) {
        return _homeForRole(user.role);
      }
      if (isStudentRoute && user.role != AppUserRole.student) {
        return _homeForRole(user.role);
      }
      return null;
    },
    routes: [
      GoRoute(
          path: AppRoutes.languageSelect,
          pageBuilder: (c, s) => fadePage(s, const LanguageSelectScreen())),
      GoRoute(path: AppRoutes.welcome, pageBuilder: (c, s) => fadePage(s, const WelcomeScreen())),
      GoRoute(path: AppRoutes.login, pageBuilder: (c, s) => fadePage(s, const LoginScreen())),
      GoRoute(
        path: AppRoutes.registerRoleSelect,
        pageBuilder: (c, s) => fadeSlidePage(s, const RegisterRoleSelectScreen()),
      ),
      GoRoute(
        path: AppRoutes.registerStudent,
        pageBuilder: (c, s) => fadeSlidePage(s, const RegisterStudentScreen()),
      ),
      GoRoute(
        path: AppRoutes.registerParent,
        pageBuilder: (c, s) => fadeSlidePage(s, const RegisterParentScreen()),
      ),
      GoRoute(
        path: AppRoutes.registerInstructor,
        pageBuilder: (c, s) => fadeSlidePage(s, const RegisterInstructorScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (c, s) => fadeSlidePage(s, const ForgotPasswordScreen()),
      ),

      // Student shell
      GoRoute(
          path: AppRoutes.studentHome,
          pageBuilder: (c, s) => fadeSlidePage(s, const StudentDashboardScreen())),
      GoRoute(path: AppRoutes.gradeMap, pageBuilder: (c, s) => fadeSlidePage(s, const GradeMapScreen())),
      GoRoute(
          path: AppRoutes.curriculum, pageBuilder: (c, s) => fadeSlidePage(s, const CurriculumScreen())),
      GoRoute(
        path: '/student/curriculum/:subjectId',
        pageBuilder: (c, s) =>
            fadeSlidePage(s, ChaptersScreen(subjectId: s.pathParameters['subjectId']!)),
      ),
      GoRoute(
        path: '/student/curriculum/:subjectId/:chapterId',
        pageBuilder: (c, s) => fadeSlidePage(
          s,
          LessonsScreen(
            subjectId: s.pathParameters['subjectId']!,
            chapterId: s.pathParameters['chapterId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/student/curriculum/:subjectId/:chapterId/:lessonId',
        pageBuilder: (c, s) => fadeSlidePage(
          s,
          LessonDetailScreen(
            subjectId: s.pathParameters['subjectId']!,
            lessonId: s.pathParameters['lessonId']!,
          ),
        ),
      ),
      GoRoute(
          path: AppRoutes.aiTeacher, pageBuilder: (c, s) => fadeSlidePage(s, const AiTeacherScreen())),
      GoRoute(
          path: AppRoutes.homework,
          pageBuilder: (c, s) => fadeSlidePage(s, const HomeworkDashboardScreen())),
      GoRoute(
          path: AppRoutes.advisor, pageBuilder: (c, s) => fadeSlidePage(s, const AdvisorScreen())),
      GoRoute(
          path: AppRoutes.studyPlan,
          pageBuilder: (c, s) => fadeSlidePage(s, const WeeklyPlanScreen())),
      GoRoute(
          path: AppRoutes.certificates,
          pageBuilder: (c, s) => fadeSlidePage(s, const MyCertificatesScreen())),
      GoRoute(path: AppRoutes.exams, pageBuilder: (c, s) => fadeSlidePage(s, const ExamsScreen())),
      GoRoute(
        path: '/student/exams/:examId',
        pageBuilder: (c, s) =>
            fadeSlidePage(s, ExamTakingScreen(examId: s.pathParameters['examId']!)),
      ),
      GoRoute(
          path: AppRoutes.attendance, pageBuilder: (c, s) => fadeSlidePage(s, const AttendanceScreen())),
      GoRoute(path: AppRoutes.library, pageBuilder: (c, s) => fadeSlidePage(s, const LibraryScreen())),
      GoRoute(path: AppRoutes.seminars, pageBuilder: (c, s) => fadeSlidePage(s, const SeminarsScreen())),
      GoRoute(path: AppRoutes.chat, pageBuilder: (c, s) => fadeSlidePage(s, const ChatScreen())),
      GoRoute(
        path: '/student/chat/:conversationId',
        pageBuilder: (c, s) =>
            fadeSlidePage(s, ChatThreadScreen(conversationId: s.pathParameters['conversationId']!)),
      ),
      GoRoute(
          path: AppRoutes.notifications,
          pageBuilder: (c, s) => fadeSlidePage(s, const NotificationsScreen())),
      GoRoute(path: AppRoutes.profile, pageBuilder: (c, s) => fadeSlidePage(s, const ProfileScreen())),

      // Parent
      GoRoute(
          path: AppRoutes.parentDashboard,
          pageBuilder: (c, s) => fadeSlidePage(s, const ParentDashboardScreen())),
      GoRoute(
          path: AppRoutes.parentScores,
          pageBuilder: (c, s) => fadeSlidePage(s, const ParentScoresScreen())),
      GoRoute(
          path: AppRoutes.parentHomework,
          pageBuilder: (c, s) => fadeSlidePage(s, const ParentHomeworkScreen())),
      GoRoute(
          path: AppRoutes.parentProfile, pageBuilder: (c, s) => fadeSlidePage(s, const ProfileScreen())),
      GoRoute(
          path: AppRoutes.parentSeminars,
          pageBuilder: (c, s) => fadeSlidePage(s, const ParentSeminarsScreen())),
      GoRoute(
          path: AppRoutes.parentContactAdmin,
          pageBuilder: (c, s) => fadeSlidePage(s, const ContactAdminScreen())),
      GoRoute(
          path: AppRoutes.parentNotifications,
          pageBuilder: (c, s) => fadeSlidePage(s, const NotificationsScreen())),

      // اتاق ویدیو کنفرانس سمینار (همهٔ نقش‌ها؛ کنترل دسترسی داخل صفحه)
      GoRoute(
        path: '/seminar-room/:seminarId',
        pageBuilder: (c, s) =>
            fadePage(s, SeminarRoomScreen(seminarId: s.pathParameters['seminarId']!)),
      ),

      // پخش زندهٔ سمینار با Cloudflare Stream (تماشای شاگرد/والد)
      GoRoute(
        path: '/seminar-live/:seminarId',
        pageBuilder: (c, s) =>
            fadePage(s, SeminarLivePlayerScreen(seminarId: s.pathParameters['seminarId']!)),
      ),

      // مرور پاسخ‌های یک تلاش امتحان (همهٔ نقش‌ها؛ کنترل دسترسی واقعی سمت
      // سرور — GET /exams/attempts/:attemptId — نه اینجا).
      GoRoute(
        path: '/exam-result/:attemptId',
        pageBuilder: (c, s) =>
            fadeSlidePage(s, ExamResultReviewScreen(attemptId: s.pathParameters['attemptId']!)),
      ),

      // Instructor
      GoRoute(
          path: AppRoutes.instructorHome,
          pageBuilder: (c, s) => fadeSlidePage(s, const InstructorHomeScreen())),
      GoRoute(
          path: AppRoutes.instructorProfile,
          pageBuilder: (c, s) => fadeSlidePage(s, const ProfileScreen())),
      GoRoute(
          path: AppRoutes.instructorContactAdmin,
          pageBuilder: (c, s) => fadeSlidePage(s, const ContactAdminScreen())),
      GoRoute(
          path: AppRoutes.instructorNotifications,
          pageBuilder: (c, s) => fadeSlidePage(s, const NotificationsScreen())),

      // Collective Memory (shared across all roles)
      GoRoute(
          path: AppRoutes.collectiveMemory,
          pageBuilder: (c, s) => fadeSlidePage(s, const CollectiveMemoryScreen())),

      // Admin
      GoRoute(
          path: AppRoutes.adminDashboard,
          pageBuilder: (c, s) => fadeSlidePage(s, const AdminDashboardScreen())),
      GoRoute(
          path: AppRoutes.adminUsers,
          pageBuilder: (c, s) => fadeSlidePage(s, const UserManagementScreen())),
      GoRoute(
          path: AppRoutes.adminStudents,
          pageBuilder: (c, s) => fadeSlidePage(s, const StudentListScreen())),
      GoRoute(
        path: '/admin/students/:studentId',
        pageBuilder: (c, s) => fadeSlidePage(
            s, StudentDetailScreen(studentId: s.pathParameters['studentId']!)),
      ),
      GoRoute(
          path: AppRoutes.adminInstructors,
          pageBuilder: (c, s) => fadeSlidePage(s, const InstructorListScreen())),
      GoRoute(
        path: '/admin/instructors/:instructorId',
        pageBuilder: (c, s) => fadeSlidePage(s,
            InstructorDetailScreen(instructorId: s.pathParameters['instructorId']!)),
      ),
      GoRoute(
          path: AppRoutes.adminParents,
          pageBuilder: (c, s) => fadeSlidePage(s, const ParentListScreen())),
      GoRoute(
        path: '/admin/parents/:parentId',
        pageBuilder: (c, s) =>
            fadeSlidePage(s, ParentDetailScreen(parentId: s.pathParameters['parentId']!)),
      ),
      GoRoute(path: AppRoutes.adminCms, pageBuilder: (c, s) => fadeSlidePage(s, const CmsScreen())),
      GoRoute(
          path: AppRoutes.adminExamsManagement,
          pageBuilder: (c, s) => fadeSlidePage(s, const AdminExamsScreen())),
      GoRoute(
          path: AppRoutes.adminAiTeacher,
          pageBuilder: (c, s) => fadeSlidePage(s, const AiTeacherManagementScreen())),
      GoRoute(
          path: AppRoutes.adminBulkImport,
          pageBuilder: (c, s) => fadeSlidePage(s, const BulkImportScreen())),
      GoRoute(
          path: AppRoutes.adminSafetyQueue,
          pageBuilder: (c, s) => fadeSlidePage(s, const SafetyQueueScreen())),
      GoRoute(
          path: AppRoutes.adminAuditLogs,
          pageBuilder: (c, s) => fadeSlidePage(s, const AdminAuditLogsScreen())),
      GoRoute(
          path: AppRoutes.adminChats,
          pageBuilder: (c, s) => fadeSlidePage(s, const AdminChatMonitoringScreen())),
      GoRoute(
        path: '/admin/chats/class/:classId',
        pageBuilder: (c, s) =>
            fadeSlidePage(s, AdminClassChatsScreen(classId: s.pathParameters['classId']!)),
      ),
      GoRoute(
        path: '/admin/chats/thread/:conversationId',
        pageBuilder: (c, s) => fadeSlidePage(
            s, AdminChatThreadScreen(conversationId: s.pathParameters['conversationId']!)),
      ),
      GoRoute(
          path: AppRoutes.adminReports,
          pageBuilder: (c, s) => fadeSlidePage(s, const ReportsScreen())),
      GoRoute(
          path: AppRoutes.adminSeminars,
          pageBuilder: (c, s) => fadeSlidePage(s, const AdminSeminarsScreen())),
      GoRoute(
          path: AppRoutes.adminSubmissions,
          pageBuilder: (c, s) => fadeSlidePage(s, const AdminSubmissionsScreen())),
      GoRoute(
          path: AppRoutes.adminNotifications,
          pageBuilder: (c, s) => fadeSlidePage(s, const NotificationsScreen())),
      GoRoute(
          path: AppRoutes.adminProfile, pageBuilder: (c, s) => fadeSlidePage(s, const ProfileScreen())),
    ],
  );
});

String _homeForRole(AppUserRole role) {
  switch (role) {
    case AppUserRole.superAdmin:
      return AppRoutes.adminDashboard;
    case AppUserRole.parent:
      return AppRoutes.parentDashboard;
    case AppUserRole.seminarInstructor:
      return AppRoutes.instructorHome;
    case AppUserRole.student:
      return AppRoutes.studentHome;
  }
}

/// پل بین Riverpod (authSessionProvider) و `Listenable` مورد نیاز go_router
/// برای این‌که با تغییر وضعیت ورود، منطق redirect دوباره اجرا شود.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authSessionProvider, (previous, next) {
      notifyListeners();
    });
    ref.listen(onboardingSeenProvider, (previous, next) {
      notifyListeners();
    });
    ref.listen(languageChosenProvider, (previous, next) {
      notifyListeners();
    });
  }
}

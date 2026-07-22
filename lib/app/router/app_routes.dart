/// نام/مسیر تمام صفحات اپ در یک‌جا — طبق بخش ۲۴.۴ سند
/// (`app/router/`: تعریف تمام مسیرها از جمله /admin/*، /parent/*).
class AppRoutes {
  AppRoutes._();

  // Onboarding
  static const languageSelect = '/language-select';
  static const welcome = '/welcome';

  // Auth
  static const login = '/login';
  static const registerRoleSelect = '/register';
  static const registerStudent = '/register/student';
  static const registerParent = '/register/parent';
  static const registerInstructor = '/register/instructor';
  static const forgotPassword = '/forgot-password';

  // Student shell
  static const studentHome = '/student';
  static const gradeMap = '/student/grade-map';
  static const curriculum = '/student/curriculum';
  static String curriculumChapters(String subjectId) => '/student/curriculum/$subjectId';
  static String curriculumLessons(String subjectId, String chapterId) =>
      '/student/curriculum/$subjectId/$chapterId';
  static String curriculumLessonDetail(String subjectId, String chapterId, String lessonId) =>
      '/student/curriculum/$subjectId/$chapterId/$lessonId';
  static const aiTeacher = '/student/ai-teacher';
  static const homework = '/student/homework';
  static const advisor = '/student/advisor';
  static const studyPlan = '/student/study-plan';
  static const certificates = '/student/certificates';
  static const exams = '/student/exams';
  static String examTaking(String examId) => '/student/exams/$examId';
  static const attendance = '/student/attendance';
  static const library = '/student/library';
  static const seminars = '/student/seminars';
  static const chat = '/student/chat';
  static String chatThread(String conversationId) => '/student/chat/$conversationId';
  static const notifications = '/student/notifications';
  static const profile = '/student/profile';

  // Parent
  static const parentDashboard = '/parent';
  static const parentSeminars = '/parent/seminars';
  static const parentScores = '/parent/scores';
  static const parentHomework = '/parent/homework';
  static const parentContactAdmin = '/parent/contact-admin';
  static const parentNotifications = '/parent/notifications';
  static const parentProfile = '/parent/profile';

  // اتاق ویدیو کنفرانس سمینار — مشترک بین همهٔ نقش‌ها (خارج از پیشوند نقش‌ها).
  static String seminarRoom(String seminarId) => '/seminar-room/$seminarId';

  // پخش زندهٔ سمینار (Cloudflare Stream) — تماشای شاگرد.
  static String seminarLive(String seminarId) => '/seminar-live/$seminarId';

  // مرور پاسخ‌های یک تلاش امتحان — مشترک بین همهٔ نقش‌ها (خارج از پیشوند
  // نقش‌ها)، چون هم شاگرد خودش، هم والدِ لینک‌شده (از /parent/scores)، و هم
  // مدیر (از پروندهٔ شاگرد در /admin/students/:id) باید بتوانند این صفحه را
  // باز کنند. رفع اشکال واقعی: قبلاً این مسیر زیر «/student/...» بود، پس
  // نگهبان RBAC (پایین همین فایل) هر کاربر غیر-شاگرد را همان لحظه به
  // داشبورد خودش برمی‌گرداند — یعنی والد/مدیر هرگز نمی‌توانست این صفحه را
  // واقعاً باز کند، حتی با اینکه سرور دسترسی را مجاز می‌دانست.
  static String examResultReview(String attemptId) => '/exam-result/$attemptId';

  // Instructor
  static const instructorHome = '/instructor';
  static const instructorContactAdmin = '/instructor/contact-admin';
  static const instructorNotifications = '/instructor/notifications';
  static const instructorProfile = '/instructor/profile';

  // Collective Memory (accessible to all roles)
  static const collectiveMemory = '/community';

  // Admin
  static const adminDashboard = '/admin';
  static const adminUsers = '/admin/users';
  static const adminStudents = '/admin/students';
  static String adminStudentDetail(String studentId) => '/admin/students/$studentId';
  static const adminInstructors = '/admin/instructors';
  static String adminInstructorDetail(String instructorId) => '/admin/instructors/$instructorId';
  static const adminParents = '/admin/parents';
  static String adminParentDetail(String parentId) => '/admin/parents/$parentId';
  static const adminCms = '/admin/cms';
  static const adminExamsManagement = '/admin/exams-management';
  static const adminAiTeacher = '/admin/ai-teacher';
  static const adminBulkImport = '/admin/ai-teacher/bulk-import';
  static const adminSafetyQueue = '/admin/safety-queue';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminChats = '/admin/chats';
  static String adminClassChats(String classId) => '/admin/chats/class/$classId';
  static String adminChatThread(String conversationId) => '/admin/chats/thread/$conversationId';
  static const adminReports = '/admin/reports';
  static const adminSeminars = '/admin/seminars';
  static const adminSubmissions = '/admin/submissions';
  static const adminNotifications = '/admin/notifications';
  static const adminProfile = '/admin/profile';
}

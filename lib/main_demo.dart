/// اجرای مستقیم دیموی «مدیریت شاگردان» با دیتای نمونه (Mock) — بدون Backend:
///
///   flutter run -t lib/main_demo.dart
///
/// این فایل فقط برای تست سریع ماژول است؛ اپ اصلی از lib/main.dart اجرا می‌شود
/// و صفحهٔ مدیریت شاگردان در آن از مسیر /admin/users → دکمهٔ «مدیریت شاگردان»
/// (یا مستقیم /admin/students) در دسترس است.

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/user_management/presentation/screens/student_detail_screen.dart';
import 'features/admin/user_management/presentation/screens/student_list_screen.dart';

void main() => runApp(const ProviderScope(child: StudentManagementDemoApp()));

final _demoRouter = GoRouter(
  initialLocation: '/admin/students',
  routes: [
    GoRoute(
      path: '/admin/students',
      builder: (c, s) => const StudentListScreen(),
    ),
    GoRoute(
      path: '/admin/students/:studentId',
      builder: (c, s) =>
          StudentDetailScreen(studentId: s.pathParameters['studentId']!),
    ),
  ],
);

class StudentManagementDemoApp extends StatelessWidget {
  const StudentManagementDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'دیمو — مدیریت شاگردان',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF16A085),
        ),
        routerConfig: _demoRouter,
      );
}

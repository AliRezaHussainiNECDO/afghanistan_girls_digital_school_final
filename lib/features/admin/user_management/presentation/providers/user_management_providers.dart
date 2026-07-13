import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/instructor/instructor_directory.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/student/student_directory.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/user_management_mock_datasource.dart';
import '../../data/datasources/user_management_remote_datasource.dart';
import '../../data/repositories_impl/user_management_repository_impl.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../../domain/usecases/user_management_usecases.dart';

/// منابع واحد حقیقت حساب‌ها — تا راجستر/مسدودسازی خودکار لیست را تازه کند
/// (فقط در حالت Mock معنا دارد؛ در حالت Live داده از سرور می‌آید).
final _studentDirProvider =
    ChangeNotifierProvider<StudentDirectory>((ref) => StudentDirectory.instance);
final _instructorDirProvider = ChangeNotifierProvider<InstructorDirectory>(
    (ref) => InstructorDirectory.instance);

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final userManagementDataSourceProvider = Provider<UserManagementDataSource>((ref) {
  if (kUseLiveBackend) {
    return UserManagementRemoteDataSource(ref.watch(apiClientProvider));
  }
  return UserManagementMockDataSource();
});
final userManagementRepositoryProvider = Provider<UserManagementRepository>(
  (ref) => UserManagementRepositoryImpl(ref.watch(userManagementDataSourceProvider)),
);
final getUsersUseCaseProvider =
    Provider((ref) => GetUsersUseCase(ref.watch(userManagementRepositoryProvider)));
final toggleSuspendUseCaseProvider =
    Provider((ref) => ToggleSuspendUseCase(ref.watch(userManagementRepositoryProvider)));

final adminUserSearchQueryProvider = StateProvider<String>((ref) => '');

final adminUsersProvider = FutureProvider<List<AdminUserRow>>((ref) async {
  // با هر تغییر واقعی (راجستر شاگرد/استاد جدید، مسدود/فعال‌سازی) بازسازی شود.
  ref.watch(_studentDirProvider);
  ref.watch(_instructorDirProvider);
  final query = ref.watch(adminUserSearchQueryProvider);
  final result = await ref.read(getUsersUseCaseProvider).call(query);
  return result.fold((f) => throw f, (v) => v);
});

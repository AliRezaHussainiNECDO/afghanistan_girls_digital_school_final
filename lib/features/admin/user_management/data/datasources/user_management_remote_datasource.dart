import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_user_row.dart';

/// قرارداد مشترک DataSource مدیریت کاربران — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class UserManagementDataSource {
  Future<List<AdminUserRow>> getUsers(String query);
  Future<void> toggleSuspend(String userId);
}

/// پیاده‌سازی واقعی — روتر admin زیر `/api/v1/admin` (بخش ۱۵.۲ سند).
/// لیست کامل کاربران واقعی از D1 (دانش‌آموز/والد/استاد) با جستجو و
/// مسدود/فعال‌سازی سرور-محور.
class UserManagementRemoteDataSource implements UserManagementDataSource {
  final ApiClient _api;
  UserManagementRemoteDataSource(this._api);

  @override
  Future<List<AdminUserRow>> getUsers(String query) async {
    final data = await _api.get('/admin/users',
        queryParameters: {if (query.trim().isNotEmpty) 'q': query.trim()});
    final list = (data['users'] as List? ?? []);
    return list
        .map((u) => AdminUserRow(
              id: u['id'] as String,
              name: u['name'] as String? ?? '',
              email: u['email'] as String? ?? '',
              role: u['role'] as String? ?? 'student',
              suspended: u['suspended'] == true,
              avatarUrl: _absoluteUrl(u['avatarUrl'] as String?),
              emailVerified: u['emailVerified'] != false,
            ))
        .toList();
  }

  @override
  Future<void> toggleSuspend(String userId) async {
    await _api.patch('/admin/users/$userId/toggle-suspend');
  }

  /// آدرس نسبی سرور (مثل `/files/avatars/x.jpg`) → آدرس کامل.
  String? _absoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$kApiBaseUrl$url';
  }
}

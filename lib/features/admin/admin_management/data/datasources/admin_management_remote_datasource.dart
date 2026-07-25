import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_manager.dart';

/// روتر `/api/v1/admin/admins` — بخش «مدیریت مدیران» (فقط Super Admin،
/// backend/src/routes/admin.ts، بخش «مدیریت مدیران»).
class AdminManagementRemoteDataSource {
  final ApiClient _api;
  AdminManagementRemoteDataSource(this._api);

  AdminManager _fromJson(Map<String, dynamic> j) => AdminManager(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        suspended: j['suspended'] == true,
        createdAt: j['createdAt'] as String? ?? '',
        permissions: (j['permissions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  Future<List<AdminManager>> getAdmins() async {
    final data = await _api.get('/admin/admins');
    final list = (data['admins'] as List? ?? []);
    return list.map((e) => _fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<AdminManager> createAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required List<String> permissions,
  }) async {
    final data = await _api.post('/admin/admins', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'permissions': permissions,
    });
    return _fromJson(Map<String, dynamic>.from(data['admin'] as Map));
  }

  Future<List<String>> updatePermissions(String adminId, List<String> permissions) async {
    final data = await _api.patch('/admin/admins/$adminId/permissions', data: {'permissions': permissions});
    return (data['permissions'] as List? ?? []).map((e) => e.toString()).toList();
  }

  Future<void> toggleSuspend(String adminId) async {
    await _api.patch('/admin/admins/$adminId/toggle-suspend');
  }
}

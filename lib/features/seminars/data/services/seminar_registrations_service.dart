import '../../../../core/network/api_client.dart';

/// یک ثبت‌نامی در سمینار — همراه با نام کاربر (برای نمایش در پنل مدیر/استاد).
class SeminarRegistrant {
  final String userId;
  final String name;
  final String role;
  final String status;
  final String registeredAt;

  const SeminarRegistrant({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    required this.registeredAt,
  });

  factory SeminarRegistrant.fromJson(Map<String, dynamic> j) => SeminarRegistrant(
        userId: j['userId']?.toString() ?? '',
        name: (j['name']?.toString().trim().isNotEmpty ?? false) ? j['name'].toString() : '—',
        role: j['role']?.toString() ?? '',
        status: j['status']?.toString() ?? 'registered',
        registeredAt: j['registeredAt']?.toString() ?? '',
      );
}

/// سرویس دریافت فهرست ثبت‌نامی‌های یک سمینار (فقط استاد/مدیر).
/// مسیر سرور: GET /seminars/:id/registrations
class SeminarRegistrationsService {
  final ApiClient _api;
  const SeminarRegistrationsService(this._api);

  Future<List<SeminarRegistrant>> getRegistrations(String seminarId) async {
    final data = await _api.get('/seminars/$seminarId/registrations');
    final list = (data['registrations'] as List? ?? []);
    return list
        .map((e) => SeminarRegistrant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

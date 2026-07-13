/// DataSource واقعی مدیریت تفصیلی شاگرد — از `ApiClient` مشترک (با
/// Interceptor های JWT) استفاده می‌کند تا با بقیهٔ اپ هماهنگ باشد.
/// Endpointها زیر `/api/v1/admin` (بخش ۱۵.۲ سند SPEC).

library;
import '../../../../../../core/network/api_client.dart';
import '../../../domain/entities/student_entities.dart';
import '../../models/student_models.dart';

abstract class StudentManagementRemoteDataSource {
  Future<PagedStudentsModel> fetchStudents(StudentListFilter filter);
  Future<StudentDetailModel> fetchStudentDetail(String studentId);
  Future<AiTeacherReportModel> fetchAiReport(String studentId);
  Future<void> patchStatus(String studentId, AccountStatus status, String reason);
  Future<void> softDelete(String studentId, String reason);
  Future<void> sendPasswordResetLink(String studentId);
}

class StudentManagementRemoteDataSourceImpl
    implements StudentManagementRemoteDataSource {
  final ApiClient _api;
  const StudentManagementRemoteDataSourceImpl(this._api);

  @override
  Future<PagedStudentsModel> fetchStudents(StudentListFilter filter) async {
    final data = await _api.get('/admin/students', queryParameters: {
      if (filter.query?.isNotEmpty == true) 'q': filter.query,
      if (filter.grade != null) 'grade': filter.grade,
      if (filter.province != null) 'province': filter.province,
      if (filter.status != null) 'status': accountStatusToApi(filter.status!),
      if (filter.atRiskOnly) 'at_risk': true,
      'page': filter.page,
    });
    return PagedStudentsModel.fromJson(_asMap(data));
  }

  @override
  Future<StudentDetailModel> fetchStudentDetail(String studentId) async {
    final data = await _api.get('/admin/students/$studentId');
    return StudentDetailModel.fromJson(_asMap(data));
  }

  @override
  Future<AiTeacherReportModel> fetchAiReport(String studentId) async {
    final data = await _api.get('/admin/students/$studentId/ai-report');
    return AiTeacherReportModel.fromJson(_asMap(data));
  }

  @override
  Future<void> patchStatus(
      String studentId, AccountStatus status, String reason) async {
    // PATCH /admin/students/{id}/status — reason برای Audit ثبت می‌شود.
    await _api.patch('/admin/students/$studentId/status', data: {
      'status': accountStatusToApi(status),
      'reason': reason,
    });
  }

  @override
  Future<void> softDelete(String studentId, String reason) =>
      patchStatus(studentId, AccountStatus.deleted, reason);

  @override
  Future<void> sendPasswordResetLink(String studentId) async {
    await _api.post('/admin/students/$studentId/password-reset-link');
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
}

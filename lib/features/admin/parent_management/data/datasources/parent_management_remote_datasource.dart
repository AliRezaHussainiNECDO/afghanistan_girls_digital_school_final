/// DataSource واقعی «مدیریت والدین» — از همان `ApiClient` مشترک استفاده
/// می‌کند. Endpointها زیر `/api/v1/admin` (هم‌الگو با مدیریت شاگردان).
library;

import '../../../../../core/network/api_client.dart';
import '../../../user_management/domain/entities/student_entities.dart' show AccountStatus;
import '../../domain/entities/parent_entities.dart';
import '../models/parent_models.dart';

String _statusToApi(AccountStatus s) => switch (s) {
      AccountStatus.active => 'active',
      AccountStatus.suspended => 'suspended',
      AccountStatus.pendingVerification => 'pending_verification',
      AccountStatus.deleted => 'deleted',
    };

abstract class ParentManagementDataSource {
  Future<PagedParentsModel> fetchParents(ParentListFilter filter);
  Future<ParentDetailModel> fetchParentDetail(String parentId);
  Future<void> patchStatus(String parentId, AccountStatus status);
}

class ParentManagementRemoteDataSource implements ParentManagementDataSource {
  final ApiClient _api;
  const ParentManagementRemoteDataSource(this._api);

  @override
  Future<PagedParentsModel> fetchParents(ParentListFilter filter) async {
    final data = await _api.get('/admin/parents', queryParameters: {
      if (filter.query?.isNotEmpty == true) 'q': filter.query,
      if (filter.status != null) 'status': _statusToApi(filter.status!),
      'page': filter.page,
    });
    return PagedParentsModel.fromJson(_asMap(data));
  }

  @override
  Future<ParentDetailModel> fetchParentDetail(String parentId) async {
    final data = await _api.get('/admin/parents/$parentId');
    return ParentDetailModel.fromJson(_asMap(data));
  }

  @override
  Future<void> patchStatus(String parentId, AccountStatus status) async {
    // از همان Endpoint عمومی مدیریت کاربران استفاده می‌شود (کار برای هر
    // نقشی از جمله والد می‌کند) — نیازی به یک Endpoint اختصاصی نیست.
    await _api.patch('/admin/users/$parentId', data: {'status': _statusToApi(status)});
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
}

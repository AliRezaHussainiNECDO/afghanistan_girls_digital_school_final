import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../audit_logs/domain/entities/audit_log_entry.dart';
import '../../../audit_logs/presentation/providers/audit_logs_providers.dart' show auditLogsDataSourceProvider;
import '../../data/datasources/admin_management_remote_datasource.dart';
import '../../data/repositories_impl/admin_management_repository_impl.dart';
import '../../domain/entities/admin_manager.dart';
import '../../domain/repositories/admin_management_repository.dart';

final adminManagementDataSourceProvider = Provider<AdminManagementRemoteDataSource>(
  (ref) => AdminManagementRemoteDataSource(ref.watch(apiClientProvider)),
);

final adminManagementRepositoryProvider = Provider<AdminManagementRepository>(
  (ref) => AdminManagementRepositoryImpl(ref.watch(adminManagementDataSourceProvider)),
);

final adminManagersProvider = FutureProvider.autoDispose<List<AdminManager>>((ref) async {
  final result = await ref.watch(adminManagementRepositoryProvider).getAdmins();
  return result.fold((f) => throw f, (v) => v);
});

/// «پروندهٔ فعالیت مدیر» — تاریخچهٔ اقدامات یک مدیر مشخص، از همان
/// GET /admin/audit-logs?actorId=... (سرور از قبل این فیلتر را پشتیبانی
/// می‌کند — نیازی به Endpoint تازه نبود).
final adminActivityProvider =
    FutureProvider.autoDispose.family<List<AuditLogEntry>, String>((ref, adminId) async {
  final ds = ref.watch(auditLogsDataSourceProvider);
  return ds.fetch(actorId: adminId, limit: 200);
});

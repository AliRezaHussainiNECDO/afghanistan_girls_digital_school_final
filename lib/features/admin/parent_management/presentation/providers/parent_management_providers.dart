/// لایهٔ Presentation «مدیریت والدین» — Riverpod 2+، هم‌الگو با
/// `student_management_providers.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/network_providers.dart';
import '../../../user_management/domain/entities/student_entities.dart' show AccountStatus;
import '../../data/datasources/parent_management_remote_datasource.dart';
import '../../domain/entities/parent_entities.dart';

final parentMgmtDataSourceProvider = Provider<ParentManagementDataSource>(
  (ref) => ParentManagementRemoteDataSource(ref.watch(apiClientProvider)),
);

final parentListFilterProvider = StateProvider<ParentListFilter>((ref) => const ParentListFilter());

final parentsProvider = FutureProvider<PagedParents>((ref) async {
  final filter = ref.watch(parentListFilterProvider);
  return ref.read(parentMgmtDataSourceProvider).fetchParents(filter);
});

final parentDetailProvider = FutureProvider.family<ParentDetail, String>((ref, id) async {
  return ref.read(parentMgmtDataSourceProvider).fetchParentDetail(id);
});

class ParentActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> setStatus(String id, AccountStatus status) async {
    state = const AsyncLoading();
    try {
      await ref.read(parentMgmtDataSourceProvider).patchStatus(id, status);
      state = const AsyncData(null);
      ref.invalidate(parentsProvider);
      ref.invalidate(parentDetailProvider(id));
      return null;
    } catch (e) {
      state = const AsyncData(null);
      return e.toString();
    }
  }
}

final parentActionsProvider = AsyncNotifierProvider<ParentActionsController, void>(ParentActionsController.new);

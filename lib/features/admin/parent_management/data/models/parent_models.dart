/// DTOها — نگاشت JSON ↔ Entity، هم‌الگو با `student_models.dart`.
library;

import '../../../user_management/domain/entities/student_entities.dart' show AccountStatus;
import '../../domain/entities/parent_entities.dart';

AccountStatus _statusFrom(String s) => switch (s) {
      'active' => AccountStatus.active,
      'suspended' => AccountStatus.suspended,
      'pending_verification' => AccountStatus.pendingVerification,
      'deleted' => AccountStatus.deleted,
      _ => AccountStatus.active,
    };

class ParentSummaryModel extends ParentSummary {
  const ParentSummaryModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    super.avatarUrl,
    required super.status,
    required super.linkedChildrenCount,
    required super.pendingChildrenCount,
    required super.createdAt,
  });

  factory ParentSummaryModel.fromJson(Map<String, dynamic> json) => ParentSummaryModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        status: _statusFrom(json['status'] as String? ?? 'active'),
        linkedChildrenCount: json['linked_children_count'] as int? ?? 0,
        pendingChildrenCount: json['pending_children_count'] as int? ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class PagedParentsModel extends PagedParents {
  const PagedParentsModel({
    required super.items,
    required super.total,
    required super.page,
    required super.pageSize,
  });

  factory PagedParentsModel.fromJson(Map<String, dynamic> json) => PagedParentsModel(
        items: (json['items'] as List? ?? [])
            .map((e) => ParentSummaryModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: json['total'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['page_size'] as int? ?? 20,
      );
}

class LinkedChildModel extends LinkedChild {
  const LinkedChildModel({
    required super.linkId,
    required super.studentId,
    required super.studentName,
    required super.grade,
    required super.linkStatus,
    required super.linkedAt,
    super.approvedAt,
    required super.progressPercent,
    required super.pointsTotal,
    required super.pointsLevel,
    required super.pointsLevelTitleFa,
  });

  factory LinkedChildModel.fromJson(Map<String, dynamic> json) => LinkedChildModel(
        linkId: json['link_id'] as String,
        studentId: json['student_id'] as String,
        studentName: json['student_name'] as String? ?? '',
        grade: json['grade'] as int? ?? 7,
        linkStatus: json['link_status'] as String? ?? 'pending_student_approval',
        linkedAt: DateTime.tryParse(json['linked_at'] as String? ?? '') ?? DateTime.now(),
        approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'] as String) : null,
        progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0,
        pointsTotal: json['points_total'] as int? ?? 0,
        pointsLevel: json['points_level'] as int? ?? 1,
        pointsLevelTitleFa: json['points_level_title_fa'] as String? ?? 'نوآموز',
      );
}

class ParentDetailModel extends ParentDetail {
  const ParentDetailModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    super.avatarUrl,
    required super.status,
    required super.registeredAt,
    required super.children,
  });

  factory ParentDetailModel.fromJson(Map<String, dynamic> json) => ParentDetailModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        status: _statusFrom(json['status'] as String? ?? 'active'),
        registeredAt: DateTime.tryParse(json['registered_at'] as String? ?? '') ?? DateTime.now(),
        children: (json['children'] as List? ?? [])
            .map((e) => LinkedChildModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

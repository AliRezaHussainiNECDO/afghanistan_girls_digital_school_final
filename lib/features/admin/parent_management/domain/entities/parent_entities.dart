/// Entities خالص «مدیریت والدین» پنل مدیر — هم‌الگو با
/// `user_management/domain/entities/student_entities.dart`. تمام مقادیر
/// (پیشرفت فرزند، امتیاز فعالیت و غیره) در Backend محاسبه می‌شوند؛ کلاینت
/// فقط نمایش می‌دهد.
library;

import '../../../user_management/domain/entities/student_entities.dart' show AccountStatus;

/// ردیف لیست والدین (GET /api/v1/admin/parents).
class ParentSummary {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final AccountStatus status;
  final int linkedChildrenCount;
  final int pendingChildrenCount;
  final DateTime createdAt;

  const ParentSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.status,
    required this.linkedChildrenCount,
    required this.pendingChildrenCount,
    required this.createdAt,
  });
}

class PagedParents {
  final List<ParentSummary> items;
  final int total;
  final int page;
  final int pageSize;
  const PagedParents({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  bool get hasMore => page * pageSize < total;
}

class ParentListFilter {
  final String? query;
  final AccountStatus? status;
  final int page;
  const ParentListFilter({this.query, this.status, this.page = 1});

  ParentListFilter copyWith({
    String? query,
    AccountStatus? status,
    int? page,
    bool clearStatus = false,
  }) =>
      ParentListFilter(
        query: query ?? this.query,
        status: clearStatus ? null : (status ?? this.status),
        page: page ?? this.page,
      );
}

/// یک فرزندِ لینک‌شده به این والد + خلاصهٔ زندهٔ پیشرفت (منبع واحد
/// `lib/progress.ts` — دقیقاً همان عددی که خودِ شاگرد در داشبورد خودش می‌بیند).
class LinkedChild {
  final String linkId;
  final String studentId;
  final String studentName;
  final int grade;
  final String linkStatus; // pending_student_approval | approved | rejected
  final DateTime linkedAt;
  final DateTime? approvedAt;
  final double progressPercent;
  final int pointsTotal;
  final int pointsLevel;
  final String pointsLevelTitleFa;

  const LinkedChild({
    required this.linkId,
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.linkStatus,
    required this.linkedAt,
    this.approvedAt,
    required this.progressPercent,
    required this.pointsTotal,
    required this.pointsLevel,
    required this.pointsLevelTitleFa,
  });
}

/// معلومات مفصل والد (GET /api/v1/admin/parents/:id).
class ParentDetail {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final AccountStatus status;
  final DateTime registeredAt;
  final List<LinkedChild> children;

  const ParentDetail({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.status,
    required this.registeredAt,
    required this.children,
  });
}

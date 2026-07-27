import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════════════════
/// موجودیت «رکورد گزارش خطا» (بخش «گزارش خطاهای برنامه» — Migration 0046).
///
/// هر ردیف یک خطای اجرایی است، چه از بک‌اند (Cloudflare Worker) چه از اپ
/// فلاتر — با کد خطا، دسته‌بندی، شدت، پیام/Stack trace، و تاریخ/روز/ساعت
/// دقیق وقوع. پارس کاملاً دفاعی است تا یک رکورد بدشکل کل لیست را نیندازد
/// (همان اصل AuditLogEntry).
/// ═══════════════════════════════════════════════════════════════════════════

enum ErrorSeverity { low, medium, high, critical }

enum ErrorLogStatus { newIssue, investigating, resolved, ignored }

class ErrorLogEntry {
  final String id;
  final String errorCode;
  final String category; // AUTH|DATABASE|API|UI|VALIDATION|NETWORK|UNKNOWN
  final ErrorSeverity severity;
  final String title;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final String source; // flutter_app | cloudflare_worker
  final String? screenOrEndpoint;
  final String? httpMethod;
  final int? httpStatus;
  final String? platform;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
  final String? locale;
  final String? userId;
  final String? userRole;
  final String occurredAt; // 'YYYY-MM-DD HH:MM:SS.sss' (UTC، بدون Z)
  final String occurredDate;
  final String occurredDayOfWeek;
  final String occurredTime;
  final ErrorLogStatus status;
  final String? resolutionNotes;
  final String? resolvedAt;
  final String? resolvedBy;
  final int occurrenceCount;

  const ErrorLogEntry({
    required this.id,
    required this.errorCode,
    required this.category,
    required this.severity,
    required this.title,
    required this.message,
    this.stackTrace,
    this.context,
    required this.source,
    this.screenOrEndpoint,
    this.httpMethod,
    this.httpStatus,
    this.platform,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
    this.locale,
    this.userId,
    this.userRole,
    required this.occurredAt,
    required this.occurredDate,
    required this.occurredDayOfWeek,
    required this.occurredTime,
    required this.status,
    this.resolutionNotes,
    this.resolvedAt,
    this.resolvedBy,
    this.occurrenceCount = 1,
  });

  bool get isCritical => severity == ErrorSeverity.critical;

  static ErrorSeverity _severityFrom(dynamic v) {
    switch (v?.toString()) {
      case 'low':
        return ErrorSeverity.low;
      case 'high':
        return ErrorSeverity.high;
      case 'critical':
        return ErrorSeverity.critical;
      default:
        return ErrorSeverity.medium;
    }
  }

  static ErrorLogStatus _statusFrom(dynamic v) {
    switch (v?.toString()) {
      case 'investigating':
        return ErrorLogStatus.investigating;
      case 'resolved':
        return ErrorLogStatus.resolved;
      case 'ignored':
        return ErrorLogStatus.ignored;
      default:
        return ErrorLogStatus.newIssue;
    }
  }

  static String statusToApi(ErrorLogStatus s) {
    switch (s) {
      case ErrorLogStatus.investigating:
        return 'investigating';
      case ErrorLogStatus.resolved:
        return 'resolved';
      case ErrorLogStatus.ignored:
        return 'ignored';
      case ErrorLogStatus.newIssue:
        return 'new';
    }
  }

  /// پارس دفاعی: context ممکن است Map، رشتهٔ JSON، یا null باشد.
  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    if (v is String && v.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) return decoded.map((k, val) => MapEntry(k.toString(), val));
      } catch (_) {
        return {'raw': v};
      }
    }
    return null;
  }

  factory ErrorLogEntry.fromJson(Map<String, dynamic> j) => ErrorLogEntry(
        id: (j['id'] ?? '').toString(),
        errorCode: (j['error_code'] ?? '').toString(),
        category: (j['category'] ?? 'UNKNOWN').toString(),
        severity: _severityFrom(j['severity']),
        title: (j['title'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        stackTrace: j['stack_trace']?.toString(),
        context: _asMap(j['context'] ?? j['context_json']),
        source: (j['source'] ?? '').toString(),
        screenOrEndpoint: j['screen_or_endpoint']?.toString(),
        httpMethod: j['http_method']?.toString(),
        httpStatus: j['http_status'] is int ? j['http_status'] as int : int.tryParse('${j['http_status']}'),
        platform: j['platform']?.toString(),
        appVersion: j['app_version']?.toString(),
        osVersion: j['os_version']?.toString(),
        deviceModel: j['device_model']?.toString(),
        locale: j['locale']?.toString(),
        userId: j['user_id']?.toString(),
        userRole: j['user_role']?.toString(),
        occurredAt: (j['occurred_at'] ?? '').toString(),
        occurredDate: (j['occurred_date'] ?? '').toString(),
        occurredDayOfWeek: (j['occurred_day_of_week'] ?? '').toString(),
        occurredTime: (j['occurred_time'] ?? '').toString(),
        status: _statusFrom(j['status']),
        resolutionNotes: j['resolution_notes']?.toString(),
        resolvedAt: j['resolved_at']?.toString(),
        resolvedBy: j['resolved_by']?.toString(),
        occurrenceCount: j['occurrence_count'] is int ? j['occurrence_count'] as int : int.tryParse('${j['occurrence_count']}') ?? 1,
      );

  /// گزارش متنی تمیز — برای دکمهٔ «کپی برای هوش مصنوعی»، آمادهٔ پیست مستقیم
  /// در گفتگو با Claude تا مشکل سریع تشخیص داده شود.
  String toAiReport() {
    final b = StringBuffer();
    b.writeln('### گزارش خطا برای بررسی');
    b.writeln('- کد خطا: $errorCode');
    b.writeln('- دسته‌بندی: $category | شدت: ${severity.name} | وضعیت: ${statusToApi(status)}');
    b.writeln('- عنوان: $title');
    b.writeln('- منبع: $source${screenOrEndpoint != null ? ' ($screenOrEndpoint)' : ''}');
    if (httpMethod != null || httpStatus != null) b.writeln('- HTTP: ${httpMethod ?? ''} ${httpStatus ?? ''}');
    b.writeln('- تاریخ: $occurredDate ($occurredDayOfWeek) ساعت $occurredTime (UTC)');
    if (occurrenceCount > 1) b.writeln('- تعداد تکرار: $occurrenceCount بار');
    if (platform != null) {
      b.writeln('- پلتفرم: $platform | نسخهٔ اپ: ${appVersion ?? '-'} | OS: ${osVersion ?? '-'} | دستگاه: ${deviceModel ?? '-'}');
    }
    if (userId != null) b.writeln('- کاربر: $userId (${userRole ?? '-'})');
    b.writeln();
    b.writeln('پیام خطا:');
    b.writeln(message);
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      b.writeln();
      b.writeln('Stack trace:');
      b.writeln(stackTrace);
    }
    if (context != null && context!.isNotEmpty) {
      b.writeln();
      b.writeln('اطلاعات تکمیلی:');
      context!.forEach((k, v) => b.writeln('- $k: $v'));
    }
    return b.toString();
  }
}

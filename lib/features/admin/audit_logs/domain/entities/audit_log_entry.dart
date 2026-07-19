import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════════════════
/// موجودیت «رکورد لاگ بازبینی» (بخش ۲۰.۳ سند — جدول Append-only `audit_logs`).
///
/// پارس JSON کاملاً دفاعی است: هر فیلد ممکن است null، رشتهٔ JSON، یا Map
/// باشد؛ هیچ ورودی بدشکلی نباید اپ را خراب کند (Error Boundary در سطح داده).
/// ═══════════════════════════════════════════════════════════════════════════

/// دسته‌بندی نمایشی رویدادها برای فیلترهای سریع صفحهٔ مانیتورینگ.
enum AuditCategory {
  /// گفتگو/فراخوانی معلم هوشمند (شامل Prompt کامل — بخش ۵.۶).
  ai,

  /// رویدادهای امنیتی: ورود ناموفق/مسدود.
  security,

  /// اقدام‌های حساس مدیر: تغییر نقش/وضعیت، CMS، کد دعوت، پاک‌سازی نصاب.
  sensitive,

  /// سایر رویدادها (ثبت‌نام، ورود موفق، خروج، پیوند والد و…).
  general,
}

class AuditLogEntry {
  final String id;
  final String? actorId;
  final String? actorRole;
  final String actionType;
  final String? targetTable;
  final String? targetId;
  final String? reason;
  final Map<String, dynamic>? beforeValue;
  final Map<String, dynamic>? afterValue;
  final Map<String, dynamic>? detail;
  final String? ipAddress;
  final String priority; // 'normal' | 'high'
  final DateTime? createdAt;

  const AuditLogEntry({
    required this.id,
    required this.actionType,
    required this.priority,
    this.actorId,
    this.actorRole,
    this.targetTable,
    this.targetId,
    this.reason,
    this.beforeValue,
    this.afterValue,
    this.detail,
    this.ipAddress,
    this.createdAt,
  });

  bool get isHighPriority => priority == 'high';

  AuditCategory get category {
    if (actionType == 'ai_invocation') return AuditCategory.ai;
    if (actionType == 'login_failed' || actionType == 'login_blocked') {
      return AuditCategory.security;
    }
    const sensitive = {
      'user_status_change',
      'invite_code_issue',
      'invite_code_revoke',
      'password_reset_link',
      'content_status_change',
      'content_delete',
      'curriculum_wipe',
      'safety_resolve',
      'certificate_issue',
      'certificate_revoke',
      'exam_delete',
    };
    if (sensitive.contains(actionType)) return AuditCategory.sensitive;
    return AuditCategory.general;
  }

  /// آرایهٔ پیام‌های Prompt (برای ai_invocation) — همیشه لیست امن برمی‌گرداند.
  List<AuditPromptMessage> get promptMessages {
    final p = detail?['prompt'];
    if (p is! List) return const [];
    return p
        .whereType<Map>()
        .map((m) => AuditPromptMessage(
              role: (m['role'] ?? '').toString(),
              content: (m['content'] ?? '').toString(),
            ))
        .toList(growable: false);
  }

  /// پیام‌های system (پنجرهٔ RAG Context — متن نصاب تزریق‌شده به مدل).
  List<AuditPromptMessage> get ragContext =>
      promptMessages.where((m) => m.role == 'system').toList(growable: false);

  /// جریان گفتگو (شاگرد ↔ معلم هوشمند) بدون پیام‌های system.
  List<AuditPromptMessage> get conversation =>
      promptMessages.where((m) => m.role != 'system').toList(growable: false);

  String? get replyPreview => detail?['replyPreview']?.toString();
  String? get aiModel => detail?['model']?.toString();
  String? get aiOutcome => detail?['outcome']?.toString();
  String? get subjectId => detail?['subjectId']?.toString();
  String? get attemptedEmail => detail?['email']?.toString();

  /// پارس دفاعی: مقدار می‌تواند null / Map / رشتهٔ JSON / هر چیز دیگری باشد.
  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    if (v is String && v.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString(), val));
        }
        // JSON معتبر ولی غیر-Map (مثلاً آرایه) — زیر یک کلید ثابت نگه می‌داریم.
        return {'value': decoded};
      } catch (_) {
        return {'raw': v};
      }
    }
    return null;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    // سرور D1 با `datetime('now')` مقدار UTC بدون پسوند Z می‌دهد.
    final s = v.toString();
    final parsed = DateTime.tryParse(s.contains('T') ? s : '${s.replaceFirst(' ', 'T')}Z');
    return parsed?.toLocal();
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
        id: (j['id'] ?? '').toString(),
        actorId: j['actorId']?.toString(),
        actorRole: j['actorRole']?.toString(),
        actionType: (j['actionType'] ?? 'unknown').toString(),
        targetTable: j['targetTable']?.toString(),
        targetId: j['targetId']?.toString(),
        reason: j['reason']?.toString(),
        beforeValue: _asMap(j['beforeValue']),
        afterValue: _asMap(j['afterValue']),
        detail: _asMap(j['detail']),
        ipAddress: j['ipAddress']?.toString(),
        priority: (j['priority'] ?? 'normal').toString(),
        createdAt: _asDate(j['createdAt']),
      );
}

class AuditPromptMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;
  const AuditPromptMessage({required this.role, required this.content});
}

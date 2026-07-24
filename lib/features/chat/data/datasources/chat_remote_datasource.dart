import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/chat_entities.dart';

/// قرارداد مشترک DataSource چت — Mock (محلی) و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class ChatDataSource {
  Future<List<Classmate>> getClassmates();
  Future<String> startConversationWith(String classmateId);
  Future<List<PeerConversation>> getConversations();
  Future<List<PeerMessage>> getMessages(String conversationId);
  Future<void> sendMessage(String conversationId, String text, {String? replyToId});
  Future<void> sendVoiceMessage(String conversationId, String audioUrl, int durationMs);
  Future<void> reportMessage(String messageId, String reason);
  Future<List<ClassChatSummary>> getClassChatSummaries();
  Future<List<AdminConversationSummary>> getClassConversations(String classId);
  Future<List<AdminConversationSummary>> getAdminInbox();
  Future<AdminConversationSummary> getConversationInfo(String conversationId);
  Future<List<PeerMessage>> getMessagesForAdmin(String conversationId);
  Future<void> reviewMessage(String conversationId, String messageId, bool approve);
  Future<void> sendAdminReply(String conversationId, String text, {String? replyToId});
}

/// پیاده‌سازی واقعی — روتر media زیر `/api/v1` (بخش ۱۰ سند). پیام صوتی روی
/// R2 آپلود/پخش می‌شود. هویت فرستنده از توکن JWT گرفته می‌شود (سرور).
class ChatRemoteDataSource implements ChatDataSource {
  final ApiClient _api;
  final AppUser? currentUser;

  ChatRemoteDataSource({required ApiClient api, this.currentUser}) : _api = api;

  String get _uid => currentUser?.id ?? '';
  String get _uname => currentUser?.displayName ?? 'من';

  /// آدرس نسبی سرور (مثل `/files/avatars/x.jpg`) → آدرس کامل.
  String? _absoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$kApiBaseUrl$url';
  }
  int get _grade => currentUser?.currentGrade ?? 0;

  /// رفع اشکال: قبلاً این مقادیر همیشه بر اساس صنف محاسبه می‌شدند
  /// (`grade-0`/`صنف 0` برای والد/استاد که صنف ندارند) — چون «ارتباط با
  /// مدیریت» قبلاً فقط از داشبورد شاگرد در دسترس بود. حالا هر نقشی می‌تواند
  /// گفتگوی مدیریت را شروع کند، پس این دو مقدار بر اساس نقش واقعی کاربر
  /// محاسبه می‌شوند (فقط برای شاگرد واقعاً به صنف نیاز است).
  String get _classId {
    switch (currentUser?.role) {
      case AppUserRole.student:
        return 'grade-$_grade';
      case AppUserRole.parent:
        return 'parents';
      case AppUserRole.seminarInstructor:
        return 'instructors';
      case AppUserRole.superAdmin:
      case null:
        return 'admin-support';
    }
  }

  String get _className {
    switch (currentUser?.role) {
      case AppUserRole.student:
        return 'صنف $_grade';
      case AppUserRole.parent:
        return 'والدین';
      case AppUserRole.seminarInstructor:
        return 'استادان';
      case AppUserRole.superAdmin:
      case null:
        return '';
    }
  }

  // ─────────────────────────── هم‌صنفی‌ها ──────────────────────────────

  @override
  Future<List<Classmate>> getClassmates() async {
    final data = await _api.get('/classmates');
    final list = (data as List? ?? []);
    return list
        .map((e) => Classmate(
              id: e['id'] as String,
              name: e['name'] as String? ?? '',
              classId: e['classId'] as String? ?? _classId,
              className: e['className'] as String? ?? _className,
              avatarUrl: _absoluteUrl(e['avatarUrl'] as String?),
            ))
        .toList();
  }

  // ─────────────────────────── شروع گفتگو ──────────────────────────────

  @override
  Future<String> startConversationWith(String classmateId) async {
    if (classmateId == 'admin') {
      final data = await _api.post('/conversations', data: {
        'type': 'admin',
        'classId': _classId,
        'className': _className,
        'participants': [
          {'id': _uid, 'name': _uname, 'className': _className},
          {'id': 'admin', 'name': 'مدیریت و پشتیبانی مکتب', 'className': ''},
        ],
      });
      return data['id'] as String;
    }
    // نام هم‌صنفی را از فهرست هم‌صنفی‌ها پیدا کن تا participants کامل باشد.
    final mates = await getClassmates();
    final mate = mates.firstWhere(
      (m) => m.id == classmateId,
      orElse: () => Classmate(id: classmateId, name: 'هم‌صنفی', classId: _classId, className: _className),
    );
    final data = await _api.post('/conversations', data: {
      'type': 'dm',
      'classId': _classId,
      'className': _className,
      'participants': [
        {'id': _uid, 'name': _uname, 'className': _className},
        {'id': mate.id, 'name': mate.name, 'className': mate.className},
      ],
    });
    return data['id'] as String;
  }

  // ─────────────────────────── گفتگوهای من ─────────────────────────────

  @override
  Future<List<PeerConversation>> getConversations() async {
    final data = await _api.get('/users/$_uid/conversations');
    final list = (data as List? ?? []);
    return list.map((c) {
      final isAdmin = c['type'] == 'admin';
      final parts = _participants(c['participants']);
      final peer = parts.firstWhere(
        (p) => p['id'] != _uid,
        orElse: () => {'id': 'admin', 'name': 'مدیریت مکتب', 'className': ''},
      );
      return PeerConversation(
        id: c['id'] as String,
        peerId: (peer['id'] ?? '') as String,
        peerName: isAdmin ? 'مدیریت و پشتیبانی مکتب' : (peer['name'] ?? '') as String,
        peerClassName: (peer['className'] ?? '') as String,
        lastMessage: (c['last_message'] ?? '') as String,
        lastMessageAt: _date(c['last_message_at']),
        isAdmin: isAdmin,
      );
    }).toList();
  }

  // ─────────────────────────── پیام‌ها (شاگرد) ─────────────────────────

  @override
  Future<List<PeerMessage>> getMessages(String conversationId) async {
    final data = await _api.get('/conversations/$conversationId/messages',
        queryParameters: {'viewerId': _uid});
    return _messages(data);
  }

  @override
  Future<void> sendMessage(String conversationId, String text, {String? replyToId}) async {
    await _api.post('/conversations/$conversationId/messages', data: {
      'senderName': _uname,
      'senderClassName': _className,
      'text': text,
      if (replyToId != null) 'replyToId': replyToId,
    });
  }

  @override
  Future<void> sendVoiceMessage(String conversationId, String audioUrl, int durationMs) async {
    final bytes = await File(audioUrl).readAsBytes();
    await _api.raw.post(
      '/conversations/$conversationId/messages/voice',
      data: Stream.fromIterable([bytes]),
      options: Options(
        method: 'POST',
        contentType: 'audio/m4a',
        headers: {
          'X-Sender-Name': Uri.encodeComponent(_uname),
          'X-Sender-Class': Uri.encodeComponent(_className),
          'X-Duration-Ms': '$durationMs',
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
  }

  @override
  Future<void> reportMessage(String messageId, String reason) async {
    await _api.post('/messages/$messageId/report', data: {
      'reason': reason,
      'reportedByName': _uname,
    });
  }

  // ─────────────────────────── نمای مدیر ───────────────────────────────

  @override
  Future<List<ClassChatSummary>> getClassChatSummaries() async {
    final data = await _api.get('/admin/chat/overview');
    final list = (data as List? ?? []);
    return list
        .map((e) => ClassChatSummary(
              classId: (e['class_id'] ?? '') as String,
              className: (e['class_name'] ?? '') as String,
              studentCount: (e['student_count'] as num?)?.toInt() ?? 0,
              conversationCount: (e['conversation_count'] as num?)?.toInt() ?? 0,
              messageCount: (e['message_count'] as num?)?.toInt() ?? 0,
              flaggedPendingCount: (e['flagged_pending_count'] as num?)?.toInt() ?? 0,
              lastActivityAt: e['last_activity_at'] != null ? _date(e['last_activity_at']) : null,
            ))
        .toList();
  }

  @override
  Future<List<AdminConversationSummary>> getClassConversations(String classId) async {
    final data = await _api.get('/admin/chat/classes/$classId/conversations');
    return (data as List? ?? []).map(_adminConv).toList();
  }

  @override
  Future<List<AdminConversationSummary>> getAdminInbox() async {
    final data = await _api.get('/admin/chat/inbox');
    return (data as List? ?? []).map(_adminConv).toList();
  }

  @override
  Future<AdminConversationSummary> getConversationInfo(String conversationId) async {
    final data = await _api.get('/admin/conversations/$conversationId/info');
    return _adminConv(data);
  }

  @override
  Future<List<PeerMessage>> getMessagesForAdmin(String conversationId) async {
    final data = await _api.get('/admin/conversations/$conversationId/messages');
    return _messages(data, adminView: true);
  }

  @override
  Future<void> reviewMessage(String conversationId, String messageId, bool approve) async {
    await _api.post('/admin/messages/$messageId/review', data: {'approve': approve});
  }

  @override
  Future<void> sendAdminReply(String conversationId, String text, {String? replyToId}) async {
    await _api.post('/admin/conversations/$conversationId/reply', data: {
      'text': text,
      if (replyToId != null) 'replyToId': replyToId,
    });
  }

  // ─────────────────────────── کمک‌کننده‌ها ─────────────────────────────

  List<Map<String, dynamic>> _participants(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return const [];
  }

  AdminConversationSummary _adminConv(dynamic c) {
    final parts = _participants(c['participants']);
    final names = parts.map((p) => (p['name'] ?? '') as String).where((s) => s.isNotEmpty).toList();
    final isAdmin = c['type'] == 'admin';
    return AdminConversationSummary(
      id: c['id'] as String,
      classId: (c['class_id'] ?? '') as String,
      className: (c['class_name'] ?? '') as String,
      title: isAdmin
          ? '${names.isNotEmpty ? names.first : 'شاگرد'} ↔ مدیریت'
          : names.join(' ↔ '),
      participantNames: names,
      lastMessage: (c['last_message'] ?? '') as String,
      lastMessageAt: _date(c['last_message_at']),
      messageCount: (c['message_count'] as num?)?.toInt() ?? 0,
      flaggedPendingCount: (c['flagged_pending_count'] as num?)?.toInt() ?? 0,
      isAdminSupport: isAdmin,
    );
  }

  List<PeerMessage> _messages(dynamic data, {bool adminView = false}) {
    final list = (data as List? ?? []);
    return list.map((m) {
      final kind = m['kind'] == 'voice' ? MessageKind.voice : MessageKind.text;
      final audioKey = m['audio_key'] as String?;
      return PeerMessage(
        id: m['id'] as String,
        senderId: (m['sender_id'] ?? '') as String,
        senderName: (m['sender_name'] ?? '') as String,
        senderClassName: (m['sender_class_name'] ?? '') as String,
        fromMe: !adminView && m['sender_id'] == _uid,
        body: (m['body'] ?? '') as String,
        timestamp: _date(m['created_at']),
        flagged: (m['flagged'] as num?)?.toInt() == 1,
        reviewStatus: _review(m['review_status'] as String?),
        kind: kind,
        audioUrl: (kind == MessageKind.voice && audioKey != null)
            ? '$kApiBaseUrl/files/$audioKey'
            : null,
        durationMs: (m['duration_ms'] as num?)?.toInt(),
        replyToId: m['reply_to_id'] as String?,
      );
    }).toList();
  }

  MessageReviewStatus _review(String? s) => switch (s) {
        'pending' => MessageReviewStatus.pending,
        'approved' => MessageReviewStatus.approved,
        'rejected' => MessageReviewStatus.rejected,
        _ => MessageReviewStatus.none,
      };

  DateTime _date(dynamic v) =>
      DateTime.tryParse((v as String?)?.replaceFirst(' ', 'T') ?? '') ?? DateTime.now();
}

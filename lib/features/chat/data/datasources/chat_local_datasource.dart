import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/chat_entities.dart';
import 'chat_remote_datasource.dart' show ChatDataSource;

/// شناسهٔ کاربری مدیریت در گفتگوهای «شاگرد ↔ مدیریت».
const String kAdminUserId = 'admin';
const String kAdminDisplayName = 'مدیریت و پشتیبانی مکتب';

/// چت محلی و پایدار (SharedPreferences) — منطق صنف‌محور:
///   • هر شاگرد عضو یک صنف است و فقط با هم‌صنفی‌های خودش چت دو نفره دارد
///     (بخش ۱۰.۱الف سند: «فقط بین هم‌صنفی‌ها»).
///   • هر پیام با هویت واقعی فرستنده (نام + صنف) ذخیره می‌شود تا مدیر در
///     بازبینی، دقیقاً بداند پیام از کیست (بخش ۱۰.۴: نظارت مدیر).
///   • پیام flag‌شده تا تأیید مدیر به گیرنده نمی‌رسد (بخش ۱۰.۱الف).
///
/// ساختار ذخیره (نسخهٔ ۲ — کلیدهای v1 قدیمی نادیده گرفته می‌شوند):
///   chat_v2_conversations            → فهرست همهٔ گفتگوها (همهٔ کاربران)
///   chat_v2_messages_<convId>        → پیام‌های یک گفتگو
///   chat_v2_lastread_<uid>_<convId>  → آخرین زمان خواندن برای شمارش نخوانده
///   chat_v2_roster_extra             → شاگردان ثبت‌نام‌شدهٔ جدید (افزوده به روستر)
///
/// هماهنگ‌سازی واقعی بین دستگاه‌ها نیازمند بک‌اند Cloudflare است (فاز بعد؛
/// backend/src/index.ts همین قرارداد داده را پیاده کرده است).
class ChatLocalDataSource implements ChatDataSource {
  static const _convKey = 'chat_v2_conversations';
  static const _msgKeyPrefix = 'chat_v2_messages_';
  static const _lastReadPrefix = 'chat_v2_lastread_';
  static const _rosterExtraKey = 'chat_v2_roster_extra';
  static const _reportsKey = 'chat_v2_reports';
  static const _seededKey = 'chat_v2_seeded';

  /// فیلتر کلمات نامناسب سرور-ساید (شبیه‌سازی محلی — بخش ۱۰.۱الف).
  static const _bannedWords = ['فحش', 'بد', 'احمق', 'لعنتی'];

  /// کاربر فعلی (از نشست Auth تزریق می‌شود). null یعنی خارج از نشست.
  final AppUser? currentUser;
  ChatLocalDataSource({this.currentUser});

  // -------------------------------------------------------------------------
  // روستر صنف‌ها و شاگردان (فاز ۱: ساختگی + شاگردان ثبت‌نام‌شدهٔ جدید)
  // -------------------------------------------------------------------------

  static const List<Map<String, String>> _classes = [
    {'id': 'class-7a', 'name': 'صنف هفتم — الف'},
    {'id': 'class-8b', 'name': 'صنف هشتم — ب'},
  ];

  static const List<Map<String, String>> _baseRoster = [
    {'id': 'u-student-demo', 'name': 'مریم احمدی', 'classId': 'class-7a'},
    {'id': 'u-fatima', 'name': 'فاطمه رضایی', 'classId': 'class-7a'},
    {'id': 'u-zahra', 'name': 'زهرا محمدی', 'classId': 'class-7a'},
    {'id': 'u-samira', 'name': 'سمیرا حسینی', 'classId': 'class-7a'},
    {'id': 'u-narges', 'name': 'نرگس عزیزی', 'classId': 'class-8b'},
    {'id': 'u-fereshta', 'name': 'فرشته نوری', 'classId': 'class-8b'},
    {'id': 'u-hadia', 'name': 'هدیه صادقی', 'classId': 'class-8b'},
  ];

  static String classNameOf(String classId) =>
      _classes.firstWhere((c) => c['id'] == classId, orElse: () => {'name': ''})['name'] ?? '';

  Future<List<Map<String, String>>> _fullRoster() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rosterExtraKey);
    final extras = raw == null
        ? <Map<String, String>>[]
        : List<Map<String, dynamic>>.from(jsonDecode(raw) as List)
            .map((e) => e.map((k, v) => MapEntry(k, v.toString())))
            .toList();
    return [..._baseRoster, ...extras];
  }

  /// شاگردِ واردشده‌ای که در روستر نیست (ثبت‌نام جدید) به صنف پیش‌فرض
  /// (صنف هفتم — الف) افزوده می‌شود تا بلافاصله هم‌صنفی داشته باشد.
  Future<Map<String, String>> _ensureInRoster() async {
    final user = currentUser;
    if (user == null) throw StateError('برای چت باید وارد سیستم شده باشید.');
    if (user.role != AppUserRole.student) {
      // مدیر/والد/استاد عضو روستر صنف نیستند؛ مدیر از مسیر نظارتی
      // (getMessagesForAdmin و ...) وارد چت می‌شود.
      throw StateError('چت دو نفره مخصوص شاگردان است.');
    }
    final roster = await _fullRoster();
    final found = roster.where((r) => r['id'] == user.id).toList();
    if (found.isNotEmpty) return found.first;

    final entry = {'id': user.id, 'name': user.displayName, 'classId': 'class-7a'};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rosterExtraKey);
    final extras = raw == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(raw) as List);
    extras.add(entry);
    await prefs.setString(_rosterExtraKey, jsonEncode(extras));
    return entry;
  }

  @override
  Future<List<Classmate>> getClassmates() async {
    final me = await _ensureInRoster();
    final roster = await _fullRoster();
    return roster
        .where((r) => r['classId'] == me['classId'] && r['id'] != me['id'])
        .map((r) => Classmate(
              id: r['id']!,
              name: r['name']!,
              classId: r['classId']!,
              className: classNameOf(r['classId']!),
            ))
        .toList();
  }

  // -------------------------------------------------------------------------
  // ذخیره/خواندن خام
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _readConvsRaw() async {
    await _seedIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<void> _writeConvsRaw(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_convKey, jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> _readMsgsRaw(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_msgKeyPrefix$conversationId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<void> _writeMsgsRaw(String conversationId, List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_msgKeyPrefix$conversationId', jsonEncode(list));
  }

  // -------------------------------------------------------------------------
  // ساخت گفتگو
  // -------------------------------------------------------------------------

  /// شناسهٔ قطعی گفتگوی دو نفره — مستقل از این‌که چه کسی شروع کرده.
  static String dmIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
  }

  static String adminConvIdFor(String studentId) => 'admin_$studentId';

  Future<Map<String, dynamic>> _ensureConversation({
    required String id,
    required String type, // 'dm' | 'admin'
    required String classId,
    required List<Map<String, String>> participants, // {id, name, className}
    String seedLastMessage = '',
  }) async {
    final convs = await _readConvsRaw();
    final existing = convs.where((c) => c['id'] == id).toList();
    if (existing.isNotEmpty) return existing.first;
    final conv = {
      'id': id,
      'type': type,
      'classId': classId,
      'className': classNameOf(classId),
      'participants': participants,
      'lastMessage': seedLastMessage,
      'lastMessageAt': DateTime.now().toIso8601String(),
    };
    convs.add(conv);
    await _writeConvsRaw(convs);
    return conv;
  }

  /// شروع (یا بازیابی) گفتگوی دو نفره با یک هم‌صنفی — شناسه را برمی‌گرداند.
  @override
  Future<String> startConversationWith(String classmateId) async {
    final me = await _ensureInRoster();
    final roster = await _fullRoster();
    final peer = roster.firstWhere((r) => r['id'] == classmateId,
        orElse: () => throw StateError('هم‌صنفی موردنظر یافت نشد.'));
    if (peer['classId'] != me['classId']) {
      // بخش ۱۰.۱الف: چت دو نفره فقط بین هم‌صنفی‌ها مجاز است.
      throw StateError('گفتگو فقط با هم‌صنفی‌های خودتان امکان‌پذیر است.');
    }
    final id = dmIdFor(me['id']!, peer['id']!);
    await _ensureConversation(
      id: id,
      type: 'dm',
      classId: me['classId']!,
      participants: [
        {'id': me['id']!, 'name': me['name']!, 'className': classNameOf(me['classId']!)},
        {'id': peer['id']!, 'name': peer['name']!, 'className': classNameOf(peer['classId']!)},
      ],
    );
    return id;
  }

  Future<String> _ensureAdminConversation() async {
    final me = await _ensureInRoster();
    final id = adminConvIdFor(me['id']!);
    final existing = (await _readConvsRaw()).any((c) => c['id'] == id);
    await _ensureConversation(
      id: id,
      type: 'admin',
      classId: me['classId']!,
      participants: [
        {'id': me['id']!, 'name': me['name']!, 'className': classNameOf(me['classId']!)},
        {'id': kAdminUserId, 'name': kAdminDisplayName, 'className': ''},
      ],
      seedLastMessage: 'سؤال یا مشکلی داشتید، همین‌جا بنویسید.',
    );
    if (!existing) {
      await _appendMessage(
        conversationId: id,
        senderId: kAdminUserId,
        senderName: kAdminDisplayName,
        senderClassName: '',
        body: 'سلام! این‌جا می‌توانید مستقیم با مدیریت مکتب در تماس باشید. چطور می‌توانیم کمک کنیم؟',
        touch: false,
      );
    }
    return id;
  }

  // -------------------------------------------------------------------------
  // فهرست گفتگوها و پیام‌ها (دید شاگرد)
  // -------------------------------------------------------------------------

  @override
  Future<List<PeerConversation>> getConversations() async {
    await Future.delayed(const Duration(milliseconds: 150));
    final me = await _ensureInRoster();
    await _ensureAdminConversation();
    final convs = await _readConvsRaw();
    final mine = convs.where((c) {
      final parts = List<Map<String, dynamic>>.from(
          (c['participants'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      return parts.any((p) => p['id'] == me['id']);
    }).toList();

    final result = <PeerConversation>[];
    for (final c in mine) {
      final parts = List<Map<String, dynamic>>.from(
          (c['participants'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      final peer = parts.firstWhere((p) => p['id'] != me['id'], orElse: () => parts.first);
      final isAdmin = c['type'] == 'admin';
      result.add(PeerConversation(
        id: c['id'] as String,
        peerId: peer['id'] as String,
        peerName: peer['name'] as String,
        peerClassName: (peer['className'] as String?) ?? '',
        lastMessage: (c['lastMessage'] as String?) ?? '',
        lastMessageAt:
            DateTime.tryParse(c['lastMessageAt'] as String? ?? '') ?? DateTime.now(),
        unreadCount: await _unreadCount(me['id']!, c['id'] as String),
        isAdmin: isAdmin,
      ));
    }
    result.sort((a, b) {
      if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
      return b.lastMessageAt.compareTo(a.lastMessageAt);
    });
    return result;
  }

  Future<int> _unreadCount(String userId, String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRead =
        DateTime.tryParse(prefs.getString('$_lastReadPrefix${userId}_$conversationId') ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final msgs = await _readMsgsRaw(conversationId);
    return msgs.where((m) {
      final ts = DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now();
      final fromOther = m['senderId'] != userId;
      final pending = (m['flagged'] as bool? ?? false) && m['review'] == 'pending';
      return fromOther && !pending && ts.isAfter(lastRead);
    }).length;
  }

  PeerMessage _toMessage(Map<String, dynamic> m, {required String viewerId}) {
    final review = switch (m['review'] as String? ?? 'none') {
      'pending' => MessageReviewStatus.pending,
      'approved' => MessageReviewStatus.approved,
      'rejected' => MessageReviewStatus.rejected,
      _ => MessageReviewStatus.none,
    };
    return PeerMessage(
      id: m['id'] as String,
      senderId: m['senderId'] as String,
      senderName: (m['senderName'] as String?) ?? '',
      senderClassName: (m['senderClassName'] as String?) ?? '',
      fromMe: m['senderId'] == viewerId,
      body: (m['body'] as String?) ?? '',
      timestamp: DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
      flagged: m['flagged'] as bool? ?? false,
      reviewStatus: review,
      kind: (m['kind'] as String?) == 'voice' ? MessageKind.voice : MessageKind.text,
      audioUrl: m['audioUrl'] as String?,
      durationMs: m['durationMs'] as int?,
      replyToId: m['replyToId'] as String?,
    );
  }

  /// پیام‌های یک گفتگو از دید کاربر فعلی. پیام flag‌شدهٔ در انتظار بازبینی
  /// فقط برای فرستنده‌اش نمایش داده می‌شود (بخش ۱۰.۱الف).
  @override
  Future<List<PeerMessage>> getMessages(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final me = await _ensureInRoster();
    final msgs = await _readMsgsRaw(conversationId);
    // ثبت «خوانده‌شد» برای شمارش نخوانده‌ها.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_lastReadPrefix${me['id']}_$conversationId', DateTime.now().toIso8601String());
    return msgs
        .map((m) => _toMessage(m, viewerId: me['id']!))
        .where((m) => m.fromMe || (!m.isPendingReview && !m.isRejected))
        .toList();
  }

  // -------------------------------------------------------------------------
  // ارسال پیام
  // -------------------------------------------------------------------------

  Future<void> _appendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderClassName,
    String body = '',
    String kind = 'text',
    String? audioUrl,
    int? durationMs,
    bool flagged = false,
    bool touch = true,
    String? preview,
    String? replyToId,
  }) async {
    final msgs = await _readMsgsRaw(conversationId);
    msgs.add({
      'id': 'm${DateTime.now().microsecondsSinceEpoch}',
      'senderId': senderId,
      'senderName': senderName,
      'senderClassName': senderClassName,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
      'flagged': flagged,
      'review': flagged ? 'pending' : 'none',
      'kind': kind,
      'audioUrl': audioUrl,
      'durationMs': durationMs,
      'replyToId': replyToId,
    });
    await _writeMsgsRaw(conversationId, msgs);
    if (touch) {
      final convs = await _readConvsRaw();
      final idx = convs.indexWhere((c) => c['id'] == conversationId);
      if (idx != -1) {
        convs[idx]['lastMessage'] =
            flagged ? 'در انتظار بازبینی مدیر...' : (preview ?? body);
        convs[idx]['lastMessageAt'] = DateTime.now().toIso8601String();
        await _writeConvsRaw(convs);
      }
    }
  }

  @override
  Future<void> sendMessage(String conversationId, String text, {String? replyToId}) async {
    final me = await _ensureInRoster();
    final flagged = _bannedWords.any((w) => text.contains(w));
    await _appendMessage(
      conversationId: conversationId,
      senderId: me['id']!,
      senderName: me['name']!,
      senderClassName: classNameOf(me['classId']!),
      body: text,
      flagged: flagged,
      replyToId: replyToId,
    );
  }

  @override
  Future<void> sendVoiceMessage(String conversationId, String audioUrl, int durationMs) async {
    final me = await _ensureInRoster();
    await _appendMessage(
      conversationId: conversationId,
      senderId: me['id']!,
      senderName: me['name']!,
      senderClassName: classNameOf(me['classId']!),
      kind: 'voice',
      audioUrl: audioUrl,
      durationMs: durationMs,
      preview: '🎙 پیام صوتی',
    );
  }

  /// ذخیرهٔ گزارش تخلف با هویت گزارش‌دهنده — به صف بازبینی مدیر می‌رود.
  @override
  Future<void> reportMessage(String messageId, String reason) async {
    final me = await _ensureInRoster();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reportsKey);
    final list =
        raw == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(raw) as List);
    list.add({
      'messageId': messageId,
      'reason': reason,
      'reportedById': me['id'],
      'reportedByName': me['name'],
      'reportedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_reportsKey, jsonEncode(list));
  }

  // -------------------------------------------------------------------------
  // دید مدیر — نظارت صنف‌به‌صنف با هویت واقعی (بخش ۱۰.۴)
  // -------------------------------------------------------------------------

  @override
  Future<List<ClassChatSummary>> getClassChatSummaries() async {
    await Future.delayed(const Duration(milliseconds: 150));
    await _seedIfNeeded();
    final convs = await _readConvsRaw();
    final roster = await _fullRoster();
    final result = <ClassChatSummary>[];
    for (final cls in _classes) {
      final classConvs = convs.where((c) => c['classId'] == cls['id']).toList();
      var messageCount = 0;
      var flaggedPending = 0;
      DateTime? lastActivity;
      for (final c in classConvs) {
        final msgs = await _readMsgsRaw(c['id'] as String);
        messageCount += msgs.length;
        flaggedPending += msgs
            .where((m) => (m['flagged'] as bool? ?? false) && m['review'] == 'pending')
            .length;
        final ts = DateTime.tryParse(c['lastMessageAt'] as String? ?? '');
        if (ts != null && (lastActivity == null || ts.isAfter(lastActivity))) {
          lastActivity = ts;
        }
      }
      result.add(ClassChatSummary(
        classId: cls['id']!,
        className: cls['name']!,
        studentCount: roster.where((r) => r['classId'] == cls['id']).length,
        conversationCount: classConvs.length,
        messageCount: messageCount,
        flaggedPendingCount: flaggedPending,
        lastActivityAt: lastActivity,
      ));
    }
    return result;
  }

  @override
  Future<List<AdminConversationSummary>> getClassConversations(String classId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final convs = await _readConvsRaw();
    final result = <AdminConversationSummary>[];
    for (final c in convs.where((c) => c['classId'] == classId)) {
      final parts = List<Map<String, dynamic>>.from(
          (c['participants'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      final names = parts.map((p) => p['name'] as String).toList();
      final isAdminSupport = c['type'] == 'admin';
      final msgs = await _readMsgsRaw(c['id'] as String);
      result.add(AdminConversationSummary(
        id: c['id'] as String,
        classId: classId,
        className: classNameOf(classId),
        title: isAdminSupport
            ? names.firstWhere((n) => n != kAdminDisplayName, orElse: () => names.first)
            : names.join(' ↔ '),
        participantNames: names,
        lastMessage: (c['lastMessage'] as String?) ?? '',
        lastMessageAt:
            DateTime.tryParse(c['lastMessageAt'] as String? ?? '') ?? DateTime.now(),
        messageCount: msgs.length,
        flaggedPendingCount: msgs
            .where((m) => (m['flagged'] as bool? ?? false) && m['review'] == 'pending')
            .length,
        isAdminSupport: isAdminSupport,
      ));
    }
    result.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return result;
  }

  /// همهٔ گفتگوهای «شاگرد ↔ مدیریت» از تمام صنف‌ها — صندوق پیام مدیر.
  @override
  Future<List<AdminConversationSummary>> getAdminInbox() async {
    await Future.delayed(const Duration(milliseconds: 150));
    await _seedIfNeeded();
    final convs = await _readConvsRaw();
    final result = <AdminConversationSummary>[];
    for (final c in convs.where((c) => c['type'] == 'admin')) {
      final parts = List<Map<String, dynamic>>.from(
          (c['participants'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      final student =
          parts.firstWhere((p) => p['id'] != kAdminUserId, orElse: () => parts.first);
      final msgs = await _readMsgsRaw(c['id'] as String);
      result.add(AdminConversationSummary(
        id: c['id'] as String,
        classId: (c['classId'] as String?) ?? '',
        className: (c['className'] as String?) ?? '',
        title: student['name'] as String,
        participantNames: parts.map((p) => p['name'] as String).toList(),
        lastMessage: (c['lastMessage'] as String?) ?? '',
        lastMessageAt:
            DateTime.tryParse(c['lastMessageAt'] as String? ?? '') ?? DateTime.now(),
        messageCount: msgs.length,
        flaggedPendingCount: msgs
            .where((m) => (m['flagged'] as bool? ?? false) && m['review'] == 'pending')
            .length,
        isAdminSupport: true,
      ));
    }
    result.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return result;
  }

  /// مشخصات یک گفتگو برای هدر صفحهٔ نظارتی مدیر.
  @override
  Future<AdminConversationSummary> getConversationInfo(String conversationId) async {
    final convs = await _readConvsRaw();
    final c = convs.firstWhere((c) => c['id'] == conversationId,
        orElse: () => throw StateError('گفتگو یافت نشد.'));
    final parts = List<Map<String, dynamic>>.from(
        (c['participants'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final names = parts.map((p) => p['name'] as String).toList();
    final isAdminSupport = c['type'] == 'admin';
    final msgs = await _readMsgsRaw(conversationId);
    return AdminConversationSummary(
      id: conversationId,
      classId: (c['classId'] as String?) ?? '',
      className: (c['className'] as String?) ?? '',
      title: isAdminSupport
          ? names.firstWhere((n) => n != kAdminDisplayName, orElse: () => names.first)
          : names.join(' ↔ '),
      participantNames: names,
      lastMessage: (c['lastMessage'] as String?) ?? '',
      lastMessageAt:
          DateTime.tryParse(c['lastMessageAt'] as String? ?? '') ?? DateTime.now(),
      messageCount: msgs.length,
      flaggedPendingCount: msgs
          .where((m) => (m['flagged'] as bool? ?? false) && m['review'] == 'pending')
          .length,
      isAdminSupport: isAdminSupport,
    );
  }

  /// همهٔ پیام‌های یک گفتگو برای مدیر — شامل flag‌شده‌های در انتظار بازبینی.
  @override
  Future<List<PeerMessage>> getMessagesForAdmin(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final msgs = await _readMsgsRaw(conversationId);
    return msgs.map((m) => _toMessage(m, viewerId: kAdminUserId)).toList();
  }

  /// تصمیم مدیر دربارهٔ پیام flag‌شده: تأیید (تحویل به گیرنده) یا رد.
  @override
  Future<void> reviewMessage(String conversationId, String messageId, bool approve) async {
    final msgs = await _readMsgsRaw(conversationId);
    final idx = msgs.indexWhere((m) => m['id'] == messageId);
    if (idx == -1) return;
    msgs[idx]['review'] = approve ? 'approved' : 'rejected';
    await _writeMsgsRaw(conversationId, msgs);
    if (approve) {
      final convs = await _readConvsRaw();
      final cIdx = convs.indexWhere((c) => c['id'] == conversationId);
      if (cIdx != -1) {
        convs[cIdx]['lastMessage'] = (msgs[idx]['body'] as String?) ?? '';
        await _writeConvsRaw(convs);
      }
    }
  }

  /// پاسخ مدیر در گفتگوی «شاگرد ↔ مدیریت».
  @override
  Future<void> sendAdminReply(String conversationId, String text, {String? replyToId}) async {
    await _appendMessage(
      conversationId: conversationId,
      senderId: kAdminUserId,
      senderName: kAdminDisplayName,
      senderClassName: '',
      body: text,
      replyToId: replyToId,
    );
  }

  // -------------------------------------------------------------------------
  // داده‌های نمایشی اولیه — تا اپ در اولین اجرا خالی و بی‌روح نباشد
  // -------------------------------------------------------------------------

  Future<void> _seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) ?? false) return;
    await prefs.setBool(_seededKey, true);

    Future<void> seedDm(String aId, String aName, String bId, String bName, String classId,
        List<(String, String)> messages) async {
      final id = dmIdFor(aId, bId);
      final cls = classNameOf(classId);
      await _ensureConversation(id: id, type: 'dm', classId: classId, participants: [
        {'id': aId, 'name': aName, 'className': cls},
        {'id': bId, 'name': bName, 'className': cls},
      ]);
      for (final (senderId, body) in messages) {
        await _appendMessage(
          conversationId: id,
          senderId: senderId,
          senderName: senderId == aId ? aName : bName,
          senderClassName: cls,
          body: body,
        );
      }
    }

    await seedDm('u-fatima', 'فاطمه رضایی', 'u-student-demo', 'مریم احمدی', 'class-7a', [
      ('u-fatima', 'سلام، تکلیف ریاضی را حل کردی؟'),
      ('u-fatima', 'اگر وقت داشتی سؤال سومش را برایم توضیح بده 🙏'),
    ]);
    await seedDm('u-zahra', 'زهرا محمدی', 'u-student-demo', 'مریم احمدی', 'class-7a', [
      ('u-zahra', 'فردا برای سمینار می‌آیی؟'),
    ]);
    await seedDm('u-narges', 'نرگس عزیزی', 'u-fereshta', 'فرشته نوری', 'class-8b', [
      ('u-narges', 'جزوهٔ علوم را از کجا دانلود کنم؟'),
      ('u-fereshta', 'از بخش کتابخانه، فصل دوم را ببین.'),
    ]);

    // گفتگوی نمونهٔ «شاگرد ↔ مدیریت» از صنف دیگر — تا صندوق پیام مدیر
    // از روز اول یک نمونهٔ واقعی با هویت شاگرد داشته باشد.
    final nargesAdminId = adminConvIdFor('u-narges');
    await _ensureConversation(
      id: nargesAdminId,
      type: 'admin',
      classId: 'class-8b',
      participants: [
        {'id': 'u-narges', 'name': 'نرگس عزیزی', 'className': classNameOf('class-8b')},
        {'id': kAdminUserId, 'name': kAdminDisplayName, 'className': ''},
      ],
    );
    await _appendMessage(
      conversationId: nargesAdminId,
      senderId: 'u-narges',
      senderName: 'نرگس عزیزی',
      senderClassName: classNameOf('class-8b'),
      body: 'سلام استاد، رمز ورودم را فراموش کرده‌ام؛ لطفاً راهنمایی کنید.',
    );
  }
}

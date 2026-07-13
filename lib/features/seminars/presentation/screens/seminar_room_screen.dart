import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared_models/seminar.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/seminar_store.dart';
import '../providers/seminars_providers.dart';

/// اتاق ویدیو کنفرانس زندهٔ سمینار — تجربهٔ مدرن و کامل برای هر چهار نقش:
/// استاد/مدیر به‌عنوان میزبان (شروع، بی‌صدا کردن همه، پایان جلسه) و
/// شاگرد/والد به‌عنوان شرکت‌کننده (میکروفن، دوربین، بلند کردن دست، گفتگو).
///
/// در فاز ۱ (Mock) جریان صوت/تصویر شبیه‌سازی می‌شود؛ از فاز ۲ همین UI به
/// WebRTC/SFU واقعی وصل خواهد شد (بخش ۱۲ سند).
class SeminarRoomScreen extends ConsumerStatefulWidget {
  final String seminarId;
  const SeminarRoomScreen({super.key, required this.seminarId});

  @override
  ConsumerState<SeminarRoomScreen> createState() => _SeminarRoomScreenState();
}

class _RoomParticipant {
  final String name;
  final bool isHost;
  final bool isMe;
  bool micOn;
  bool cameraOn;
  bool handRaised = false;
  bool speaking;

  _RoomParticipant({
    required this.name,
    this.isHost = false,
    this.isMe = false,
    this.micOn = false,
    this.cameraOn = false,
    this.speaking = false,
  });
}

class _ChatMessage {
  final String sender;
  final String text;
  final bool isMe;
  _ChatMessage(this.sender, this.text, {this.isMe = false});
}

enum _SidePanel { none, chat, participants }

class _SeminarRoomScreenState extends ConsumerState<SeminarRoomScreen> {
  final _random = Random();
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  bool _micOn = false;
  bool _cameraOn = false;
  bool _handRaised = false;
  _SidePanel _panel = _SidePanel.none;

  Duration _elapsed = Duration.zero;
  Timer? _clockTimer;
  Timer? _simulationTimer;

  List<_RoomParticipant> _participants = [];
  final List<_ChatMessage> _messages = [];
  bool _initialized = false;
  int _unreadMessages = 0;

  static const _studentNames = [
    'مریم احمدی', 'زهرا حسینی', 'فاطمه رضایی', 'سمیرا نظری',
    'فرشته کریمی', 'نرگس امیری', 'شبنم صادقی', 'هدیه محمدی',
    'رقیه یوسفی', 'مرسل حیدری', 'آرزو رحیمی',
  ];

  static const _autoChatLines = [
    'سلام، صدا واضح است 🌟',
    'تشکر استاد، خیلی مفید بود',
    'لطفاً این بخش را دوباره توضیح دهید',
    'من هم همین سؤال را داشتم',
    'عالی بود 👏',
  ];

  @override
  void dispose() {
    _clockTimer?.cancel();
    _simulationTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  bool _isHostUser(AppUser? user, Seminar seminar) {
    if (user == null) return false;
    return user.role == AppUserRole.superAdmin ||
        (user.role == AppUserRole.seminarInstructor && user.id == seminar.instructorId);
  }

  void _initRoom(Seminar seminar, AppUser user, bool isHost) {
    if (_initialized) return;
    _initialized = true;

    final visibleCount = min(seminar.registeredCount, 7);
    _participants = [
      _RoomParticipant(
        name: isHost ? user.displayName : seminar.instructorName,
        isHost: true,
        isMe: isHost,
        micOn: true,
        cameraOn: true,
        speaking: true,
      ),
      if (!isHost)
        _RoomParticipant(name: user.displayName, isMe: true),
      for (var i = 0; i < visibleCount; i++)
        _RoomParticipant(
          name: _studentNames[i % _studentNames.length],
          micOn: false,
        ),
    ];

    _messages.add(_ChatMessage(seminar.instructorName,
        'به سمینار «${seminar.title}» خوش آمدید 🌸'));

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        // چرخش گویندهٔ فعال (شبیه‌سازی)
        for (final p in _participants) {
          p.speaking = false;
        }
        final speakerPool =
            _participants.where((p) => p.isHost || (p.micOn && !p.isMe)).toList();
        if (speakerPool.isNotEmpty) {
          speakerPool[_random.nextInt(speakerPool.length)].speaking = true;
        }
        // پیام‌های گفتگوی شبیه‌سازی‌شده
        if (_random.nextInt(3) == 0) {
          final others = _participants.where((p) => !p.isMe && !p.isHost).toList();
          if (others.isNotEmpty) {
            _messages.add(_ChatMessage(
              others[_random.nextInt(others.length)].name,
              _autoChatLines[_random.nextInt(_autoChatLines.length)],
            ));
            if (_panel != _SidePanel.chat) _unreadMessages++;
            _scrollChatToEnd();
          }
        }
      });
    });
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final seminarAsync = ref.watch(seminarByIdProvider(widget.seminarId));
    final user = ref.watch(authSessionProvider);

    return seminarAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF12100D),
        body: LoadingView(),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: e.toString()),
      ),
      data: (seminar) {
        if (user == null) return const SizedBox.shrink();
        final isHost = _isHostUser(user, seminar);

        // کنترل دسترسی: شاگرد/والد باید ثبت‌نام کرده و مخاطبِ سمینار باشد.
        final allowed = isHost ||
            user.role == AppUserRole.superAdmin ||
            ((user.role == AppUserRole.student
                    ? SeminarAudience.students
                    : user.role == AppUserRole.parent
                        ? SeminarAudience.parents
                        : seminar.audience) ==
                    seminar.audience &&
                seminar.isRegistered(user.id));
        if (!allowed) {
          return Scaffold(
            appBar: AppBar(title: Text(seminar.title)),
            body: ErrorView(message: context.tr('room.notAllowed')),
          );
        }

        if (seminar.hasEnded) {
          return _EndedView(title: seminar.title);
        }

        // پیش از شروع: شرکت‌کننده منتظر می‌ماند، میزبان می‌تواند شروع کند.
        if (!seminar.isLiveNow && seminar.status != SeminarStatus.live) {
          return _WaitingView(
            seminar: seminar,
            isHost: isHost,
            onStart: () async {
              await SeminarStore.instance.setStatus(seminar.id, SeminarStatus.live);
              ref.invalidate(seminarByIdProvider(widget.seminarId));
            },
          );
        }

        _initRoom(seminar, user, isHost);
        return _buildRoom(context, seminar, isHost);
      },
    );
  }

  Widget _buildRoom(BuildContext context, Seminar seminar, bool isHost) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 720;

    return Scaffold(
      backgroundColor: const Color(0xFF12100D),
      body: SafeArea(
        child: Stack(
          children: [
            // پس‌زمینهٔ گرادیانی ملایم
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1E1812),
                      const Color(0xFF12100D),
                      AppColors.orange700.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(context, seminar),
                      Expanded(child: _buildGrid(context, isWide)),
                      _buildControls(context, seminar, isHost),
                    ],
                  ),
                ),
                // پنل کناری (گفتگو / شرکت‌کنندگان) در صفحات عریض
                if (isWide && _panel != _SidePanel.none)
                  SizedBox(width: 320, child: _buildSidePanel(context)),
              ],
            ),
            // پنل روی صفحه در موبایل
            if (!isWide && _panel != _SidePanel.none)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _panel = _SidePanel.none),
                  child: Container(
                    color: Colors.black54,
                    alignment: AlignmentDirectional.centerEnd,
                    child: GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        width: min(340.0, width * 0.9),
                        child: _buildSidePanel(context),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Seminar seminar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // نشان زنده
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 500.ms)
                    .then()
                    .fadeOut(duration: 500.ms),
                const SizedBox(width: 6),
                Text(
                  context.tr('room.live'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seminar.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  seminar.instructorName,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 5),
                Text(
                  _formatElapsed(_elapsed),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontFeatures: []),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, bool isWide) {
    final crossAxisCount = isWide ? (_panel == _SidePanel.none ? 4 : 3) : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: _participants.length,
      itemBuilder: (context, i) {
        final p = _participants[i];
        final displayMic = p.isMe ? _micOn : p.micOn;
        final displayCam = p.isMe ? _cameraOn : p.cameraOn;
        final displayHand = p.isMe ? _handRaised : p.handRaised;
        return _ParticipantTile(
          participant: p,
          micOn: displayMic,
          cameraOn: displayCam,
          handRaised: displayHand,
          index: i,
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, Seminar seminar, bool isHost) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: context.tr('room.mic'),
              active: _micOn,
              onTap: () => setState(() => _micOn = !_micOn),
            ),
            _ControlButton(
              icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: context.tr('room.camera'),
              active: _cameraOn,
              onTap: () => setState(() => _cameraOn = !_cameraOn),
            ),
            if (!isHost)
              _ControlButton(
                icon: Icons.back_hand_rounded,
                label: context.tr('room.raiseHand'),
                active: _handRaised,
                activeColor: AppColors.gold500,
                onTap: () {
                  setState(() => _handRaised = !_handRaised);
                  if (_handRaised) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('room.handRaised')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            _ControlButton(
              icon: Icons.chat_bubble_rounded,
              label: context.tr('room.chat'),
              active: _panel == _SidePanel.chat,
              badgeCount: _unreadMessages,
              onTap: () => setState(() {
                _panel = _panel == _SidePanel.chat ? _SidePanel.none : _SidePanel.chat;
                if (_panel == _SidePanel.chat) _unreadMessages = 0;
              }),
            ),
            _ControlButton(
              icon: Icons.people_alt_rounded,
              label: context.tr('room.participants'),
              active: _panel == _SidePanel.participants,
              onTap: () => setState(() => _panel =
                  _panel == _SidePanel.participants ? _SidePanel.none : _SidePanel.participants),
            ),
            if (isHost) ...[
              _ControlButton(
                icon: Icons.mic_off_rounded,
                label: context.tr('room.muteAll'),
                onTap: () {
                  setState(() {
                    for (final p in _participants) {
                      if (!p.isHost && !p.isMe) p.micOn = false;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('room.mutedAll'))),
                  );
                },
              ),
              _ControlButton(
                icon: Icons.stop_circle_rounded,
                label: context.tr('room.endSeminar'),
                activeColor: AppColors.danger,
                active: true,
                onTap: () => _confirmEnd(context, seminar),
              ),
            ],
            const SizedBox(width: 6),
            // دکمهٔ خروج
            GestureDetector(
              onTap: () => _confirmLeave(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.call_end_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('room.leave'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final isChat = _panel == _SidePanel.chat;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF221C15),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isChat
                        ? context.tr('room.chat')
                        : '${context.tr('room.participants')} (${_participants.length})',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => setState(() => _panel = _SidePanel.none),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(child: isChat ? _buildChatList(context) : _buildParticipantList(context)),
          if (isChat) _buildChatInput(context),
        ],
      ),
    ).animate().slideX(begin: 0.15, end: 0, duration: 250.ms, curve: Curves.easeOutCubic).fadeIn();
  }

  Widget _buildChatList(BuildContext context) {
    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        return Align(
          alignment: m.isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 240),
            decoration: BoxDecoration(
              color: m.isMe
                  ? AppColors.orange600.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!m.isMe)
                  Text(
                    m.sender,
                    style: const TextStyle(
                        color: AppColors.gold300, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                Text(m.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: context.tr('room.sendMessage'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _participants.length,
      itemBuilder: (context, i) {
        final p = _participants[i];
        final micOn = p.isMe ? _micOn : p.micOn;
        final hand = p.isMe ? _handRaised : p.handRaised;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: _avatarColor(i),
            child: Text(
              p.name.isNotEmpty ? p.name.substring(0, 1) : '?',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          title: Text(
            p.isMe ? '${p.name} (${context.tr('room.you')})' : p.name,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          subtitle: p.isHost
              ? Text(context.tr('room.host'),
                  style: const TextStyle(color: AppColors.gold300, fontSize: 11))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hand)
                const Icon(Icons.back_hand_rounded, color: AppColors.gold500, size: 16),
              const SizedBox(width: 8),
              Icon(
                micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: micOn ? AppColors.green300 : Colors.white38,
                size: 16,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage('', text, isMe: true));
      _chatController.clear();
    });
    _scrollChatToEnd();
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('room.leave')),
        content: Text(context.tr('room.leaveConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('room.leave')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) context.pop();
  }

  Future<void> _confirmEnd(BuildContext context, Seminar seminar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('room.endSeminar')),
        content: Text(context.tr('room.endConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('room.endSeminar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SeminarStore.instance.setStatus(seminar.id, SeminarStatus.ended);
    ref.invalidate(seminarByIdProvider(widget.seminarId));
    ref.invalidate(upcomingSeminarsProvider);
    ref.invalidate(parentSeminarsProvider);
    if (context.mounted) context.pop();
  }

  static Color _avatarColor(int i) {
    const colors = [
      AppColors.orange500,
      AppColors.green500,
      AppColors.gold600,
      AppColors.info,
      AppColors.orange700,
      AppColors.green700,
    ];
    return colors[i % colors.length];
  }
}

/// دکمهٔ دایره‌ای نوار کنترل (میکروفن، دوربین، گفتگو و…).
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final int badgeCount;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppColors.green500) : Colors.white.withValues(alpha: 0.1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  if (badgeCount > 0)
                    PositionedDirectional(
                      top: -4,
                      end: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کاشی هر شرکت‌کننده — آواتار گرادیانی، هالهٔ «در حال صحبت»، وضعیت میکروفن.
class _ParticipantTile extends StatelessWidget {
  final _RoomParticipant participant;
  final bool micOn;
  final bool cameraOn;
  final bool handRaised;
  final int index;

  const _ParticipantTile({
    required this.participant,
    required this.micOn,
    required this.cameraOn,
    required this.handRaised,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final speaking = p.speaking;

    Widget tile = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF221C15),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: speaking
              ? AppColors.green300
              : (p.isHost ? AppColors.gold500.withValues(alpha: 0.5) : Colors.white12),
          width: speaking ? 2 : 1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: AppColors.green500.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: cameraOn
                ? _CameraOnPlaceholder(name: p.name, index: index)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: p.isHost
                              ? AppColors.heroGradientWarm
                              : AppColors.successGradient,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.name.isNotEmpty ? p.name.substring(0, 1) : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22),
                        ),
                      ),
                    ],
                  ),
          ),
          // نشان میزبان
          if (p.isHost)
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold500,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      context.tr('room.host'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          // دست بلندشده
          if (handRaised)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: const Icon(Icons.back_hand_rounded,
                      color: AppColors.gold500, size: 20)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -3, duration: 500.ms),
            ),
          // نام + میکروفن
          PositionedDirectional(
            bottom: 8,
            start: 8,
            end: 8,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      p.isMe ? '${p.name} (${context.tr('room.you')})' : p.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: micOn
                        ? AppColors.green500
                        : Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return tile
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 300.ms)
        .scaleXY(begin: 0.92, end: 1, delay: (index * 60).ms, duration: 300.ms);
  }
}

/// جایگزین تصویر دوربین (فاز ۱ بدون WebRTC واقعی).
class _CameraOnPlaceholder extends StatelessWidget {
  final String name;
  final int index;
  const _CameraOnPlaceholder({required this.name, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: index.isEven
              ? [AppColors.orange700.withValues(alpha: 0.5), const Color(0xFF221C15)]
              : [AppColors.green700.withValues(alpha: 0.5), const Color(0xFF221C15)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white30, size: 64),
      ),
    );
  }
}

/// نمای انتظار پیش از شروع جلسه — شمارش معکوس + دکمهٔ شروع برای میزبان.
class _WaitingView extends StatefulWidget {
  final Seminar seminar;
  final bool isHost;
  final Future<void> Function() onStart;
  const _WaitingView({required this.seminar, required this.isHost, required this.onStart});

  @override
  State<_WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<_WaitingView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _countdown() {
    final diff = widget.seminar.scheduledStart.difference(DateTime.now());
    if (diff.isNegative) return '00:00';
    final d = diff.inDays;
    final h = (diff.inHours % 24).toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return d > 0 ? '$d:$h:$m:$s' : '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12100D),
      body: SafeArea(
        child: Stack(
          children: [
            PositionedDirectional(
              top: 8,
              start: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                onPressed: () => context.pop(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradientWarm,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 44),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 1, end: 1.06, duration: 900.ms),
                    const SizedBox(height: 24),
                    Text(
                      widget.seminar.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.seminar.instructorName,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.tr('room.startsIn'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _countdown(),
                      style: const TextStyle(
                        color: AppColors.gold300,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (widget.isHost)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green500,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        onPressed: widget.onStart,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(context.tr('room.startNow')),
                      )
                    else
                      Text(
                        context.tr('room.waitingHost'),
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نمای پایان‌یافته.
class _EndedView extends StatelessWidget {
  final String title;
  const _EndedView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12100D),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.event_available_rounded, color: Colors.white54, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('seminars.ended'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(context.tr('common.back')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

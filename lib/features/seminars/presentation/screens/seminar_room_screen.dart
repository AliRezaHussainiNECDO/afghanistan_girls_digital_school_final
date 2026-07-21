import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared_models/seminar.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/usecases/seminars_usecases.dart';
import '../providers/seminars_providers.dart';

/// اتاق ویدیو کنفرانس زندهٔ سمینار — مسیر «فال‌بک»: وقتی نه پخش زندهٔ
/// Cloudflare Stream تنظیم شده و نه لینک جلسهٔ خارجی (Zoom/Meet/Jitsi)،
/// همین‌جا یک جلسهٔ صوتی/تصویری **واقعی** چندنفره از طریق Jitsi Meet SDK
/// برای این سمینار به‌طور خودکار ساخته و اجرا می‌شود — نه شبیه‌سازی.
///
/// دسترسی: استاد/مدیر میزبان (شروع، پایان جلسه برای همه) و شاگرد/والد
/// شرکت‌کننده (فقط پس از ثبت‌نام) — کنترل دسترسی و State Machine وضعیت
/// سمینار مثل قبل روی سرور/پایگاه‌داده انجام می‌شود (بخش ۱۲.۲ سند).
class SeminarRoomScreen extends ConsumerStatefulWidget {
  final String seminarId;
  const SeminarRoomScreen({super.key, required this.seminarId});

  @override
  ConsumerState<SeminarRoomScreen> createState() => _SeminarRoomScreenState();
}

class _SeminarRoomScreenState extends ConsumerState<SeminarRoomScreen> {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  bool _connecting = false;

  /// Jitsi Meet SDK فقط اندروید/iOS را پشتیبانی می‌کند — در وب/دسکتاپ باید
  /// پیام روشن نشان داد، نه شبیه‌سازی گمراه‌کننده. از `defaultTargetPlatform`
  /// (نه dart:io) استفاده می‌کنیم تا بیلد وب/ویندوز/مک هم بدون خطا کامپایل شود.
  bool get _jitsiSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String _roomNameFor(String seminarId) =>
      'agds${seminarId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';

  bool _isHostUser(AppUser? user, Seminar seminar) {
    if (user == null) return false;
    return user.role == AppUserRole.superAdmin ||
        (user.role == AppUserRole.seminarInstructor && user.id == seminar.instructorId);
  }

  Future<void> _joinCall(Seminar seminar, AppUser user, bool isHost) async {
    if (!_jitsiSupported) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('room.mobileOnlyShort')),
      ));
      return;
    }
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final options = JitsiMeetConferenceOptions(
        room: _roomNameFor(seminar.id),
        configOverrides: {
          'subject': seminar.title,
          'startWithAudioMuted': !isHost,
          'startWithVideoMuted': false,
        },
        featureFlags: {
          FeatureFlags.welcomePageEnabled: false,
          FeatureFlags.preJoinPageEnabled: true,
          // حریم خصوصی شاگردان دختر افغان در اولویت است: بدون دعوت افراد
          // بیرونی، بدون ضبط/پخش زندهٔ ثانویه روی سرور عمومی Jitsi.
          FeatureFlags.inviteEnabled: false,
          FeatureFlags.addPeopleEnabled: false,
          FeatureFlags.calenderEnabled: false,
          FeatureFlags.recordingEnabled: false,
          FeatureFlags.liveStreamingEnabled: false,
          FeatureFlags.meetingPasswordEnabled: false,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: user.displayName,
          email: user.email,
          avatar: user.avatarUrl,
        ),
      );
      final listener = JitsiMeetEventListener(
        readyToClose: () {
          if (!mounted) return;
          setState(() => _connecting = false);
          if (isHost) _promptEndAfterCall(seminar);
        },
        conferenceTerminated: (url, error) {
          if (!mounted) return;
          setState(() => _connecting = false);
        },
      );
      await _jitsiMeet.join(options, listener);
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('room.connectError', {'error': '$e'}))));
    }
  }

  /// پس از خروج میزبان از جلسهٔ Jitsi، از او می‌پرسیم آیا سمینار واقعاً برای
  /// همه پایان یابد یا فقط اتصال او قطع شده (تا دوباره بپیوندد).
  Future<void> _promptEndAfterCall(Seminar seminar) async {
    if (!mounted) return;
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(context.tr('room.endSeminar')),
          content: Text(context.tr('room.leftPromptEndAll')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('room.noJustDisconnected')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.tr('room.endSeminar')),
            ),
          ],
        ),
      ),
    );
    if (shouldEnd == true) await _endSeminar(seminar);
  }

  Future<void> _confirmEnd(BuildContext context, Seminar seminar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
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
      ),
    );
    if (confirmed != true) return;
    await _endSeminar(seminar);
  }

  Future<void> _endSeminar(Seminar seminar) async {
    if (!mounted) return;
    // پایان جلسه واقعاً روی سرور/پایگاه‌داده ثبت می‌شود تا شاگرد/والد روی
    // دستگاه‌های دیگر هم بلافاصله بفهمند سمینار تمام شده — نه فقط محلی.
    final result = await ref
        .read(setSeminarStatusUseCaseProvider)
        .call(SetSeminarStatusParams(seminarId: seminar.id, status: SeminarStatus.ended));
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(localizeSeminarFailureMessage(context, f.message)))),
      (_) {},
    );
    ref.invalidate(seminarByIdProvider(widget.seminarId));
    ref.invalidate(upcomingSeminarsProvider);
    ref.invalidate(parentSeminarsProvider);
    if (mounted && context.mounted) context.pop();
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
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
      ),
    );
    if (confirmed == true && context.mounted) context.pop();
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
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(seminarByIdProvider(widget.seminarId)),
        ),
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
              // وضعیت واقعاً روی سرور/پایگاه‌داده ثبت می‌شود (نه فقط محلی) تا
              // شاگرد/والد/سایر دستگاه‌ها هم بلافاصله «زنده» را ببینند.
              final result = await ref.read(setSeminarStatusUseCaseProvider).call(
                  SetSeminarStatusParams(seminarId: seminar.id, status: SeminarStatus.live));
              result.fold(
                (f) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizeSeminarFailureMessage(context, f.message))));
                  }
                },
                (_) {},
              );
              ref.invalidate(seminarByIdProvider(widget.seminarId));
            },
          );
        }

        return _LiveGateView(
          seminar: seminar,
          isHost: isHost,
          jitsiSupported: _jitsiSupported,
          connecting: _connecting,
          onJoin: () => _joinCall(seminar, user, isHost),
          onEnd: () => _confirmEnd(context, seminar),
          onLeave: () => _confirmLeave(context),
        );
      },
    );
  }
}

/// نمای «آمادهٔ پیوستن» — پیش از باز شدن رابط کاربری بومی Jitsi Meet (که
/// تمام صفحه را می‌گیرد و شامل شبکهٔ ویدیو، میکروفن/دوربین، گفتگو و
/// شرکت‌کنندگان واقعی می‌شود)، اینجا خلاصهٔ سمینار و دکمهٔ پیوستن نشان
/// داده می‌شود؛ برای میزبان دکمهٔ «پایان سمینار برای همه» هم در دسترس است.
class _LiveGateView extends StatelessWidget {
  final Seminar seminar;
  final bool isHost;
  final bool jitsiSupported;
  final bool connecting;
  final VoidCallback onJoin;
  final VoidCallback onEnd;
  final VoidCallback onLeave;

  const _LiveGateView({
    required this.seminar,
    required this.isHost,
    required this.jitsiSupported,
    required this.connecting,
    required this.onJoin,
    required this.onEnd,
    required this.onLeave,
  });

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
                onPressed: onLeave,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 24),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradientWarm,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 44),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 1, end: 1.06, duration: 900.ms),
                    const SizedBox(height: 24),
                    Text(
                      seminar.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      seminar.instructorName,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${seminar.registeredCount} ${context.tr('room.participants')}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    if (jitsiSupported)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green500,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md)),
                          ),
                          onPressed: connecting ? null : onJoin,
                          icon: connecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.videocam_rounded),
                          label: Text(
                            connecting ? context.tr('room.connecting') : context.tr('room.joinNow'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          context.tr('room.mobileOnlyLong'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.7),
                        ),
                      ),
                    if (isHost) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md)),
                          ),
                          onPressed: onEnd,
                          icon: const Icon(Icons.stop_circle_rounded, size: 18),
                          label: Text(context.tr('room.endSeminar')),
                        ),
                      ),
                    ],
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

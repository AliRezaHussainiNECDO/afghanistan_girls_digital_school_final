import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared_models/seminar.dart';
import '../providers/seminars_providers.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// صفحهٔ پخش زندهٔ سمینار — Cloudflare Stream (HLS) با پخش‌کنندهٔ Chewie.
///
/// شاگرد/والد این صفحه را باز می‌کند تا کلاس زنده را تماشا کند. Chewie روی
/// video_player سوار است و کنترل‌های حرفه‌ای (بافر، صدا، تمام‌صفحه، نشان LIVE)
/// را می‌دهد. اگر استاد هنوز پخش را شروع نکرده باشد، حالت «در انتظار شروع» با
/// انیمیشن نمایش داده می‌شود و صفحه هر چند ثانیه دوباره وضعیت را می‌گیرد.
/// ═══════════════════════════════════════════════════════════════════════════
class SeminarLivePlayerScreen extends ConsumerStatefulWidget {
  final String seminarId;
  const SeminarLivePlayerScreen({super.key, required this.seminarId});

  @override
  ConsumerState<SeminarLivePlayerScreen> createState() => _SeminarLivePlayerScreenState();
}

class _SeminarLivePlayerScreenState extends ConsumerState<SeminarLivePlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _activeUrl;
  bool _initializing = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // هر ۱۰ ثانیه وضعیت سمینار را دوباره می‌گیریم تا لحظهٔ شروعِ پخش را بگیریم.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(seminarByIdProvider(widget.seminarId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  /// راه‌اندازی پخش‌کننده برای نشانی جدید (فقط اگر تغییر کرده باشد).
  Future<void> _ensurePlayer(String url) async {
    if (url == _activeUrl || _initializing) return;
    _initializing = true;
    _activeUrl = url;
    _chewie?.dispose(); // ChewieController.dispose() خروجی void دارد (بدون await)
    await _video?.dispose();
    _chewie = null;
    final v = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = v;
    try {
      await v.initialize();
      _chewie = ChewieController(
        videoPlayerController: v,
        autoPlay: true,
        looping: false,
        isLive: true,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.orange500,
          handleColor: AppColors.orange400,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
        placeholder: const ColoredBox(color: Colors.black),
      );
      if (mounted) setState(() => _error = null);
    } catch (e) {
      // پخش زنده ممکن است چند ثانیه بعد از go-live آماده شود؛ اجازه بده poll دوباره تلاش کند.
      _activeUrl = null;
      if (mounted) setState(() => _error = context.tr('seminars.connectingLive'));
    } finally {
      _initializing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(seminarByIdProvider(widget.seminarId));
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: async.when(
        loading: () => const _StageBackground(child: _CenterSpinner()),
        error: (e, _) => _StageBackground(
          child: _MessageState(
            icon: Icons.error_outline_rounded,
            title: context.tr('seminars.loadError'),
            subtitle: '$e',
            onBack: () => context.pop(),
          ),
        ),
        data: (seminar) {
          if (seminar.hasLiveStream && !seminar.hasEnded) {
            _ensurePlayer(seminar.streamPlaybackUrl);
            return _buildLiveStage(seminar);
          }
          if (seminar.hasEnded) {
            return _StageBackground(
              child: _MessageState(
                icon: Icons.stop_circle_outlined,
                title: context.tr('seminars.hasEndedTitle'),
                subtitle: context.tr('seminars.recordingNotice'),
                onBack: () => context.pop(),
              ),
            );
          }
          return _StageBackground(child: _WaitingState(seminar: seminar, onBack: () => context.pop()));
        },
      ),
    );
  }

  Widget _buildLiveStage(Seminar seminar) {
    final ready = _chewie != null && (_video?.value.isInitialized ?? false);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          Center(child: Chewie(controller: _chewie!))
        else
          _StageBackground(
            child: _MessageState(
              icon: Icons.live_tv_rounded,
              title: _error ?? context.tr('seminars.connectingLive'),
              subtitle: context.tr('seminars.pleaseWaitMoment'),
              spinner: true,
            ),
          ),

        // نوار بالا (نشان LIVE + عنوان + بستن) — روی پخش‌کننده
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                const _LiveBadge(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seminar.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 6)]),
                      ),
                      if (seminar.instructorName.isNotEmpty)
                        Text(
                          context.tr('seminars.instructorPrefix', {'name': seminar.instructorName}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 6)]),
                        ),
                    ],
                  ),
                ),
                _RoundIconButton(icon: Icons.close_rounded, onTap: () => context.pop()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── اجزای بصری ────────────────────────────────

/// پس‌زمینهٔ سینمایی تیره با هالهٔ نارنجی — برای حالت‌های بدون ویدیو.
class _StageBackground extends StatelessWidget {
  final Widget child;
  const _StageBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.1,
          colors: [Color(0xFF241A12), Color(0xFF0B0B0F)],
        ),
      ),
      child: child,
    );
  }
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.orange400, strokeWidth: 2.5),
      );
}

/// نشان LIVE با نقطهٔ تپندهٔ قرمز.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.5), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ac,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          Text(context.tr('room.live'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// حالت پیام مرکزی (خطا/پایان/اتصال).
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool spinner;
  final VoidCallback? onBack;
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.spinner = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.orange400, size: 56),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.6)),
            if (spinner) ...[
              const SizedBox(height: 22),
              const CircularProgressIndicator(color: AppColors.orange400, strokeWidth: 2.5),
            ],
            if (onBack != null) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
                label: Text(context.tr('common.back'), style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالت انتظار — استاد هنوز پخش را شروع نکرده است.
class _WaitingState extends StatefulWidget {
  final Seminar seminar;
  final VoidCallback onBack;
  const _WaitingState({required this.seminar, required this.onBack});

  @override
  State<_WaitingState> createState() => _WaitingStateState();
}

class _WaitingStateState extends State<_WaitingState> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // حلقهٔ تپنده
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _ac,
                builder: (_, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Opacity(
                          opacity: (1 - ((_ac.value + i / 3) % 1)).clamp(0.0, 1.0) * 0.5,
                          child: Container(
                            width: 40 + ((_ac.value + i / 3) % 1) * 80,
                            height: 40 + ((_ac.value + i / 3) % 1) * 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.orange400, width: 2),
                            ),
                          ),
                        ),
                      child!,
                    ],
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.orange500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(widget.seminar.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(context.tr('seminars.waitingForInstructor'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text(context.tr('seminars.autoUpdateNotice'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 26),
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
              label: Text(context.tr('common.back'), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

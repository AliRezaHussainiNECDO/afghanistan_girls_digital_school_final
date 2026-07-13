import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/design_tokens.dart';
import '../providers/seminars_providers.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// پنل پخش زندهٔ کلاس — پخش مستقیم دوربین/میکروفون موبایل به Cloudflare Stream
/// از طریق RTMPS (پکیج apivideo_live_stream). مشترک بین استاد و مدیر ارشد.
///
/// ورودی‌های [rtmpsUrl] و [streamKey] از پاسخ go-live گرفته می‌شوند. کاربر فقط
/// دکمهٔ «شروع پخش» را می‌زند؛ نیازی به OBS یا نرم‌افزار جداگانه نیست.
/// ═══════════════════════════════════════════════════════════════════════════
class SeminarBroadcastScreen extends ConsumerStatefulWidget {
  final String seminarId;
  final String seminarTitle;
  final String rtmpsUrl;
  final String streamKey;

  const SeminarBroadcastScreen({
    super.key,
    required this.seminarId,
    required this.seminarTitle,
    required this.rtmpsUrl,
    required this.streamKey,
  });

  @override
  ConsumerState<SeminarBroadcastScreen> createState() => _SeminarBroadcastScreenState();
}

class _SeminarBroadcastScreenState extends ConsumerState<SeminarBroadcastScreen>
    with WidgetsBindingObserver {
  late final ApiVideoLiveStreamController _controller;
  bool _initialized = false;
  bool _isStreaming = false;
  bool _isMuted = false;
  bool _busy = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ApiVideoLiveStreamController(
      initialAudioConfig: AudioConfig(),
      initialVideoConfig: VideoConfig.withDefaultBitrate(),
      onConnectionSuccess: () {
        if (mounted) setState(() => _isStreaming = true);
      },
      onConnectionFailed: (error) {
        if (mounted) {
          setState(() => _isStreaming = false);
          _snack('اتصال پخش ناموفق بود: $error');
        }
      },
      onDisconnection: () {
        if (mounted) setState(() => _isStreaming = false);
      },
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() =>
            _permissionError = 'برای پخش زنده، دسترسی دوربین و میکروفون لازم است.');
      }
      return;
    }
    try {
      await _controller.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _permissionError = 'راه‌اندازی دوربین ناموفق بود: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (_initialized) _controller.startPreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleStream() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_isStreaming) {
        await _controller.stopStreaming();
        if (mounted) setState(() => _isStreaming = false);
      } else {
        await _controller.startStreaming(
          streamKey: widget.streamKey,
          url: widget.rtmpsUrl,
        );
        // وضعیت واقعی از callback onConnectionSuccess می‌آید.
      }
    } catch (e) {
      _snack('خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پایان کلاس زنده'),
        content: const Text('پخش زنده متوقف و کلاس پایان می‌یابد. مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پایان کلاس'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (_isStreaming) await _controller.stopStreaming();
      await ref.read(seminarLiveServiceProvider).endLive(widget.seminarId);
    } catch (_) {
      // حتی اگر end-live خطا داد، از صفحه خارج می‌شویم.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized)
            ApiVideoCameraPreview(controller: _controller, fit: BoxFit.cover)
          else
            _PrepView(
                error: _permissionError,
                onRetry: _bootstrap,
                onBack: () => Navigator.of(context).pop()),

          if (_initialized) ...[
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Color(0x00000000), Color(0x00000000), Color(0xE6000000)],
                    stops: [0.0, 0.2, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    _StatusPill(streaming: _isStreaming),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.seminarTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    _CircleBtn(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CircleBtn(
                            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            onTap: () async {
                              await _controller.toggleMute();
                              setState(() => _isMuted = !_isMuted);
                            },
                            big: true,
                          ),
                          GestureDetector(
                            onTap: _toggleStream,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isStreaming ? AppColors.danger : AppColors.green500,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isStreaming ? AppColors.danger : AppColors.green500)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(26),
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 3),
                                    )
                                  : Icon(
                                      _isStreaming ? Icons.stop_rounded : Icons.podcasts_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                            ),
                          ),
                          _CircleBtn(
                            icon: Icons.cameraswitch_rounded,
                            onTap: () => _controller.switchCamera(),
                            big: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isStreaming
                            ? 'در حال پخش زنده — شاگردان/والدین شما را می‌بینند'
                            : 'برای شروع پخش، دکمهٔ سبز را بزنید',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _endClass,
                          icon: const Icon(Icons.stop_circle_outlined, size: 18),
                          label: const Text('پایان کلاس زنده'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── اجزای بصری ────────────────────────────────

class _PrepView extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _PrepView({required this.error, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(error == null ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                color: AppColors.orange400, size: 56),
            const SizedBox(height: 18),
            Text(
              error ?? 'در حال آماده‌سازی دوربین…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            ),
            if (error == null) ...[
              const SizedBox(height: 22),
              const CircularProgressIndicator(color: AppColors.orange400, strokeWidth: 2.5),
            ] else ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تلاش دوباره'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onBack,
                child: const Text('بازگشت', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool streaming;
  const _StatusPill({required this.streaming});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: streaming ? AppColors.danger : Colors.white24,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(streaming ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(streaming ? 'زنده' : 'آماده',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool big;
  const _CircleBtn({required this.icon, required this.onTap, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white24,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(big ? 14 : 8),
          child: Icon(icon, color: Colors.white, size: big ? 26 : 20),
        ),
      ),
    );
  }
}

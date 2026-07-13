import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared_models/app_notification.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/advisor_store.dart';
import '../../domain/advisor_entities.dart';
import '../advisor_providers.dart';

/// «مشاور هوشمند» — یک مشاور دلسوز برای دختران افغانستان (روانی، اجتماعی،
/// خانوادگی، تحصیلی و روزمره). گفتگوها برای حمایت بهتر، قابل بازبینی مدیر است.
class AdvisorScreen extends ConsumerStatefulWidget {
  const AdvisorScreen({super.key});
  @override
  ConsumerState<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends ConsumerState<AdvisorScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  static const _suggestions = [
    'استرس امتحان دارم',
    'با خانواده‌ام مشکل دارم',
    'احساس تنهایی می‌کنم',
    'نمی‌توانم تمرکز کنم',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _studentId => ref.read(authSessionProvider)?.id ?? 'me';
  String get _studentName => ref.read(authSessionProvider)?.displayName ?? 'شاگرد';

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    final store = ref.read(advisorStoreProvider);
    final service = ref.read(advisorServiceProvider);
    _controller.clear();
    setState(() => _sending = true);

    store.add(studentId: _studentId, studentName: _studentName, role: AdvisorRole.student, text: text);
    _scrollToEnd();

    try {
      final history = store.messagesFor(_studentId);
      final reply = await service.reply(history: history, userText: text);
      store.add(
        studentId: _studentId,
        studentName: _studentName,
        role: AdvisorRole.advisor,
        text: reply.text,
        flagged: reply.flagged,
        topic: reply.topic,
      );
      if (reply.flagged) {
        // اطلاع به مدیر برای بازبینی و حمایت.
        NotificationCenter.instance.push(
          title: 'گفتگوی مشاور نیاز به توجه دارد 💙',
          body: '$_studentName پیامی حساس ارسال کرد — لطفاً در جزئیات شاگرد بازبینی شود.',
          kind: NotificationKind.safety,
          priority: NotificationPriority.high,
        );
      }
    } catch (_) {
      store.add(
        studentId: _studentId,
        studentName: _studentName,
        role: AdvisorRole.advisor,
        text: 'ببخشید، الان نتوانستم پاسخ بدهم. لطفاً دوباره تلاش کن. 🌸',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(advisorStoreProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'مشاور هوشمند',
      role: AppUserRole.student,
      body: Column(
        children: [
          _MonitoredNotice(),
          Expanded(
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final msgs = store.messagesFor(_studentId);
                if (msgs.isEmpty) return _intro(context);
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => _Bubble(msg: msgs[i])
                      .animate()
                      .fadeIn(duration: 220.ms)
                      .slideY(begin: 0.1),
                );
              },
            ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('مشاور در حال نوشتن…', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ]),
            ),
          _composer(context),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle, boxShadow: AppShadows.warm),
            child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 40),
          ),
        ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        Text('سلام عزیزم 🌸',
            textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: scheme.onSurface)),
        const SizedBox(height: 8),
        Text(
          'من مشاور تو هستم. می‌توانی دربارهٔ درس، احساسات، خانواده، دوستان یا هر چیزی که '
          'ذهنت را مشغول کرده با من صحبت کنی. اینجا جای امنی برای توست.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.7, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text('می‌توانی این‌طور شروع کنی:', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions
              .map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () => _send(s),
                    backgroundColor: scheme.surfaceContainerLowest,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'پیامت را بنویس…',
                  filled: true,
                  fillColor: scheme.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sending ? null : () => _send(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoredNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.gold600.withValues(alpha: 0.10),
      child: Row(children: [
        Icon(Icons.shield_moon_rounded, size: 16, color: AppColors.gold600),
        const SizedBox(width: 8),
        Expanded(
          child: Text('برای امنیت و حمایت بهتر تو، این گفتگوها ممکن است توسط مدیریت مکتب بازبینی شود.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final AdvisorMessage msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStudent = msg.role == AdvisorRole.student;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isStudent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isStudent) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
              child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isStudent ? scheme.primary : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadii.lg),
                  topRight: const Radius.circular(AppRadii.lg),
                  bottomLeft: Radius.circular(isStudent ? AppRadii.lg : AppRadii.xs),
                  bottomRight: Radius.circular(isStudent ? AppRadii.xs : AppRadii.lg),
                ),
                border: isStudent ? null : Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  height: 1.6,
                  color: isStudent ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

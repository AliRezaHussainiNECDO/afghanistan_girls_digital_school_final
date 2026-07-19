import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../providers/audit_logs_providers.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// «مرکز عملیات سیستم و مانیتورینگ AI» — صفحهٔ لاگ بازبینی مدیر (بخش ۲۰.۳).
///
///   • تم Cinema Dark (#0F172A / #1E293B) با لهجه‌های شیشه‌ای (Glassmorphism).
///   • چیپ‌های فیلتر سریع + جستجوی زندهٔ بدون تأخیر (کاملاً محلی).
///   • لیست/جدول واکنش‌گرا (موبایل/تبلت/وب) با نقطه‌های نئونی وضعیت.
///   • «بازرس Prompt»: مودال عمیق برای رویدادهای AI — پنجرهٔ RAG Context +
///     جریان گفتگو به‌شکل حباب چت؛ برای رویدادهای امنیتی «نقشهٔ بردار امنیتی».
///   • Riverpod برای وضعیت، فیلترها و صفحه‌بندی (Infinite Scroll).
/// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────── پالت سینمایی ─────────────────────────────────
class _Cine {
  static const bg = Color(0xFF0F172A); // Slate-900
  static const surface = Color(0xFF1E293B); // Slate-800
  static const surfaceHi = Color(0xFF273449);
  static const codeBg = Color(0xFF0B1220);
  static const border = Color(0x1FFFFFFF); // شیشه‌ای
  static const text = Color(0xFFE2E8F0);
  static const textDim = Color(0xFF94A3B8);
  static const indigo = Color(0xFF818CF8);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);
}

// ─────────────────────── برچسب/آیکون/رنگ هر نوع رویداد ──────────────────────
String _actionLabel(BuildContext context, String t) {
  switch (t) {
    case 'ai_invocation':
      return context.tr('auditLogs.actionAiInvocation');
    case 'login_success':
      return context.tr('auditLogs.actionLoginSuccess');
    case 'login_failed':
      return context.tr('auditLogs.actionLoginFailed');
    case 'login_blocked':
      return context.tr('auditLogs.actionLoginBlocked');
    case 'logout':
      return context.tr('auditLogs.actionLogout');
    case 'user_register':
      return context.tr('auditLogs.actionUserRegister');
    case 'user_status_change':
      return context.tr('auditLogs.actionUserStatusChange');
    case 'invite_code_issue':
      return context.tr('auditLogs.actionInviteCodeIssue');
    case 'invite_code_revoke':
      return context.tr('auditLogs.actionInviteCodeRevoke');
    case 'password_reset_link':
      return context.tr('auditLogs.actionPasswordResetLink');
    case 'content_status_change':
      return context.tr('auditLogs.actionContentStatusChange');
    case 'content_delete':
      return context.tr('auditLogs.actionContentDelete');
    case 'curriculum_wipe':
      return context.tr('auditLogs.actionCurriculumWipe');
    case 'safety_resolve':
      return context.tr('auditLogs.actionSafetyResolve');
    case 'parent_link_request':
      return context.tr('auditLogs.actionParentLinkRequest');
    case 'parent_link_decision':
      return context.tr('auditLogs.actionParentLinkDecision');
    case 'certificate_issue':
      return context.tr('auditLogs.actionCertificateIssue');
    case 'certificate_revoke':
      return context.tr('auditLogs.actionCertificateRevoke');
    case 'exam_delete':
      return context.tr('auditLogs.actionExamDelete');
    default:
      return t;
  }
}

IconData _actionIcon(String t) {
  switch (t) {
    case 'ai_invocation':
      return Icons.smart_toy_rounded;
    case 'login_success':
      return Icons.login_rounded;
    case 'login_failed':
    case 'login_blocked':
      return Icons.gpp_bad_rounded;
    case 'logout':
      return Icons.logout_rounded;
    case 'user_register':
      return Icons.person_add_alt_1_rounded;
    case 'user_status_change':
      return Icons.manage_accounts_rounded;
    case 'invite_code_issue':
    case 'invite_code_revoke':
      return Icons.qr_code_2_rounded;
    case 'password_reset_link':
      return Icons.lock_reset_rounded;
    case 'content_status_change':
      return Icons.publish_rounded;
    case 'content_delete':
      return Icons.delete_forever_rounded;
    case 'curriculum_wipe':
      return Icons.local_fire_department_rounded;
    case 'safety_resolve':
      return Icons.shield_rounded;
    case 'parent_link_request':
    case 'parent_link_decision':
      return Icons.family_restroom_rounded;
    case 'certificate_issue':
      return Icons.workspace_premium_rounded;
    case 'certificate_revoke':
      return Icons.remove_moderator_rounded;
    case 'exam_delete':
      return Icons.delete_sweep_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

/// رنگ نقطهٔ نئونی وضعیت: سبز=عادی/موفق، کهربایی=حساس، قرمز=امنیتی/بحرانی.
Color _statusColor(AuditLogEntry e) {
  if (e.isHighPriority || e.category == AuditCategory.security) return _Cine.red;
  if (e.category == AuditCategory.sensitive) return _Cine.amber;
  if (e.actionType == 'ai_invocation' && e.aiOutcome == 'upstream_error') {
    return _Cine.amber;
  }
  return _Cine.green;
}

String _roleLabel(BuildContext context, String? role) {
  switch (role) {
    case 'super_admin':
      return context.tr('auditLogs.roleSuperAdmin');
    case 'student':
      return context.tr('auditLogs.roleStudent');
    case 'parent':
      return context.tr('auditLogs.roleParent');
    case 'seminar_instructor':
      return context.tr('auditLogs.roleInstructor');
    case null:
      return context.tr('auditLogs.roleSystemUnknown');
    default:
      return role;
  }
}

String _fmtTime(DateTime? d) {
  if (d == null) return '—';
  return intl.DateFormat('yyyy/MM/dd — HH:mm:ss').format(d);
}

String _prettyJson(Map<String, dynamic>? m) {
  if (m == null || m.isEmpty) return '—';
  try {
    return const JsonEncoder.withIndent('  ').convert(m);
  } catch (_) {
    return m.toString();
  }
}

// ═════════════════════════════════ صفحه ═════════════════════════════════════
class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Infinite scroll: نزدیک انتهای لیست → صفحهٔ بعد.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(auditLogsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditLogsProvider);
    final visible = ref.watch(visibleAuditLogsProvider);
    final filter = ref.watch(auditFilterProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return AppScaffold(
      title: context.tr('admin.auditLogs'),
      role: AppUserRole.superAdmin,
      actions: [
        IconButton(
          tooltip: context.tr('auditLogs.refreshTooltip'),
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.read(auditLogsProvider.notifier).refresh(),
        ),
      ],
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Cine.bg, Color(0xFF111C33), _Cine.bg],
          ),
        ),
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _Cine.cyan),
          ),
          error: (e, _) => _ErrorPanel(
            message: e.toString(),
            onRetry: () => ref.read(auditLogsProvider.notifier).refresh(),
          ),
          data: (state) => Column(
            children: [
              _HeaderPanel(allLogs: state.logs),
              _FilterBar(filter: filter),
              const SizedBox(height: 4),
              Expanded(
                child: visible.isEmpty
                    ? const _EmptyPanel()
                    : RefreshIndicator(
                        color: _Cine.cyan,
                        backgroundColor: _Cine.surface,
                        onRefresh: () => ref.read(auditLogsProvider.notifier).refresh(),
                        child: ListView.builder(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: visible.length + (state.loadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= visible.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _Cine.cyan),
                                  ),
                                ),
                              );
                            }
                            final e = visible[i];
                            return _LogRow(
                              entry: e,
                              wide: isWide,
                              onInspect: () => _openInspector(context, e),
                            )
                                .animate()
                                .fadeIn(duration: 220.ms, delay: (i < 12 ? i * 30 : 0).ms)
                                .slideY(begin: 0.06, end: 0);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInspector(BuildContext context, AuditLogEntry e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _InspectorSheet(entry: e),
    );
  }
}

// ─────────────────────────── هدر آماری (Command Center) ─────────────────────
class _HeaderPanel extends StatelessWidget {
  final List<AuditLogEntry> allLogs;
  const _HeaderPanel({required this.allLogs});

  @override
  Widget build(BuildContext context) {
    final ai = allLogs.where((e) => e.category == AuditCategory.ai).length;
    final sec = allLogs.where((e) => e.category == AuditCategory.security).length;
    final high = allLogs.where((e) => e.isHighPriority).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatChip(
              icon: Icons.receipt_long_rounded,
              label: context.tr('auditLogs.totalEventsLabel'),
              value: '${allLogs.length}',
              color: _Cine.cyan),
          _StatChip(
              icon: Icons.smart_toy_rounded,
              label: context.tr('auditLogs.aiInvocationsLabel'),
              value: '$ai',
              color: _Cine.indigo),
          _StatChip(
              icon: Icons.gpp_bad_rounded,
              label: context.tr('auditLogs.securityAlertsLabel'),
              value: '$sec',
              color: _Cine.red),
          _StatChip(
              icon: Icons.priority_high_rounded,
              label: context.tr('auditLogs.highPriorityLabel'),
              value: '$high',
              color: _Cine.amber),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _Cine.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Cine.border),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _Cine.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────── نوار فیلتر سریع + جستجوی زنده ──────────────────────
class _FilterBar extends ConsumerWidget {
  final AuditCategory? filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(String label, IconData icon, AuditCategory? value, Color color) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => ref.read(auditFilterProvider.notifier).state = value,
          avatar: Icon(icon, size: 16, color: selected ? Colors.black : color),
          label: Text(label),
          labelStyle: TextStyle(
            color: selected ? Colors.black : _Cine.text,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          selectedColor: color,
          backgroundColor: _Cine.surface.withValues(alpha: 0.7),
          side: BorderSide(color: selected ? color : _Cine.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          // جستجوی زنده — کاملاً محلی، بدون درخواست سرور، بدون لگ.
          TextField(
            onChanged: (v) => ref.read(auditSearchProvider.notifier).state = v,
            style: const TextStyle(color: _Cine.text, fontSize: 14),
            cursorColor: _Cine.cyan,
            decoration: InputDecoration(
              hintText: context.tr('auditLogs.searchHint'),
              hintStyle: const TextStyle(color: _Cine.textDim, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _Cine.textDim),
              filled: true,
              fillColor: _Cine.surface.withValues(alpha: 0.7),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _Cine.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _Cine.cyan),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(context.tr('auditLogs.filterAll'), Icons.all_inclusive_rounded, null, _Cine.cyan),
                chip(context.tr('auditLogs.filterAiChats'), Icons.smart_toy_rounded, AuditCategory.ai,
                    _Cine.indigo),
                chip(context.tr('auditLogs.filterSecurityAlerts'), Icons.gpp_bad_rounded, AuditCategory.security,
                    _Cine.red),
                chip(context.tr('auditLogs.filterSensitiveActions'), Icons.admin_panel_settings_rounded,
                    AuditCategory.sensitive, _Cine.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── ردیف لاگ ───────────────────────────────────
class _LogRow extends StatefulWidget {
  final AuditLogEntry entry;
  final bool wide;
  final VoidCallback onInspect;
  const _LogRow({required this.entry, required this.wide, required this.onInspect});

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final status = _statusColor(e);

    final iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [status.withValues(alpha: 0.25), _Cine.surfaceHi],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: status.withValues(alpha: 0.35)),
      ),
      child: Icon(_actionIcon(e.actionType), color: status, size: 21),
    );

    final neonDot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status,
        boxShadow: [
          BoxShadow(color: status.withValues(alpha: 0.8), blurRadius: 8, spreadRadius: 1),
        ],
      ),
    );

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        neonDot,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _actionLabel(context, e.actionType),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _Cine.text, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        if (e.isHighPriority) ...[
          const SizedBox(width: 8),
          _Badge(text: context.tr('auditLogs.criticalBadge'), color: _Cine.red),
        ],
      ],
    );

    final roleBadge = _Badge(
      text: _roleLabel(context, e.actorRole),
      color: e.actorRole == 'super_admin' ? _Cine.amber : _Cine.cyan,
    );

    final time = Text(_fmtTime(e.createdAt),
        style: const TextStyle(color: _Cine.textDim, fontSize: 12));

    final ip = Text(
      e.ipAddress ?? '—',
      textDirection: TextDirection.ltr,
      style: const TextStyle(
          color: _Cine.textDim, fontSize: 12, fontFamily: 'monospace'),
    );

    final inspectBtn = IconButton(
      tooltip: context.tr('auditLogs.inspectTooltip'),
      onPressed: widget.onInspect,
      icon: Icon(
        e.category == AuditCategory.ai
            ? Icons.manage_search_rounded
            : Icons.open_in_full_rounded,
        color: _hover ? _Cine.cyan : _Cine.textDim,
        size: 20,
      ),
    );

    final content = widget.wide
        // نمای جدول (وب/تبلت): ستون‌های هم‌تراز.
        ? Row(
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(flex: 3, child: title),
              Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: roleBadge)),
              Expanded(flex: 2, child: time),
              Expanded(flex: 2, child: ip),
              inspectBtn,
            ],
          )
        // نمای کارت (موبایل).
        : Row(
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [roleBadge, time, ip],
                    ),
                  ],
                ),
              ),
              inspectBtn,
            ],
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onInspect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? _Cine.surfaceHi.withValues(alpha: 0.95)
                : _Cine.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hover ? _Cine.cyan.withValues(alpha: 0.35) : _Cine.border),
            boxShadow: _hover
                ? [
                    BoxShadow(
                        color: _Cine.cyan.withValues(alpha: 0.10),
                        blurRadius: 18,
                        spreadRadius: 1),
                  ]
                : const [],
          ),
          child: content,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ═══════════════════════ «بازرس Prompt» — مودال عمیق ═══════════════════════
class _InspectorSheet extends StatelessWidget {
  final AuditLogEntry entry;
  const _InspectorSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: _Cine.bg.withValues(alpha: 0.96),
              border: const Border(top: BorderSide(color: _Cine.border)),
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _Cine.textDim.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                _inspectorHeader(context),
                const SizedBox(height: 16),
                if (entry.category == AuditCategory.ai)
                  ..._aiInspector(context)
                else if (entry.category == AuditCategory.security)
                  ..._securityVectorMap(context)
                else
                  ..._genericInspector(context),
                const SizedBox(height: 20),
                _MetaGrid(entry: entry),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inspectorHeader(BuildContext context) {
    final status = _statusColor(entry);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [status.withValues(alpha: 0.3), _Cine.surfaceHi],
            ),
            border: Border.all(color: status.withValues(alpha: 0.4)),
          ),
          child: Icon(_actionIcon(entry.actionType), color: status, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_actionLabel(context, entry.actionType),
                  style: const TextStyle(
                      color: _Cine.text, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(_fmtTime(entry.createdAt),
                  style: const TextStyle(color: _Cine.textDim, fontSize: 12)),
            ],
          ),
        ),
        _Badge(text: _roleLabel(context, entry.actorRole), color: _Cine.cyan),
      ],
    );
  }

  // ─────────────── نمای AI: پنجرهٔ RAG + جریان گفتگو ────────────────
  List<Widget> _aiInspector(BuildContext context) {
    final rag = entry.ragContext;
    final convo = entry.conversation;
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (entry.aiModel != null)
            _Badge(text: context.tr('auditLogs.modelBadge', {'model': '${entry.aiModel}'}), color: _Cine.indigo),
          if (entry.subjectId != null)
            _Badge(text: context.tr('auditLogs.subjectBadge', {'subject': '${entry.subjectId}'}), color: _Cine.cyan),
          _Badge(
            text: entry.aiOutcome == 'ok' ? context.tr('auditLogs.outcomeOk') : context.tr('auditLogs.outcomeError'),
            color: entry.aiOutcome == 'ok' ? _Cine.green : _Cine.amber,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SectionTitle(
          icon: Icons.menu_book_rounded,
          title: context.tr('auditLogs.ragContextTitle')),
      const SizedBox(height: 8),
      if (rag.isEmpty)
        _DimNote(context.tr('auditLogs.noRagContext'))
      else
        ...rag.map((m) => _CodePanel(text: m.content)),
      const SizedBox(height: 18),
      _SectionTitle(
          icon: Icons.forum_rounded, title: context.tr('auditLogs.conversationFlowTitle')),
      const SizedBox(height: 8),
      if (convo.isEmpty)
        _DimNote(context.tr('auditLogs.noConversationMessages'))
      else
        ...convo.map((m) => _ChatBubble(message: m)),
      if (entry.replyPreview != null && entry.replyPreview!.isNotEmpty) ...[
        const SizedBox(height: 6),
        _ChatBubble(
          message: AuditPromptMessage(
              role: 'assistant', content: entry.replyPreview!),
          isReplyPreview: true,
        ),
      ],
    ];
  }

  // ─────────────── نمای امنیتی: «نقشهٔ بردار امنیتی» ────────────────
  List<Widget> _securityVectorMap(BuildContext context) {
    return [
      _SectionTitle(icon: Icons.gpp_bad_rounded, title: context.tr('auditLogs.securityVectorMapTitle')),
      const SizedBox(height: 10),
      _VectorTile(
        icon: Icons.public_rounded,
        label: context.tr('auditLogs.sourceIpLabel'),
        value: entry.ipAddress ?? context.tr('auditLogs.unknownValue'),
        color: _Cine.red,
        ltr: true,
      ),
      _VectorTile(
        icon: Icons.alternate_email_rounded,
        label: context.tr('auditLogs.attemptedEmailLabel'),
        value: entry.attemptedEmail ?? '—',
        color: _Cine.amber,
        ltr: true,
      ),
      _VectorTile(
        icon: Icons.block_rounded,
        label: context.tr('auditLogs.reasonLabel'),
        value: entry.actionType == 'login_blocked'
            ? context.tr('auditLogs.accountBlockedReason', {'status': '${entry.detail?['status'] ?? '—'}'})
            : context.tr('auditLogs.wrongCredentialsReason'),
        color: _Cine.red,
      ),
      _VectorTile(
        icon: Icons.speed_rounded,
        label: context.tr('auditLogs.rateLimitStatusLabel'),
        value: context.tr('auditLogs.rateLimitNotActive'),
        color: _Cine.textDim,
      ),
      _VectorTile(
        icon: Icons.fingerprint_rounded,
        label: context.tr('auditLogs.targetUserLabel'),
        value: entry.targetId ?? context.tr('auditLogs.unknownTargetUser'),
        color: _Cine.cyan,
        ltr: entry.targetId != null,
      ),
    ];
  }

  // ─────────────── نمای عمومی: قبل/بعد/جزئیات ────────────────
  List<Widget> _genericInspector(BuildContext context) {
    return [
      if (entry.reason != null && entry.reason!.isNotEmpty) ...[
        _SectionTitle(icon: Icons.notes_rounded, title: context.tr('auditLogs.recordedReasonTitle')),
        const SizedBox(height: 8),
        _CodePanel(text: entry.reason!),
        const SizedBox(height: 14),
      ],
      if (entry.beforeValue != null) ...[
        _SectionTitle(icon: Icons.history_rounded, title: context.tr('auditLogs.beforeStateTitle')),
        const SizedBox(height: 8),
        _CodePanel(text: _prettyJson(entry.beforeValue), ltr: true),
        const SizedBox(height: 14),
      ],
      if (entry.afterValue != null) ...[
        _SectionTitle(icon: Icons.update_rounded, title: context.tr('auditLogs.afterStateTitle')),
        const SizedBox(height: 8),
        _CodePanel(text: _prettyJson(entry.afterValue), ltr: true),
        const SizedBox(height: 14),
      ],
      if (entry.detail != null) ...[
        _SectionTitle(icon: Icons.data_object_rounded, title: context.tr('auditLogs.payloadDetailsTitle')),
        const SizedBox(height: 8),
        _CodePanel(text: _prettyJson(entry.detail), ltr: true),
      ],
      if (entry.reason == null &&
          entry.beforeValue == null &&
          entry.afterValue == null &&
          entry.detail == null)
        _DimNote(context.tr('auditLogs.noExtraPayload')),
    ];
  }
}

// ───────────────────────── اجزای کوچک بازرس ─────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _Cine.cyan),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: _Cine.text, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ],
    );
  }
}

class _DimNote extends StatelessWidget {
  final String text;
  const _DimNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: const TextStyle(color: _Cine.textDim, fontSize: 13)),
    );
  }
}

/// ظرف «شبه‌کد» تاریک برای RAG Context و JSON — با اسکرول افقی امن.
class _CodePanel extends StatelessWidget {
  final String text;
  final bool ltr;
  const _CodePanel({required this.text, this.ltr = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Cine.codeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Cine.indigo.withValues(alpha: 0.25)),
      ),
      child: SelectableText(
        text,
        textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
        style: const TextStyle(
          color: Color(0xFFA5B4FC),
          fontSize: 12.5,
          height: 1.7,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// حباب چت برای «جریان گفتگو» — شاگرد و معلم هوشمند با استایل متمایز.
class _ChatBubble extends StatelessWidget {
  final AuditPromptMessage message;
  final bool isReplyPreview;
  const _ChatBubble({required this.message, this.isReplyPreview = false});

  @override
  Widget build(BuildContext context) {
    final isStudent = message.role == 'user';
    final color = isStudent ? _Cine.cyan : _Cine.indigo;
    return Align(
      alignment: isStudent
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(isStudent ? 4 : 16),
            bottomEnd: Radius.circular(isStudent ? 16 : 4),
          ),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isStudent ? Icons.face_rounded : Icons.smart_toy_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  isStudent
                      ? context.tr('auditLogs.studentRole')
                      : (isReplyPreview ? context.tr('auditLogs.aiReplyPreviewRole') : context.tr('auditLogs.aiTeacherRole')),
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              message.content,
              style: const TextStyle(color: _Cine.text, fontSize: 13.5, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _VectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool ltr;
  const _VectorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.ltr = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _Cine.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: _Cine.textDim, fontSize: 11.5)),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
                  style: const TextStyle(
                      color: _Cine.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شبکهٔ متادیتای انتهای بازرس — شناسه‌ها برای پیگیری/ارجاع.
class _MetaGrid extends StatelessWidget {
  final AuditLogEntry entry;
  const _MetaGrid({required this.entry});

  @override
  Widget build(BuildContext context) {
    Widget cell(String k, String? v, {bool ltr = true}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(k,
                    style: const TextStyle(color: _Cine.textDim, fontSize: 12)),
              ),
              Expanded(
                child: SelectableText(
                  v ?? '—',
                  textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
                  style: const TextStyle(
                      color: _Cine.text, fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Cine.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Cine.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('auditLogs.referenceIdsTitle'),
              style: const TextStyle(
                  color: _Cine.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          cell('Log ID', entry.id),
          cell('Actor ID', entry.actorId),
          cell('Target', entry.targetTable == null
              ? entry.targetId
              : '${entry.targetTable} / ${entry.targetId ?? '—'}'),
          cell('IP', entry.ipAddress),
          cell('Priority', entry.priority),
        ],
      ),
    );
  }
}

// ─────────────────────────── حالت‌های خالی/خطا ──────────────────────────────
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radar_rounded,
              size: 56, color: _Cine.textDim.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(context.tr('auditLogs.noMatchingEvents'),
              style: const TextStyle(color: _Cine.textDim, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52, color: _Cine.red),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _Cine.textDim, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: _Cine.cyan, foregroundColor: Colors.black),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

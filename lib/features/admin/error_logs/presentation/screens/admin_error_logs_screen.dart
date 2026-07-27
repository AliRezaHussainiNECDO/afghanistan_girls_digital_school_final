import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/error_log_entry.dart';
import '../providers/error_logs_providers.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// «گزارش خطاهای برنامه» — صفحهٔ لاگ خطای مدیر (Migration 0046).
///
/// هر بار بخشی از اپ یا سرور دچار مشکل شود (کرش فلاتر، خطای مدیریت‌نشدهٔ
/// Worker، یا هر try/catch دستی که صریحاً گزارش می‌دهد)، یک ردیف اینجا ظاهر
/// می‌شود: کد خطا، دسته‌بندی، شدت، پیام کامل + Stack trace، و تاریخ/روز/ساعت
/// دقیق وقوع. دکمهٔ 🤖 روی هر رکورد یک گزارش تمیز و ساختاریافته در
/// کلیپ‌بورد کپی می‌کند — آمادهٔ پیست مستقیم در گفتگو با Claude برای تشخیص
/// سریع مشکل.
///
/// همان پالت «سینمای تیره» صفحهٔ لاگ بازبینی (audit_logs) برای هم‌سویی
/// بصری در «مرکز عملیات» پنل مدیر.
/// ═══════════════════════════════════════════════════════════════════════════

class _Cine {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceHi = Color(0xFF273449);
  static const codeBg = Color(0xFF0B1220);
  static const border = Color(0x1FFFFFFF);
  static const text = Color(0xFFE2E8F0);
  static const textDim = Color(0xFF94A3B8);
  static const indigo = Color(0xFF818CF8);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);
}

Color _severityColor(ErrorSeverity s) {
  switch (s) {
    case ErrorSeverity.critical:
      return _Cine.red;
    case ErrorSeverity.high:
      return const Color(0xFFFB923C);
    case ErrorSeverity.medium:
      return _Cine.amber;
    case ErrorSeverity.low:
      return _Cine.textDim;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'AUTH':
      return Icons.gpp_bad_rounded;
    case 'DATABASE':
      return Icons.storage_rounded;
    case 'API':
    case 'NETWORK':
      return Icons.cloud_off_rounded;
    case 'UI':
      return Icons.phonelink_erase_rounded;
    case 'VALIDATION':
      return Icons.rule_rounded;
    default:
      return Icons.bug_report_rounded;
  }
}

String _categoryLabel(BuildContext context, String category) {
  switch (category) {
    case 'AUTH':
      return context.tr('errorLogs.categoryAuth');
    case 'DATABASE':
      return context.tr('errorLogs.categoryDatabase');
    case 'API':
      return context.tr('errorLogs.categoryApi');
    case 'UI':
      return context.tr('errorLogs.categoryUi');
    case 'VALIDATION':
      return context.tr('errorLogs.categoryValidation');
    case 'NETWORK':
      return context.tr('errorLogs.categoryNetwork');
    default:
      return context.tr('errorLogs.categoryUnknown');
  }
}

String _statusLabel(BuildContext context, ErrorLogStatus s) {
  switch (s) {
    case ErrorLogStatus.investigating:
      return context.tr('errorLogs.statusInvestigating');
    case ErrorLogStatus.resolved:
      return context.tr('errorLogs.statusResolved');
    case ErrorLogStatus.ignored:
      return context.tr('errorLogs.statusIgnored');
    case ErrorLogStatus.newIssue:
      return context.tr('errorLogs.statusNew');
  }
}

String _fmtOccurred(ErrorLogEntry e) => '${e.occurredDate} (${e.occurredDayOfWeek}) ${e.occurredTime}';

// ═════════════════════════════════ صفحه ═════════════════════════════════════
class AdminErrorLogsScreen extends ConsumerStatefulWidget {
  const AdminErrorLogsScreen({super.key});

  @override
  ConsumerState<AdminErrorLogsScreen> createState() => _AdminErrorLogsScreenState();
}

class _AdminErrorLogsScreenState extends ConsumerState<AdminErrorLogsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(errorLogsProvider);
    final filter = ref.watch(errorLogsFilterProvider);

    return AppScaffold(
      title: context.tr('admin.errorLogs'),
      role: ref.watch(authSessionProvider)?.role ?? AppUserRole.superAdmin,
      actions: [
        IconButton(
          tooltip: context.tr('errorLogs.refreshTooltip'),
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(errorLogsProvider),
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
        child: Column(
          children: [
            _FilterBar(
              filter: filter,
              searchController: _searchController,
              onStatusChanged: (v) => ref.read(errorLogsFilterProvider.notifier).state =
                  filter.copyWith(status: v, clearStatus: v == null, page: 1),
              onSeverityChanged: (v) => ref.read(errorLogsFilterProvider.notifier).state =
                  filter.copyWith(severity: v, clearSeverity: v == null, page: 1),
              onSearchSubmitted: (v) =>
                  ref.read(errorLogsFilterProvider.notifier).state = filter.copyWith(query: v, page: 1),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _Cine.cyan)),
                error: (e, _) => _ErrorPanel(message: '$e', onRetry: () => ref.invalidate(errorLogsProvider)),
                data: (data) {
                  if (data.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 56, color: _Cine.textDim.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          Text(context.tr('errorLogs.noMatching'), style: const TextStyle(color: _Cine.textDim, fontSize: 14)),
                        ],
                      ),
                    );
                  }
                  final totalPages = (data.total / data.pageSize).ceil().clamp(1, 999999);
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                          itemCount: data.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _ErrorRow(entry: data.items[i])
                              .animate()
                              .fadeIn(duration: 200.ms, delay: (i < 12 ? i * 25 : 0).ms)
                              .slideY(begin: 0.05, end: 0),
                        ),
                      ),
                      _Pager(
                        page: data.page,
                        totalPages: totalPages,
                        total: data.total,
                        onPrev: data.page > 1
                            ? () => ref.read(errorLogsFilterProvider.notifier).state = filter.copyWith(page: data.page - 1)
                            : null,
                        onNext: data.page < totalPages
                            ? () => ref.read(errorLogsFilterProvider.notifier).state = filter.copyWith(page: data.page + 1)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── نوار فیلتر + جستجو ──────────────────────────────────
class _FilterBar extends StatelessWidget {
  final ErrorLogsFilter filter;
  final TextEditingController searchController;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSeverityChanged;
  final ValueChanged<String> onSearchSubmitted;

  const _FilterBar({
    required this.filter,
    required this.searchController,
    required this.onStatusChanged,
    required this.onSeverityChanged,
    required this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    Widget statusChip(String label, String? value) {
      final selected = filter.status == value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => onStatusChanged(value),
          label: Text(label),
          labelStyle: TextStyle(color: selected ? Colors.black : _Cine.text, fontWeight: FontWeight.w600, fontSize: 12.5),
          selectedColor: _Cine.cyan,
          backgroundColor: _Cine.surface.withValues(alpha: 0.7),
          side: BorderSide(color: selected ? _Cine.cyan : _Cine.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onSubmitted: onSearchSubmitted,
            style: const TextStyle(color: _Cine.text, fontSize: 14),
            cursorColor: _Cine.cyan,
            decoration: InputDecoration(
              hintText: context.tr('errorLogs.searchHint'),
              hintStyle: const TextStyle(color: _Cine.textDim, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _Cine.textDim),
              filled: true,
              fillColor: _Cine.surface.withValues(alpha: 0.7),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _Cine.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _Cine.cyan)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      statusChip(context.tr('errorLogs.filterAll'), null),
                      statusChip(context.tr('errorLogs.statusNew'), 'new'),
                      statusChip(context.tr('errorLogs.statusInvestigating'), 'investigating'),
                      statusChip(context.tr('errorLogs.statusResolved'), 'resolved'),
                      statusChip(context.tr('errorLogs.statusIgnored'), 'ignored'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: filter.severity,
                dropdownColor: _Cine.surfaceHi,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.filter_alt_rounded, color: _Cine.textDim, size: 18),
                style: const TextStyle(color: _Cine.text, fontSize: 12.5),
                hint: Text(context.tr('errorLogs.severityAll'), style: const TextStyle(color: _Cine.textDim, fontSize: 12.5)),
                items: [
                  DropdownMenuItem(value: null, child: Text(context.tr('errorLogs.severityAll'))),
                  DropdownMenuItem(value: 'low', child: Text(context.tr('errorLogs.severityLow'))),
                  DropdownMenuItem(value: 'medium', child: Text(context.tr('errorLogs.severityMedium'))),
                  DropdownMenuItem(value: 'high', child: Text(context.tr('errorLogs.severityHigh'))),
                  DropdownMenuItem(value: 'critical', child: Text(context.tr('errorLogs.severityCritical'))),
                ],
                onChanged: onSeverityChanged,
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────── ردیف خطا ───────────────────────────────────
class _ErrorRow extends ConsumerStatefulWidget {
  final ErrorLogEntry entry;
  const _ErrorRow({required this.entry});

  @override
  ConsumerState<_ErrorRow> createState() => _ErrorRowState();
}

class _ErrorRowState extends ConsumerState<_ErrorRow> {
  bool _hover = false;
  bool _loadingDetail = false;

  /// همان دلیل [_openDetail]: رکورد فهرست پیام/Stack trace ندارد، پس قبل از
  /// ساختن گزارش کپی، رکورد کامل را می‌گیریم — وگرنه گزارش کپی‌شده برای
  /// Claude خالی از مهم‌ترین بخش (پیام خطا) می‌بود.
  Future<void> _copyForAi(BuildContext context) async {
    if (_loadingDetail) return;
    setState(() => _loadingDetail = true);
    try {
      final full = await ref.read(errorLogsDataSourceProvider).fetchDetail(widget.entry.id);
      await Clipboard.setData(ClipboardData(text: full.toAiReport()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('errorLogs.copiedSnackbar'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  /// رفع اشکال «پیام خطا/Stack trace همیشه خالی است»: ردیف‌های فهرست از
  /// `GET /admin/error-logs` می‌آیند که عمداً message/stack_trace/context را
  /// برنمی‌گرداند (سبک‌نگه‌داشتن لیست). قبلاً همین رکورد ناقص مستقیم به
  /// `_ErrorDetailSheet` داده می‌شد؛ حالا پیش از باز کردن جزئیات، رکورد کامل
  /// را از `GET /admin/error-logs/:id` می‌گیریم.
  Future<void> _openDetail(BuildContext context) async {
    if (_loadingDetail) return;
    setState(() => _loadingDetail = true);
    try {
      final full = await ref.read(errorLogsDataSourceProvider).fetchDetail(widget.entry.id);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => _ErrorDetailSheet(entry: full),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final color = _severityColor(e.severity);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? _Cine.surfaceHi.withValues(alpha: 0.95) : _Cine.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hover ? color.withValues(alpha: 0.4) : _Cine.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.25), _Cine.surfaceHi]),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(_categoryIcon(e.category), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${e.errorCode} — ${e.title}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _Cine.text, fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                        if (e.occurrenceCount > 1) ...[
                          const SizedBox(width: 8),
                          _Badge(text: '${e.occurrenceCount}×', color: _Cine.amber),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _Badge(text: _statusLabel(context, e.status), color: e.status == ErrorLogStatus.resolved ? _Cine.green : color),
                        Text(_fmtOccurred(e), style: const TextStyle(color: _Cine.textDim, fontSize: 11.5)),
                        Text(e.source, style: const TextStyle(color: _Cine.textDim, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('errorLogs.copyForAiTooltip'),
                icon: _loadingDetail
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _Cine.textDim),
                      )
                    : const Icon(Icons.smart_toy_outlined, size: 20, color: _Cine.textDim),
                onPressed: _loadingDetail ? null : () => _copyForAi(context),
              ),
            ],
          ),
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
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────── صفحه‌بندی ───────────────────────────────────
class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({required this.page, required this.totalPages, required this.total, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_right_rounded, color: _Cine.textDim), onPressed: onPrev),
          Text(
            context.tr('errorLogs.pageLabel', {'page': '$page', 'totalPages': '$totalPages', 'total': '$total'}),
            style: const TextStyle(color: _Cine.textDim, fontSize: 12.5),
          ),
          IconButton(icon: const Icon(Icons.chevron_left_rounded, color: _Cine.textDim), onPressed: onNext),
        ],
      ),
    );
  }
}

// ═══════════════════════════ بازرس جزئیات (Bottom sheet) ════════════════════
class _ErrorDetailSheet extends ConsumerStatefulWidget {
  final ErrorLogEntry entry;
  const _ErrorDetailSheet({required this.entry});

  @override
  ConsumerState<_ErrorDetailSheet> createState() => _ErrorDetailSheetState();
}

class _ErrorDetailSheetState extends ConsumerState<_ErrorDetailSheet> {
  late ErrorLogStatus _status;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.entry.status;
    _notesController.text = widget.entry.resolutionNotes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _prettyContext(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) return '—';
    try {
      return const JsonEncoder.withIndent('  ').convert(m);
    } catch (_) {
      return m.toString();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(errorLogActionsProvider).updateStatus(
            widget.entry.id,
            status: _status,
            resolutionNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('errorLogs.deleteConfirmTitle')),
        content: Text(context.tr('errorLogs.deleteConfirmBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('common.delete'))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(errorLogActionsProvider).delete(widget.entry.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final color = _severityColor(e.severity);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(color: _Cine.bg.withValues(alpha: 0.97), border: const Border(top: BorderSide(color: _Cine.border))),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: _Cine.textDim.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), _Cine.surfaceHi]),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Icon(_categoryIcon(e.category), color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.errorCode} — ${e.title}', style: const TextStyle(color: _Cine.text, fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(_fmtOccurred(e), style: const TextStyle(color: _Cine.textDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('errorLogs.copyForAiTooltip'),
                      icon: const Icon(Icons.smart_toy_outlined, color: _Cine.cyan),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: e.toAiReport()));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('errorLogs.copiedSnackbar'))));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(text: _categoryLabel(context, e.category), color: _Cine.indigo),
                    _Badge(text: e.severity.name, color: color),
                    _Badge(text: _statusLabel(context, e.status), color: e.status == ErrorLogStatus.resolved ? _Cine.green : color),
                    if (e.occurrenceCount > 1) _Badge(text: '${e.occurrenceCount}× ${context.tr('errorLogs.repeatSuffix')}', color: _Cine.amber),
                  ],
                ),
                const SizedBox(height: 16),
                _MetaGrid(entry: e),
                const SizedBox(height: 16),
                Text(context.tr('errorLogs.messageTitle'), style: const TextStyle(color: _Cine.text, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 6),
                SelectableText(e.message, style: const TextStyle(color: _Cine.text, fontSize: 13.5, height: 1.6)),
                if (e.stackTrace != null && e.stackTrace!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Stack trace', style: const TextStyle(color: _Cine.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _Cine.codeBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _Cine.indigo.withValues(alpha: 0.25))),
                    child: SelectableText(
                      e.stackTrace!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 12, height: 1.6, fontFamily: 'monospace'),
                    ),
                  ),
                ],
                if (e.context != null && e.context!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(context.tr('errorLogs.contextTitle'), style: const TextStyle(color: _Cine.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _Cine.codeBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _Cine.indigo.withValues(alpha: 0.25))),
                    child: SelectableText(
                      _prettyContext(e.context),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 12, height: 1.6, fontFamily: 'monospace'),
                    ),
                  ),
                ],
                const Divider(height: 32, color: _Cine.border),
                Text(context.tr('errorLogs.statusLabel'), style: const TextStyle(color: _Cine.text, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<ErrorLogStatus>(
                  value: _status,
                  dropdownColor: _Cine.surfaceHi,
                  style: const TextStyle(color: _Cine.text),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _Cine.surface.withValues(alpha: 0.7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _Cine.border)),
                  ),
                  items: ErrorLogStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(context, s), style: const TextStyle(color: _Cine.text))))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(color: _Cine.text),
                  decoration: InputDecoration(
                    labelText: context.tr('errorLogs.notesLabel'),
                    labelStyle: const TextStyle(color: _Cine.textDim),
                    filled: true,
                    fillColor: _Cine.surface.withValues(alpha: 0.7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _Cine.border)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _Cine.cyan, foregroundColor: Colors.black),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? context.tr('errorLogs.savingLabel') : context.tr('common.save')),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: _Cine.red, side: const BorderSide(color: _Cine.red)),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.tr('common.delete')),
                      onPressed: _confirmDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  final ErrorLogEntry entry;
  const _MetaGrid({required this.entry});

  @override
  Widget build(BuildContext context) {
    Widget cell(String k, String? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(k, style: const TextStyle(color: _Cine.textDim, fontSize: 12))),
              Expanded(
                child: SelectableText(
                  v ?? '—',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: _Cine.text, fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _Cine.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: _Cine.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(context.tr('errorLogs.sourceLabel'), entry.source),
          if (entry.screenOrEndpoint != null) cell(context.tr('errorLogs.endpointLabel'), entry.screenOrEndpoint),
          if (entry.httpMethod != null || entry.httpStatus != null) cell('HTTP', '${entry.httpMethod ?? ''} ${entry.httpStatus ?? ''}'),
          if (entry.platform != null) cell(context.tr('errorLogs.platformLabel'), entry.platform),
          if (entry.appVersion != null) cell(context.tr('errorLogs.appVersionLabel'), entry.appVersion),
          if (entry.osVersion != null) cell(context.tr('errorLogs.osVersionLabel'), entry.osVersion),
          if (entry.deviceModel != null) cell(context.tr('errorLogs.deviceModelLabel'), entry.deviceModel),
          if (entry.userId != null) cell(context.tr('errorLogs.userLabel'), '${entry.userId} (${entry.userRole ?? '-'})'),
          if (entry.resolvedAt != null) cell(context.tr('errorLogs.resolvedAtLabel'), entry.resolvedAt),
        ],
      ),
    );
  }
}

// ───────────────────────────────── خطا ──────────────────────────────────────
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _Cine.textDim, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _Cine.cyan, foregroundColor: Colors.black),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

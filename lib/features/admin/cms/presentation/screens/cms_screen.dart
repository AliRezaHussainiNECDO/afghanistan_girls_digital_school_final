import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_drawer.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/language_theme_menu.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../../shared_models/subject.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../academy/domain/academy_entities.dart';
import '../../../../academy/presentation/academy_providers.dart';
import '../../../../academy/presentation/widgets/academy_shared.dart' as ash;
import '../../../../academy/presentation/widgets/book_sheets.dart' as bk;
import '../../../../academy/presentation/widgets/question_sheets.dart' as qs;
import '../../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../domain/entities/cms_entities.dart';
import '../../domain/usecases/cms_usecases.dart';
import '../providers/cms_providers.dart';
import '../widgets/cms_forms.dart';
import '../widgets/cms_shared.dart';
import '../widgets/instructor_codes_tab.dart';

/// طبق بخش ۱۴ سند: زیرسیستم واحد CMS برای مدیریت کتاب/درس/سؤال/کد دعوت
/// — نسخهٔ پویا با جستجو، آمار زنده، جزئیات، افزودن/ویرایش/حذف و گردش‌کار
/// وضعیت (پیش‌نویس → تأیید → انتشار).
class CmsScreen extends ConsumerWidget {
  const CmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        drawer: const AppDrawer(role: AppUserRole.superAdmin),
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          toolbarHeight: 72,
          automaticallyImplyLeading: false,
          leadingWidth: 44,
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: AppColors.orange600,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
          leading: IconButton(
            tooltip: context.tr('common.back'),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.adminDashboard),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('admin.cms'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(
                      context.tr('admin.cmsSubtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Builder(
              builder: (ctx) => IconButton(
                tooltip: context.tr('cms.menuTooltip'),
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const LanguageThemeMenu(),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: const Icon(Icons.menu_book_rounded), text: context.tr('cms.tabBooks')),
              Tab(icon: const Icon(Icons.article_rounded), text: context.tr('cms.tabLessons')),
              Tab(icon: const Icon(Icons.quiz_rounded), text: context.tr('cms.tabQuestions')),
              Tab(icon: const Icon(Icons.confirmation_number_rounded), text: context.tr('cms.tabInviteCodes')),
              Tab(icon: const Icon(Icons.co_present_rounded), text: context.tr('cms.tabInstructorCodes')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BooksTab(),
            _LessonsTab(),
            _QuestionsTab(),
            _InviteCodesTab(),
            InstructorCodesTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════ BOOKS ══════════════════════════
class _BooksTab extends ConsumerStatefulWidget {
  const _BooksTab();
  @override
  ConsumerState<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends ConsumerState<_BooksTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cmsBooksListProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_books',
        onPressed: () => ash.showAcademySheet(context, const bk.BookFormSheet()),
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(context.tr('admin.newBook')),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (books) {
          final filtered = books
              .where((b) =>
                  _query.isEmpty ||
                  b.title.contains(_query) ||
                  b.subject.contains(_query) ||
                  b.author.contains(_query))
              .toList();
          final published = books.where((b) => b.status == PublishStatus.published).length;
          final withRealFile = books.where((b) => b.hasPdf).length;
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.sunriseGradient,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.warm,
                ),
                child: Row(
                  children: [
                    Expanded(child: _BooksHeroStat(label: context.tr('cms.totalBooksLabel'), value: books.length)),
                    _heroDivider(),
                    Expanded(child: _BooksHeroStat(label: context.tr('cms.publishedLabel'), value: published)),
                    _heroDivider(),
                    Expanded(child: _BooksHeroStat(label: context.tr('cms.realFileLabel'), value: withRealFile)),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05),
              CmsSearchBar(onChanged: (v) => setState(() => _query = v)),
              Expanded(
                child: filtered.isEmpty
                    ? const CmsEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final b = filtered[i];
                          return _BookCard(
                            book: b,
                            onTap: () => ash.showAcademySheet(context, bk.BookDetailSheet(book: b)),
                          ).animate().fadeIn(delay: (30 * i).ms, duration: 260.ms).slideY(begin: 0.08);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ستون آماریِ داخل سربرگ گرادیانیِ تب کتاب‌ها — نسخهٔ «روی گرادیان» که
/// برخلاف `_MiniStat` معمولی (که پس‌زمینهٔ سطح دارد)، مستقیم روی گرادیان
/// گرم می‌نشیند تا این تب هم مثل بخش‌های تازه‌طراحی‌شدهٔ اپ (امتیازات/وضعیت
/// ارتقا) زنده و یکدست به‌نظر برسد.
class _BooksHeroStat extends StatelessWidget {
  final String label;
  final int value;
  const _BooksHeroStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

Widget _heroDivider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.35));

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final LibraryBook book;
  final VoidCallback onTap;
  const _BookCard({required this.book, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: ash.coverFor(book.coverIndex),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${book.subject} · ${book.gradeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ash.PublishChip(status: book.status),
                        if (book.hasPdf)
                          const Icon(Icons.picture_as_pdf_rounded, size: 15, color: AppColors.danger)
                        else if (book.pdfFileName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(context.tr('cms.fileNotUploaded'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.danger)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════ LESSONS ══════════════════════════
String _subjectNameFa(String subjectId) => mockSubjects
    .firstWhere((s) => s.id == subjectId, orElse: () => mockSubjects.first)
    .nameFa;

class _LessonsTab extends ConsumerStatefulWidget {
  const _LessonsTab();
  @override
  ConsumerState<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends ConsumerState<_LessonsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cmsLessonsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_lessons',
        onPressed: () => _openForm(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('admin.newLesson')),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (lessons) {
          final filtered = lessons
              .where((l) =>
                  _query.isEmpty ||
                  l.title.contains(_query) ||
                  l.chapterTitle.contains(_query) ||
                  _subjectNameFa(l.subjectId).contains(_query))
              .toList();
          return Column(
            children: [
              CmsStatsStrip(statuses: lessons.map((l) => l.status).toList()),
              CmsSearchBar(onChanged: (v) => setState(() => _query = v)),
              Expanded(
                child: filtered.isEmpty
                    ? const CmsEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final l = filtered[i];
                          return CmsCard(
                            icon: Icons.article_rounded,
                            title: l.title,
                            subtitle: '${context.tr('bulkImport.gradeOption', {'grade': '${l.gradeNumber}'})} · ${_subjectNameFa(l.subjectId)} · ${l.chapterTitle}',
                            status: l.status,
                            onTap: () => _openDetail(context, ref, l),
                          ).animate().fadeIn(delay: (30 * i).ms, duration: 260.ms).slideY(begin: 0.08);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, CmsLessonRow? existing) {
    showCmsSheet(context, LessonFormSheet(existing: existing));
  }

  void _openDetail(BuildContext context, WidgetRef ref, CmsLessonRow l) {
    showCmsSheet(
      context,
      CmsDetailSheet(
        title: l.title,
        icon: Icons.article_rounded,
        status: l.status,
        rows: [
          DetailRow(context.tr('cms.gradeFieldLabel'), context.tr('bulkImport.gradeOption', {'grade': '${l.gradeNumber}'})),
          DetailRow(context.tr('cms.subjectFieldLabel'), _subjectNameFa(l.subjectId)),
          DetailRow(context.tr('admin.fChapter'), l.chapterTitle),
          DetailRow(context.tr('admin.fDuration'), '${l.durationMinutes}'),
          DetailRow(context.tr('admin.fContent'), l.content),
          DetailRow(context.tr('admin.lastUpdated'), formatDate(l.updatedAt)),
        ],
        onEdit: () {
          Navigator.pop(context);
          _openForm(context, ref, l);
        },
        onDelete: () async {
          await ref.read(deleteLessonUseCaseProvider).call(l.id);
          ref.invalidate(cmsLessonsProvider);
          // رفع اشکال هماهنگی: حذف/تغییر وضعیت درس در CMS مدیر باید بلافاصله
          // در نصاب شاگردان هم منعکس شود — قبلاً فقط لیست خودِ CMS رفرش
          // می‌شد و صفحهٔ درس‌های شاگرد (در همان نشست) دیتای قدیمی نگه می‌داشت.
          ref.invalidate(chaptersProvider);
          ref.invalidate(lessonsProvider);
          ref.invalidate(lessonProvider);
        },
        onSetStatus: (s) async {
          await ref.read(setLessonStatusUseCaseProvider).call(SetStatusParams(id: l.id, status: s));
          ref.invalidate(cmsLessonsProvider);
          ref.invalidate(chaptersProvider);
          ref.invalidate(lessonsProvider);
          ref.invalidate(lessonProvider);
        },
      ),
    );
  }
}

// ══════════════════════════ QUESTIONS ══════════════════════════
class _QuestionsTab extends ConsumerStatefulWidget {
  const _QuestionsTab();
  @override
  ConsumerState<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends ConsumerState<_QuestionsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cmsQuestionsListProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_ai_gen',
            tooltip: context.tr('cms.aiGenerateTooltip'),
            onPressed: () => ash.showAcademySheet(context, const qs.AiGenerateSheet()),
            child: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_questions',
            onPressed: () => ash.showAcademySheet(context, const qs.QuestionFormSheet()),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.tr('admin.newQuestion')),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (questions) {
          final filtered = questions
              .where((q) => _query.isEmpty || q.text.contains(_query) || q.subject.contains(_query))
              .toList();
          final published = questions.where((q) => q.status == PublishStatus.published).length;
          return Column(
            children: [
              // نکتهٔ هماهنگی: این بانک سؤال، «تمرینِ» مضمون‌محورِ آکادمی را
              // می‌سازد (صفحهٔ تمرین شاگرد) — با «امتحانات رسمی» (که دروازهٔ
              // واقعیِ ارتقای صنف‌اند و در تب جداگانهٔ «مدیریت امتحانات رسمی»
              // مدیریت می‌شوند) اشتباه گرفته نشود.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('cms.practiceBankNotice'),
                          style: const TextStyle(fontSize: 11, color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(child: _MiniStat(label: context.tr('cms.totalQuestionsLabel'), value: questions.length, color: AppColors.orange600)),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(label: context.tr('cms.publishedLabel'), value: published, color: AppColors.green600)),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(label: context.tr('cms.draftLabel'), value: questions.length - published, color: AppColors.ink500)),
                  ],
                ),
              ),
              CmsSearchBar(onChanged: (v) => setState(() => _query = v)),
              Expanded(
                child: filtered.isEmpty
                    ? const CmsEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final q = filtered[i];
                          return _QuestionCard(
                            q: q,
                            onTap: () => ash.showAcademySheet(context, qs.QuestionDetailSheet(q: q)),
                          ).animate().fadeIn(delay: (30 * i).ms, duration: 260.ms).slideY(begin: 0.08);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final BankQuestion q;
  final VoidCallback onTap;
  const _QuestionCard({required this.q, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.quiz_rounded, size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ash.KindChip(kind: q.kind),
                      ash.PublishChip(status: q.status),
                      Text('${q.subject} · ${q.gradeId == 0 ? context.tr('academy.generalGradeLabel') : context.tr('bulkImport.gradeOption', {'grade': '${q.gradeId}'})}',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ]),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════ INVITE CODES ══════════════════════════
class _InviteCodesTab extends ConsumerStatefulWidget {
  const _InviteCodesTab();
  @override
  ConsumerState<_InviteCodesTab> createState() => _InviteCodesTabState();
}

class _InviteCodesTabState extends ConsumerState<_InviteCodesTab> {
  String _query = '';

  Future<void> _showGenerateDialog() async {
    final countController = TextEditingController(text: '10');
    final batchController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('admin.generateCodes')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('cms.countFieldLabel')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: batchController,
              decoration: InputDecoration(labelText: context.tr('cms.batchLabelFieldLabel')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('common.confirm'))),
        ],
      ),
    );
    if (confirmed == true) {
      final count = int.tryParse(countController.text) ?? 0;
      await ref.read(generateInviteCodesUseCaseProvider).call(GenerateInviteCodesParams(
            count: count,
            batchLabel: batchController.text.trim(),
            type: 'student',
          ));
      ref.invalidate(cmsInviteCodesProvider('student'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final codesAsync = ref.watch(cmsInviteCodesProvider('student'));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_codes',
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('admin.generateCodes')),
      ),
      body: codesAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (codes) {
          final filtered = codes
              .where((c) => _query.isEmpty || c.code.contains(_query) || c.batchLabel.contains(_query))
              .toList();
          return Column(
            children: [
              CmsSearchBar(onChanged: (v) => setState(() => _query = v)),
              Expanded(
                child: filtered.isEmpty
                    ? const CmsEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          return _InviteCard(
                            code: c,
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: c.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('cms.codeCopiedNotice', {'code': c.code})), behavior: SnackBarBehavior.floating),
                              );
                            },
                            onRevoke: c.status == 'unused'
                                ? () async {
                                    await ref.read(revokeInviteCodeUseCaseProvider).call(c.id);
                                    ref.invalidate(cmsInviteCodesProvider('student'));
                                  }
                                : null,
                          ).animate().fadeIn(delay: (30 * i).ms, duration: 260.ms).slideY(begin: 0.08);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final CmsInviteCodeRow code;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;
  const _InviteCard({required this.code, required this.onCopy, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final revoked = code.status == 'revoked';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.confirmation_number_rounded, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.code,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    decoration: revoked ? TextDecoration.lineThrough : null,
                    color: revoked ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
                Text(code.batchLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                // ── قابلیت بازبینی: مصرف‌کننده یا اعتبار باقی‌مانده ──
                if (code.status == 'used' && code.usedByName.isNotEmpty)
                  Text(context.tr('cms.registeredByLabel', {'name': code.usedByName}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green600))
                else if (code.status == 'unused' && code.expiresAt != null)
                  Text(context.tr('cms.remainingDaysLabel', {'days': '${code.remainingDays}'}),
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          InviteStatusChip(status: code.status),
          IconButton(
            tooltip: context.tr('cms.copyTooltip'),
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: onCopy,
          ),
          if (onRevoke != null)
            IconButton(
              tooltip: context.tr('common.delete'),
              icon: Icon(Icons.block_rounded, color: scheme.error, size: 18),
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}

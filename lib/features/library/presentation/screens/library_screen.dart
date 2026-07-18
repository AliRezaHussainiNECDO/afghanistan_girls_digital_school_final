import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../academy/domain/academy_entities.dart';
import '../../../academy/presentation/academy_providers.dart';
import '../../../academy/presentation/widgets/academy_shared.dart';
import '../../../academy/presentation/widgets/book_sheets.dart';

/// کتابخانهٔ شاگرد — کتاب‌هایی که مدیر در «مدیریت محتوا» منتشر کرده و به
/// صنف همین شاگرد تعلق دارند (یا عمومی‌اند)، اینجا با همان جزئیات نمایش
/// داده می‌شوند و قابل مشاهده/دانلود واقعی هستند (هماهنگ با انبار مشترک
/// AcademyStore). طراحی مطابق زبان بصری گرم اپ (گرادیان‌های نارنجی/طلایی).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(publishedBooksProvider);
    final query = ref.watch(librarySearchProvider);

    return AppScaffold(
      title: context.tr('nav.library'),
      role: AppUserRole.student,
      body: booksAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          // نکته: `publishedBooksProvider` خودش منتظر `academyHydrationProvider`
          // می‌ماند؛ اگر خطا از همان‌جا (مثلاً اتصال اول ناموفق) باشد، فقط
          // invalidate کردن publishedBooksProvider کافی نیست چون آن Provider
          // (غیر autoDispose) هنوز در حالت خطا کش شده — باید خودش را هم
          // invalidate کرد تا واقعاً دوباره تلاش شود.
          onRetry: () {
            ref.invalidate(academyHydrationProvider);
            ref.invalidate(publishedBooksProvider);
          },
        ),
        data: (books) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(academyHydrationProvider);
            ref.invalidate(publishedBooksProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _LibraryHero(bookCount: books.length)
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: -0.06),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _LibrarySearchField(
                    onChanged: (v) => ref.read(librarySearchProvider.notifier).state = v,
                  ),
                ),
              ),
              if (books.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LibraryEmptyState(searching: query.trim().isNotEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final book = books[i];
                      return _LibraryCard(
                        book: book,
                        onOpen: () => showAcademySheet(context, StudentBookSheet(book: book)),
                      ).animate().fadeIn(delay: (35 * i).ms, duration: 260.ms).slideY(begin: 0.08);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// سربرگِ گرادیانیِ گرم — تعداد کتاب‌های در دسترسِ همین صنف را با یک نماد
/// پویا (آیکونِ شناور با انیمیشن ملایم) نشان می‌دهد تا کتابخانه هم مثل
/// بقیهٔ اپ زنده و دعوت‌کننده به‌نظر برسد.
class _LibraryHero extends StatelessWidget {
  final int bookCount;
  const _LibraryHero({required this.bookCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.sunriseGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.warm,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 30),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.08, duration: 1600.ms, curve: Curves.easeInOut),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('nav.library'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
                ),
                const SizedBox(height: 4),
                Text(
                  '$bookCount ${context.tr('library.booksCount')} · ${context.tr('library.download')}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _LibrarySearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: context.tr('library.searchHint'),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  final bool searching;
  const _LibraryEmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradientWarm,
                shape: BoxShape.circle,
              ),
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.menu_book_rounded,
                color: Colors.white,
                size: 38,
              ),
            ).animate().scaleXY(begin: 0.85, end: 1, duration: 320.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(
              context.tr(searching ? 'library.emptySearch' : 'library.empty'),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 260.ms);
  }
}

class _LibraryCard extends StatelessWidget {
  final LibraryBook book;
  final VoidCallback onOpen;
  const _LibraryCard({required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: coverFor(book.coverIndex),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${book.subject} · ${book.gradeLabel} · ${book.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    if (book.fileSizeMb > 0)
                      Text('${book.fileSizeMb} MB',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(Icons.download_rounded, color: scheme.onPrimaryContainer),
                  tooltip: context.tr('library.download'),
                  onPressed: onOpen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

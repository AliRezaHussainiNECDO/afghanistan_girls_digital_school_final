import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../academy/domain/academy_entities.dart';
import '../../../academy/presentation/academy_providers.dart';
import '../../../academy/presentation/widgets/academy_shared.dart';
import '../../../academy/presentation/widgets/book_sheets.dart';

/// کتابخانهٔ شاگرد — کتاب‌هایی که مدیر در «مدیریت محتوا» منتشر کرده، اینجا
/// با همان جزئیات نمایش داده می‌شوند و قابل مشاهده/دانلود هستند (هماهنگ با
/// انبار مشترک AcademyStore).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(publishedBooksProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('nav.library'),
      role: AppUserRole.student,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
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
              onChanged: (v) => ref.read(librarySearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: booksAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(message: e.toString()),
              data: (books) => books.isEmpty
                  ? EmptyView(message: 'هنوز کتابی منتشر نشده است', icon: Icons.menu_book_rounded)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          ),
        ],
      ),
    );
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

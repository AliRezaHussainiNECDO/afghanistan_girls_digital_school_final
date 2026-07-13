import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/collective_memory_providers.dart';
import '../widgets/memory_composer_sheet.dart';
import '../widgets/memory_post_card.dart';

/// صفحهٔ اصلی «حافظهٔ جمعی» — آرشیو زندهٔ روایت‌های دختران و زنان افغانستان.
/// طبق درخواست کاربر: برای همه در دسترس است (بدون پیشوند نقش در مسیر)،
/// با طراحی مدرن، فید زیبا و دکمهٔ شناور برای ثبت روایت تازه.
class CollectiveMemoryScreen extends ConsumerWidget {
  const CollectiveMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final postsAsync = ref.watch(filteredMemoryPostsProvider);
    final searchQuery = ref.watch(memorySearchQueryProvider);

    if (user == null) return const SizedBox.shrink();

    return AppScaffold(
      title: 'حافظهٔ جمعی',
      role: user.role,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMemoryComposerSheet(context),
        backgroundColor: scheme.primary,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text('روایت تازه', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(memoryPostsRefreshProvider.notifier).state++,
        child: postsAsync.when(
          data: (posts) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _Header(scheme: scheme),
                const SizedBox(height: 14),
                _SearchBar(scheme: scheme),
                const SizedBox(height: 14),
                if (posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                              searchQuery.trim().isEmpty
                                  ? Icons.auto_stories_outlined
                                  : Icons.search_off_rounded,
                              size: 52,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                              searchQuery.trim().isEmpty
                                  ? 'هنوز روایتی ثبت نشده — اولین روایت را تو بنویس.'
                                  : 'روایتی با این عبارت پیدا نشد.',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  )
                else
                  ...posts.map((p) => MemoryPostCard(post: p)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('خطا در بارگذاری حافظهٔ جمعی: $e', style: TextStyle(color: scheme.error)),
            ),
          ),
        ),
      ),
    );
  }
}

/// نوار جستجو در روایت‌ها — فیلتر زنده روی متن و نام نویسنده.
class _SearchBar extends ConsumerStatefulWidget {
  final ColorScheme scheme;
  const _SearchBar({required this.scheme});

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(memorySearchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final query = ref.watch(memorySearchQueryProvider);
    return TextField(
      controller: _controller,
      textDirection: TextDirection.rtl,
      onChanged: (value) => ref.read(memorySearchQueryProvider.notifier).state = value,
      decoration: InputDecoration(
        hintText: 'جستجو در روایت‌ها (متن یا نام نویسنده)...',
        prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant, size: 20),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant, size: 18),
                onPressed: () {
                  _controller.clear();
                  ref.read(memorySearchQueryProvider.notifier).state = '';
                  FocusScope.of(context).unfocus();
                },
              ),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ColorScheme scheme;
  const _Header({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradientWarm,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('روایت‌های دختران و زنان افغانستان',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'اینجا فضایی امن برای بازگو کردن تجربه‌ها، بازدیدها و داستان‌های واقعی است — '
            'صدای هر نفر بخشی از تاریخی است که با هم می‌سازیم.',
            style: TextStyle(color: Colors.white, height: 1.7, fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0, duration: 300.ms);
  }
}

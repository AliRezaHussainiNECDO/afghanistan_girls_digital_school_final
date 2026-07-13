/// صفحهٔ لیست استادان — «مدیریت استادان» پنل مدیر (بخش ۱۵.۲ سند)،
/// هم‌الگو با صفحهٔ «مدیریت شاگردان» (student_list_screen.dart):
/// لیست با جزئیات هر استاد؛ کلیک روی هر نام ← صفحهٔ فعالیت‌های او.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/instructor/instructor_directory.dart';
import '../../../../seminars/data/datasources/seminar_store.dart';
import '../widgets/common_widgets.dart';

class InstructorListScreen extends StatefulWidget {
  const InstructorListScreen({super.key});

  @override
  State<InstructorListScreen> createState() => _InstructorListScreenState();
}

class _InstructorListScreenState extends State<InstructorListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: ListenableBuilder(
          listenable: InstructorDirectory.instance,
          builder: (context, _) {
            final instructors = InstructorDirectory.instance.search(_query);
            return CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: 150,
                pinned: true,
                backgroundColor: AppPalette.greenDark,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsetsDirectional.only(start: 16, bottom: 14),
                  title: const Text('مدیریت استادان',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [AppPalette.greenDark, AppPalette.green],
                      ),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
                        child: Text(
                          '${InstructorDirectory.instance.all.length} استاد ثبت‌شده',
                          style: TextStyle(
                              color: Colors.white.withOpacity(.85),
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'جستجوی نام، ایمیل یا تخصص استاد…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              instructors.isEmpty
                  ? const SliverFillRemaining(
                      child:
                          Center(child: Text('استادی با این فیلتر یافت نشد')))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: instructors.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _InstructorCard(instructor: instructors[i]),
                      ),
                    ),
            ]);
          },
        ),
      ),
    );
  }
}

class _InstructorCard extends StatelessWidget {
  final InstructorProfile instructor;
  const _InstructorCard({required this.instructor});

  @override
  Widget build(BuildContext context) {
    // آمار فعالیت از همان منبع واحد حقیقت سمینارها (SeminarStore) —
    // «هر چه داشبورد استاد می‌بیند، مدیر همان را می‌بیند».
    final seminars = SeminarStore.instance.byInstructorSync(instructor.id);
    final liveCount = seminars.where((s) => s.isLiveNow).length;
    final upcoming =
        seminars.where((s) => !s.hasEnded && !s.isLiveNow).length;
    final totalRegistrations =
        seminars.fold<int>(0, (sum, s) => sum + s.registeredCount);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/admin/instructors/${instructor.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Hero(
              tag: 'instructor-avatar-${instructor.id}',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: instructor.suspended
                    ? Colors.grey.withOpacity(.2)
                    : AppPalette.green.withOpacity(.15),
                child: Text(
                  instructor.fullName.characters.first,
                  style: TextStyle(
                      color: instructor.suspended
                          ? Colors.grey
                          : AppPalette.greenDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(instructor.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      _SuspendPill(suspended: instructor.suspended),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      instructor.specialty.isEmpty
                          ? instructor.email
                          : '${instructor.specialty} • ${instructor.email}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _StatChip(
                          icon: Icons.co_present_rounded,
                          label: '${seminars.length} سمینار'),
                      if (liveCount > 0)
                        _StatChip(
                            icon: Icons.podcasts_rounded,
                            label: '$liveCount زنده',
                            color: AppPalette.red),
                      if (upcoming > 0)
                        _StatChip(
                            icon: Icons.event_rounded,
                            label: '$upcoming پیش رو',
                            color: AppPalette.amber),
                      _StatChip(
                          icon: Icons.group_rounded,
                          label: '$totalRegistrations ثبت‌نام'),
                    ]),
                  ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

class _SuspendPill extends StatelessWidget {
  final bool suspended;
  const _SuspendPill({required this.suspended});

  @override
  Widget build(BuildContext context) {
    final color = suspended ? AppPalette.red : AppPalette.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(suspended ? 'مسدود' : 'فعال',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, this.color = AppPalette.greenDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ]),
      );
}

import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../domain/academy_entities.dart';

/// رنگ‌های جلد کتاب — برای تنوع بصری در کتابخانه و مدیریت محتوا.
const List<List<Color>> kCoverGradients = [
  [AppColors.orange500, AppColors.orange700],
  [AppColors.green500, AppColors.green700],
  [AppColors.info, Color(0xFF2A5C8A)],
  [AppColors.gold500, AppColors.gold600],
  [Color(0xFF8E5BD0), Color(0xFF5B3D9E)],
  [Color(0xFFE5484D), Color(0xFFB03038)],
];

List<Color> coverFor(int index) => kCoverGradients[index % kCoverGradients.length];

/// صنوف قابل انتخاب: عمومی + ۷ الی ۱۲.
const List<int> kGrades = [0, 7, 8, 9, 10, 11, 12];
String gradeLabel(int g) => g == 0 ? 'عمومی' : 'صنف $g';

/// مضامین رایج نصاب (پیشنهاد برای Dropdownها).
const List<String> kSubjects = [
  'ریاضی',
  'فزیک',
  'کیمیا',
  'بیولوژی',
  'ادبیات دری',
  'انگلیسی',
  'تاریخ',
  'جغرافیه',
  'دینیات',
  'کمپیوتر',
];

const List<String> kCategories = ['کتاب درسی رسمی', 'کمک‌درسی', 'داستان', 'مهارت زندگی'];

String formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// نمایش یک BottomSheet یکدست و واکنش‌گرا در سراسر بخش آموزشی.
Future<T?> showAcademySheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}

/// نشان وضعیت انتشار (پیش‌نویس / منتشرشده).
class PublishChip extends StatelessWidget {
  final PublishStatus status;
  const PublishChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final published = status == PublishStatus.published;
    final c = published ? AppColors.green600 : AppColors.ink500;
    final label = published ? 'منتشرشده' : 'پیش‌نویس';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

/// نشان نوع سؤال.
class KindChip extends StatelessWidget {
  final QuestionKind kind;
  const KindChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    late Color c;
    late String label;
    switch (kind) {
      case QuestionKind.mcq:
        c = AppColors.info;
        label = 'چهارجوابه';
        break;
      case QuestionKind.trueFalse:
        c = AppColors.gold600;
        label = 'صحیح/غلط';
        break;
      case QuestionKind.essay:
        c = AppColors.orange600;
        label = 'تشریحی';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

String kindLabel(QuestionKind k) {
  switch (k) {
    case QuestionKind.mcq:
      return 'چهارجوابه';
    case QuestionKind.trueFalse:
      return 'صحیح/غلط';
    case QuestionKind.essay:
      return 'تشریحی';
  }
}

/// فیلد ورودی استاندارد بخش آموزشی.
Widget academyField(TextEditingController c, String label, {int maxLines = 1, TextInputType? keyboard}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    ),
  );
}

/// یک ردیف «برچسب/مقدار» برای صفحات جزئیات.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

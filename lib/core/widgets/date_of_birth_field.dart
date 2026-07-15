import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// فیلد انتخاب تاریخ تولد با تقویم پویا (Date Picker) — به‌جای ورودی متنی
/// آزاد که قبلاً باعث ثبت فرمت‌های ناهماهنگ (مثلاً با '/' به‌جای '-') و در
/// نتیجه کرش هنگام پارس در سمت مدیریت می‌شد، کاربر با لمس فیلد، تقویم روز را
/// باز کرده و تاریخ تولد خود را از آن انتخاب می‌کند.
///
/// مقدار انتخابی همیشه به‌صورت ISO یکنواخت `yyyy-MM-dd` در کنترلر ذخیره
/// می‌شود تا با بک‌اند و پارس‌کنندهٔ مقاوم تاریخ (`_lenientDate` در
/// `student_models.dart`) کاملاً هماهنگ بماند.
///
/// در فرم‌های ثبت‌نام (شاگرد/والدین/استادان) و هر جای دیگری که تاریخ تولد
/// گرفته می‌شود از این ویجت به‌جای `TextFormField` خام استفاده کنید.
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    super.key,
    required this.controller,
    this.label,
    this.validator,
    this.minAge = 3,
    this.maxAge = 100,
  });

  final TextEditingController controller;
  final String? label;
  final String? Function(String?)? validator;

  /// محدودهٔ سنی قابل انتخاب — برای جلوگیری از انتخاب تاریخ‌های نامعقول.
  final int minAge;
  final int maxAge;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - maxAge, now.month, now.day);
    final lastDate = DateTime(now.year - minAge, now.month, now.day);

    DateTime initial = lastDate;
    final parsed = DateTime.tryParse(controller.text.trim().replaceAll('/', '-'));
    if (parsed != null && !parsed.isBefore(firstDate) && !parsed.isAfter(lastDate)) {
      initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: label ?? context.tr('auth.dateOfBirth'),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;

    final iso = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    controller.text = iso;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      showCursor: false,
      decoration: InputDecoration(
        labelText: label ?? context.tr('auth.dateOfBirth'),
        hintText: 'YYYY-MM-DD',
        suffixIcon: const Icon(Icons.calendar_month_rounded),
      ),
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? context.tr('common.required') : null,
      onTap: () => _pick(context),
    );
  }
}

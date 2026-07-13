import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared_models/seminar.dart';

/// نتیجهٔ فرم ایجاد/ویرایش سمینار.
class SeminarEditorResult {
  final String title;
  final String description;
  final String? instructorName;
  final DateTime scheduledStart;
  final int durationMinutes;
  final int? capacity;
  final SeminarAudience audience;
  final SeminarStatus? status;
  final String meetingLink;

  const SeminarEditorResult({
    required this.title,
    required this.description,
    this.instructorName,
    required this.scheduledStart,
    required this.durationMinutes,
    this.capacity,
    required this.audience,
    this.status,
    this.meetingLink = '',
  });
}

/// دیالوگ مدرن ایجاد/ویرایش سمینار — مشترک بین استاد و مدیر ارشد.
/// [showInstructorField] فقط برای مدیر (که نام استاد را تعیین می‌کند)،
/// [showStatusField] فقط در حالت ویرایش مدیر/استاد.
Future<SeminarEditorResult?> showSeminarEditorDialog(
  BuildContext context, {
  Seminar? existing,
  bool showInstructorField = false,
  bool showStatusField = false,
}) {
  final isEdit = existing != null;
  final titleController = TextEditingController(text: existing?.title ?? '');
  final descriptionController = TextEditingController(text: existing?.description ?? '');
  final instructorController = TextEditingController(text: existing?.instructorName ?? '');
  final durationController =
      TextEditingController(text: (existing?.durationMinutes ?? 45).toString());
  final capacityController = TextEditingController(text: existing?.capacity?.toString() ?? '');
  final meetingLinkController = TextEditingController(text: existing?.meetingLink ?? '');
  DateTime selectedDate = existing?.scheduledStart ?? DateTime.now().add(const Duration(days: 3));
  SeminarAudience audience = existing?.audience ?? SeminarAudience.students;
  SeminarStatus status = existing?.status ?? SeminarStatus.published;
  final formKey = GlobalKey<FormState>();

  return showDialog<SeminarEditorResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradientWarm,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_calendar_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit
                        ? dialogContext.tr('instructor.editSeminar')
                        : dialogContext.tr('instructor.createSeminar'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('instructor.titleLabel'),
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? dialogContext.tr('common.required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('instructor.descriptionLabel'),
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (showInstructorField) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: instructorController,
                        decoration: InputDecoration(
                          labelText: dialogContext.tr('admin.instructorName'),
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? dialogContext.tr('common.required')
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // لینک جلسهٔ زندهٔ خارجی (Zoom/Google Meet/Jitsi).
                    TextFormField(
                      controller: meetingLinkController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'لینک جلسهٔ زنده (Zoom/Meet/Jitsi)',
                        hintText: 'https://meet.jit.si/...',
                        prefixIcon: Icon(Icons.videocam_rounded),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null; // اختیاری
                        final ok = t.startsWith('http://') || t.startsWith('https://');
                        return ok ? null : 'لینک باید با http:// یا https:// شروع شود';
                      },
                    ),
                    const SizedBox(height: 12),
                    // مخاطب: شاگردان یا والدین
                    DropdownButtonFormField<SeminarAudience>(
                      value: audience,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('instructor.audienceLabel'),
                        prefixIcon: const Icon(Icons.groups_rounded),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: SeminarAudience.students,
                          child: Text(dialogContext.tr('seminars.forStudents')),
                        ),
                        DropdownMenuItem(
                          value: SeminarAudience.parents,
                          child: Text(dialogContext.tr('seminars.forParents')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => audience = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: dialogContext.tr('instructor.durationLabel'),
                              prefixIcon: const Icon(Icons.schedule_rounded),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return (n == null || n <= 0)
                                  ? dialogContext.tr('common.required')
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: capacityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: dialogContext.tr('instructor.capacityLabel'),
                              prefixIcon: const Icon(Icons.event_seat_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showStatusField && isEdit) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SeminarStatus>(
                        value: status,
                        decoration: InputDecoration(
                          labelText: dialogContext.tr('common.status'),
                          prefixIcon: const Icon(Icons.flag_rounded),
                        ),
                        items: SeminarStatus.values
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(dialogContext.tr('seminars.status.${s.name}')),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => status = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_calendar_outlined),
                      title: Text(dialogContext.tr('instructor.dateLabel'),
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} '
                        '${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate == null) return;
                        if (!dialogContext.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        setState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime?.hour ?? selectedDate.hour,
                            pickedTime?.minute ?? selectedDate.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.tr('common.cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  Navigator.of(dialogContext).pop(
                    SeminarEditorResult(
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      instructorName: showInstructorField
                          ? instructorController.text.trim()
                          : null,
                      scheduledStart: selectedDate,
                      durationMinutes: int.parse(durationController.text),
                      capacity: int.tryParse(capacityController.text),
                      audience: audience,
                      status: showStatusField ? status : null,
                      meetingLink: meetingLinkController.text.trim(),
                    ),
                  );
                },
                child: Text(dialogContext.tr('common.save')),
              ),
            ],
          );
        },
      );
    },
  );
}

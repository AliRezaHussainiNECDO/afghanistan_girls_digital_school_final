import 'package:equatable/equatable.dart';

/// اعلان — طبق جدول `notifications` بخش ۱۷.۶ سند.
enum NotificationPriority { low, medium, high }

/// نوع رویداد اعلان — برای انتخاب آیکن/رنگ متناسب در UI.
enum NotificationKind { book, exam, grade, seminar, safety, general }

class AppNotification extends Equatable {
  final String id;
  final String titleFa;
  final String bodyFa;
  final NotificationPriority priority;
  final DateTime createdAt;
  final bool read;
  final NotificationKind kind;

  const AppNotification({
    required this.id,
    required this.titleFa,
    required this.bodyFa,
    required this.priority,
    required this.createdAt,
    this.read = false,
    this.kind = NotificationKind.general,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        titleFa: titleFa,
        bodyFa: bodyFa,
        priority: priority,
        createdAt: createdAt,
        read: read ?? this.read,
        kind: kind,
      );

  @override
  List<Object?> get props => [id, read];
}

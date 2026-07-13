import 'package:equatable/equatable.dart';

/// مضمون درسی — طبق بخش ۱۷.۲ سند (`subjects`، ۱۰ رکورد ثابت).
class Subject extends Equatable {
  final String id;
  final String nameFa;
  final String nameEn;
  final String namePs;
  final String icon; // نام آیکون Material (برای سادگی فاز ۱)
  final int colorValue; // ARGB

  const Subject({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.namePs,
    required this.icon,
    required this.colorValue,
  });

  @override
  List<Object?> get props => [id];
}

/// ۱۰ مضمون ثابت هر صنف (بخش ۶.۱ سند) — دادهٔ Mock مشترک بین چند Feature.
const List<Subject> mockSubjects = [
  Subject(id: 'math', nameFa: 'ریاضی', nameEn: 'Mathematics', namePs: 'ریاضي', icon: 'calculate', colorValue: 0xFF3F51B5),
  Subject(id: 'physics', nameFa: 'فزیک', nameEn: 'Physics', namePs: 'فزیک', icon: 'science', colorValue: 0xFF009688),
  Subject(id: 'chemistry', nameFa: 'کیمیا', nameEn: 'Chemistry', namePs: 'کیمیا', icon: 'biotech', colorValue: 0xFF8E24AA),
  Subject(id: 'biology', nameFa: 'بیولوژی', nameEn: 'Biology', namePs: 'بیولوژي', icon: 'eco', colorValue: 0xFF43A047),
  Subject(id: 'english', nameFa: 'انگلیسی', nameEn: 'English', namePs: 'انګلیسي', icon: 'language', colorValue: 0xFF1E88E5),
  Subject(id: 'dari_lit', nameFa: 'ادبیات دری', nameEn: 'Dari Literature', namePs: 'دري ادبیات', icon: 'menu_book', colorValue: 0xFF6D4C41),
  Subject(id: 'history', nameFa: 'تاریخ', nameEn: 'History', namePs: 'تاریخ', icon: 'history_edu', colorValue: 0xFFA1887F),
  Subject(id: 'geography', nameFa: 'جغرافیه', nameEn: 'Geography', namePs: 'جغرافیه', icon: 'public', colorValue: 0xFF00897B),
  Subject(id: 'islamic', nameFa: 'تعلیمات اسلامی', nameEn: 'Islamic Studies', namePs: 'اسلامي زده‌کړې', icon: 'mosque', colorValue: 0xFF6A1B9A),
  Subject(id: 'cs', nameFa: 'کمپیوتر ساینس', nameEn: 'Computer Science', namePs: 'کمپیوټر ساینس', icon: 'computer', colorValue: 0xFF00ACC1),
];

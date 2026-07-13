import 'package:equatable/equatable.dart';

/// طبق بخش ۵.۲ و ۱۷.۳ سند (`ai_teachers`).
class AiTeacherConfig extends Equatable {
  final String subjectId;
  final String subjectNameFa;
  final String personaDescription;
  final int promptVersion;

  const AiTeacherConfig({
    required this.subjectId,
    required this.subjectNameFa,
    required this.personaDescription,
    required this.promptVersion,
  });

  @override
  List<Object?> get props => [subjectId, promptVersion];
}

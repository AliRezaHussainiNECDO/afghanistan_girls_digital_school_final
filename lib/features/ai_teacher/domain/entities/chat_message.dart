import 'package:equatable/equatable.dart';

enum ChatSender { student, ai }

/// طبق جدول `ai_conversations` بخش ۱۷.۳ سند.
class AiChatMessage extends Equatable {
  final String id;
  final ChatSender sender;
  final String body;
  final DateTime timestamp;
  final String? sourceReference; // ارجاع Chunk بازیابی‌شده — بخش ۵.۳.۲ گام ۶

  const AiChatMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    this.sourceReference,
  });

  @override
  List<Object?> get props => [id];
}

import 'package:equatable/equatable.dart';

/// یک کامنت (یا پاسخ به کامنت) روی یک پست در «حافظه جمعی».
/// `parentCommentId == null` یعنی کامنت اصلی است؛ در غیر این صورت
/// پاسخی به همان کامنت است (یک سطح Reply، طبق درخواست کاربر).
class MemoryComment extends Equatable {
  final String id;
  final String postId;
  final String? parentCommentId;
  final String authorId;
  final String authorName;
  final bool authorIsAdmin;

  /// عکس پروفایل نویسندهٔ کامنت در لحظهٔ ثبت (Base64).
  final String? authorAvatarBase64;

  final String body;
  final DateTime createdAt;

  const MemoryComment({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.authorId,
    required this.authorName,
    required this.authorIsAdmin,
    this.authorAvatarBase64,
    required this.body,
    required this.createdAt,
  });

  bool get isReply => parentCommentId != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'parentCommentId': parentCommentId,
        'authorId': authorId,
        'authorName': authorName,
        'authorIsAdmin': authorIsAdmin,
        'authorAvatarBase64': authorAvatarBase64,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MemoryComment.fromJson(Map<String, dynamic> j) => MemoryComment(
        id: j['id'] as String,
        postId: j['postId'] as String,
        parentCommentId: j['parentCommentId'] as String?,
        authorId: j['authorId'] as String,
        authorName: j['authorName'] as String,
        authorIsAdmin: j['authorIsAdmin'] as bool? ?? false,
        authorAvatarBase64: j['authorAvatarBase64'] as String?,
        body: j['body'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [id, postId, parentCommentId, body];
}

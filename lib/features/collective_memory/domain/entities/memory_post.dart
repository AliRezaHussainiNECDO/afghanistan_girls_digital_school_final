import 'package:equatable/equatable.dart';

/// یک پست در «حافظه جمعی» — روایت، تجربه یا بازدید یک کاربر دربارهٔ
/// خشونت یا موضوعات مربوط به دختران و زنان افغانستان. این بخش مثل یک
/// آرشیو زندهٔ تاریخی عمل می‌کند تا صدای هیچ‌کس گم نشود.
class MemoryPost extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final bool authorIsAdmin;

  /// عکس پروفایل نویسنده در لحظهٔ ثبت پست (Base64) — چون کاربران در
  /// راجستریشن احراز شده‌اند، هویت واقعی به همراه عکس نمایش داده می‌شود.
  final String? authorAvatarBase64;

  final String body;

  /// تصاویر ضمیمه به‌صورت Base64 (حداکثر ۴ عکس هر پست) — تا زمان اتصال
  /// بک‌اند واقعی (R2)، همین‌جا محلی ذخیره می‌شوند.
  final List<String> imagesBase64;

  final DateTime createdAt;
  final DateTime? updatedAt;

  /// ایموجی -> فهرست شناسهٔ کاربرانی که با آن واکنش نشان داده‌اند.
  final Map<String, List<String>> reactions;

  const MemoryPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorIsAdmin,
    this.authorAvatarBase64,
    required this.body,
    required this.imagesBase64,
    required this.createdAt,
    this.updatedAt,
    this.reactions = const {},
  });

  bool get isEdited => updatedAt != null;
  int get totalReactionCount => reactions.values.fold(0, (sum, list) => sum + list.length);
  bool hasUserReacted(String userId, String emoji) =>
      reactions[emoji]?.contains(userId) ?? false;
  bool hasAnyReactionFrom(String userId) =>
      reactions.values.any((list) => list.contains(userId));

  MemoryPost copyWith({
    String? body,
    List<String>? imagesBase64,
    DateTime? updatedAt,
    Map<String, List<String>>? reactions,
  }) =>
      MemoryPost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorIsAdmin: authorIsAdmin,
        authorAvatarBase64: authorAvatarBase64,
        body: body ?? this.body,
        imagesBase64: imagesBase64 ?? this.imagesBase64,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        reactions: reactions ?? this.reactions,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorIsAdmin': authorIsAdmin,
        'authorAvatarBase64': authorAvatarBase64,
        'body': body,
        'imagesBase64': imagesBase64,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'reactions': reactions,
      };

  factory MemoryPost.fromJson(Map<String, dynamic> j) => MemoryPost(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        authorName: j['authorName'] as String,
        authorIsAdmin: j['authorIsAdmin'] as bool? ?? false,
        authorAvatarBase64: j['authorAvatarBase64'] as String?,
        body: j['body'] as String? ?? '',
        imagesBase64: (j['imagesBase64'] as List?)?.map((e) => e as String).toList() ?? [],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'] as String) : null,
        reactions: (j['reactions'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as List).map((e) => e as String).toList()),
            ) ??
            {},
      );

  @override
  List<Object?> get props => [id, body, imagesBase64, updatedAt, reactions];
}

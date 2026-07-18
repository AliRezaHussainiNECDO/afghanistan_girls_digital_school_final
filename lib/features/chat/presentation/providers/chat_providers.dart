import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/chat_local_datasource.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories_impl/chat_repository_impl.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';

/// DataSource چت به کاربر واردشده وابسته است تا هر پیام با هویت واقعی
/// فرستنده (نام + صنف) ثبت شود — لازمهٔ نظارت مدیر (بخش ۱۰.۴ سند).
/// Mock محلی (فاز ۱) یا Backend واقعی + R2 — طبق سوییچ `kUseLiveBackend`.
final chatDataSourceProvider = Provider<ChatDataSource>((ref) {
  final user = ref.watch(authSessionProvider);
  if (kUseLiveBackend) {
    return ChatRemoteDataSource(api: ref.watch(apiClientProvider), currentUser: user);
  }
  return ChatLocalDataSource(currentUser: user);
});

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepositoryImpl(ref.watch(chatDataSourceProvider)));

// --- UseCase ها: دید شاگرد ---
final getConversationsUseCaseProvider =
    Provider((ref) => GetConversationsUseCase(ref.watch(chatRepositoryProvider)));
final getClassmatesUseCaseProvider =
    Provider((ref) => GetClassmatesUseCase(ref.watch(chatRepositoryProvider)));
final startConversationUseCaseProvider =
    Provider((ref) => StartConversationUseCase(ref.watch(chatRepositoryProvider)));
final getMessagesUseCaseProvider = Provider((ref) => GetMessagesUseCase(ref.watch(chatRepositoryProvider)));
final sendPeerMessageUseCaseProvider =
    Provider((ref) => SendPeerMessageUseCase(ref.watch(chatRepositoryProvider)));
final sendVoiceMessageUseCaseProvider =
    Provider((ref) => SendVoiceMessageUseCase(ref.watch(chatRepositoryProvider)));
final reportMessageUseCaseProvider =
    Provider((ref) => ReportMessageUseCase(ref.watch(chatRepositoryProvider)));

// --- UseCase ها: دید مدیر ---
final getClassChatSummariesUseCaseProvider =
    Provider((ref) => GetClassChatSummariesUseCase(ref.watch(chatRepositoryProvider)));
final getClassConversationsUseCaseProvider =
    Provider((ref) => GetClassConversationsUseCase(ref.watch(chatRepositoryProvider)));
final getAdminInboxUseCaseProvider =
    Provider((ref) => GetAdminInboxUseCase(ref.watch(chatRepositoryProvider)));
final getAdminConversationInfoUseCaseProvider =
    Provider((ref) => GetAdminConversationInfoUseCase(ref.watch(chatRepositoryProvider)));
final getAdminMessagesUseCaseProvider =
    Provider((ref) => GetAdminMessagesUseCase(ref.watch(chatRepositoryProvider)));
final reviewMessageUseCaseProvider =
    Provider((ref) => ReviewMessageUseCase(ref.watch(chatRepositoryProvider)));
final sendAdminReplyUseCaseProvider =
    Provider((ref) => SendAdminReplyUseCase(ref.watch(chatRepositoryProvider)));

// --- State: دید شاگرد ---
final conversationsProvider = FutureProvider<List<PeerConversation>>((ref) async {
  final result = await ref.read(getConversationsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final classmatesProvider = FutureProvider<List<Classmate>>((ref) async {
  final result = await ref.read(getClassmatesUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final messagesProvider = FutureProvider.family<List<PeerMessage>, String>((ref, conversationId) async {
  final result = await ref.read(getMessagesUseCaseProvider).call(conversationId);
  return result.fold((f) => throw f, (v) => v);
});

/// شناسهٔ گفتگوی «ارتباط با مدیریت» برای کاربر جاری — با هر نقشی (شاگرد،
/// والد، استاد) صدا زده شود، همان گفتگوی واحد و همیشگی با مدیریت مکتب را
/// برمی‌گرداند (یا در صورت نبود، می‌سازد).
final contactAdminConversationProvider = FutureProvider.autoDispose<String>((ref) async {
  final result = await ref.read(startConversationUseCaseProvider).call('admin');
  return result.fold((f) => throw f, (id) => id);
});

// --- State: دید مدیر (نظارت صنف‌به‌صنف) ---
final classChatSummariesProvider = FutureProvider<List<ClassChatSummary>>((ref) async {
  final result = await ref.read(getClassChatSummariesUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final classConversationsProvider =
    FutureProvider.family<List<AdminConversationSummary>, String>((ref, classId) async {
  final result = await ref.read(getClassConversationsUseCaseProvider).call(classId);
  return result.fold((f) => throw f, (v) => v);
});

final adminInboxProvider = FutureProvider<List<AdminConversationSummary>>((ref) async {
  final result = await ref.read(getAdminInboxUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final adminConversationInfoProvider =
    FutureProvider.family<AdminConversationSummary, String>((ref, conversationId) async {
  final result = await ref.read(getAdminConversationInfoUseCaseProvider).call(conversationId);
  return result.fold((f) => throw f, (v) => v);
});

final adminMessagesProvider =
    FutureProvider.family<List<PeerMessage>, String>((ref, conversationId) async {
  final result = await ref.read(getAdminMessagesUseCaseProvider).call(conversationId);
  return result.fold((f) => throw f, (v) => v);
});

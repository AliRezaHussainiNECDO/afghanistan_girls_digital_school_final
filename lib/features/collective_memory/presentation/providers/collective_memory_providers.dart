import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/collective_memory_local_datasource.dart';
import '../../data/datasources/collective_memory_remote_datasource.dart';
import '../../data/repositories_impl/collective_memory_repository_impl.dart';
import '../../domain/entities/memory_comment.dart';
import '../../domain/entities/memory_post.dart';
import '../../domain/repositories/collective_memory_repository.dart';
import '../../domain/usecases/collective_memory_usecases.dart';

/// Mock/محلی (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final collectiveMemoryDataSourceProvider =
    Provider<CollectiveMemoryDataSource>((ref) {
  if (kUseLiveBackend) {
    return CollectiveMemoryRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CollectiveMemoryLocalDataSource();
});

final collectiveMemoryRepositoryProvider = Provider<CollectiveMemoryRepository>(
  (ref) => CollectiveMemoryRepositoryImpl(ref.watch(collectiveMemoryDataSourceProvider)),
);

final getPostsUseCaseProvider =
    Provider((ref) => GetPostsUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final createPostUseCaseProvider =
    Provider((ref) => CreatePostUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final updatePostUseCaseProvider =
    Provider((ref) => UpdatePostUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final deletePostUseCaseProvider =
    Provider((ref) => DeletePostUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final toggleReactionUseCaseProvider =
    Provider((ref) => ToggleReactionUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final getCommentsUseCaseProvider =
    Provider((ref) => GetCommentsUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final addCommentUseCaseProvider =
    Provider((ref) => AddCommentUseCase(ref.watch(collectiveMemoryRepositoryProvider)));
final deleteCommentUseCaseProvider =
    Provider((ref) => DeleteCommentUseCase(ref.watch(collectiveMemoryRepositoryProvider)));

/// فهرست پست‌ها — با `refreshToken` بعد از هر تغییر (ایجاد/ویرایش/حذف/واکنش)
/// نامعتبر می‌شود تا فید فوراً به‌روز شود.
final memoryPostsRefreshProvider = StateProvider<int>((ref) => 0);

final memoryPostsProvider = FutureProvider<List<MemoryPost>>((ref) async {
  ref.watch(memoryPostsRefreshProvider);
  final result = await ref.read(getPostsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final memoryCommentsProvider =
    FutureProvider.family<List<MemoryComment>, String>((ref, postId) async {
  ref.watch(memoryPostsRefreshProvider);
  final result = await ref.read(getCommentsUseCaseProvider).call(postId);
  return result.fold((f) => throw f, (v) => v);
});

/// تعداد کامنت‌های هر پست (برای نمایش شمارنده روی کارت بدون باز کردن ورق کامنت‌ها).
final memoryCommentCountProvider = FutureProvider.family<int, String>((ref, postId) async {
  final comments = await ref.watch(memoryCommentsProvider(postId).future);
  return comments.length;
});

/// عبارت جستجو در فید حافظهٔ جمعی — فیلتر محلی روی متن روایت و نام نویسنده.
final memorySearchQueryProvider = StateProvider<String>((ref) => '');

/// فهرست پست‌ها پس از اعمال جستجو — اگر عبارت خالی باشد، همهٔ پست‌ها.
final filteredMemoryPostsProvider = FutureProvider<List<MemoryPost>>((ref) async {
  final posts = await ref.watch(memoryPostsProvider.future);
  final query = ref.watch(memorySearchQueryProvider).trim();
  if (query.isEmpty) return posts;
  final q = query.toLowerCase();
  return posts
      .where((p) =>
          p.body.toLowerCase().contains(q) || p.authorName.toLowerCase().contains(q))
      .toList();
});

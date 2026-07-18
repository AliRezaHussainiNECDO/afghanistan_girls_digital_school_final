import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/memory_post.dart';
import '../../domain/usecases/collective_memory_usecases.dart';
import '../providers/collective_memory_providers.dart';

const int _maxImagesPerPost = 4;

/// برگهٔ ساخت/ویرایش یک روایت — طبق درخواست کاربر: متن + ضمیمهٔ تصویر با
/// طراحی مدرن و قابلیت ادیت کامل. برای پست جدید `existing` را null بدهید.
Future<void> showMemoryComposerSheet(BuildContext context, {MemoryPost? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MemoryComposerSheet(existing: existing),
  );
}

class _MemoryComposerSheet extends ConsumerStatefulWidget {
  final MemoryPost? existing;
  const _MemoryComposerSheet({this.existing});

  @override
  ConsumerState<_MemoryComposerSheet> createState() => _MemoryComposerSheetState();
}

class _MemoryComposerSheetState extends ConsumerState<_MemoryComposerSheet> {
  late final TextEditingController _controller;
  late List<String> _images; // base64
  bool _submitting = false;
  bool _pickingImage = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.body ?? '');
    _images = List<String>.from(widget.existing?.imagesBase64 ?? const []);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImagesPerPost) {
      setState(() => _error = context.tr('memory.maxImagesError', {'max': '$_maxImagesPerPost'}));
      return;
    }
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 82);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() => _images.add(base64Encode(bytes)));
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('memory.imagePickFailed'));
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.tr('memory.writeStoryRequired'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await ref.read(updatePostUseCaseProvider).call(UpdatePostParams(
              postId: widget.existing!.id,
              body: text,
              imagesBase64: _images,
            ));
      } else {
        final user = ref.read(authSessionProvider);
        if (user == null) return;
        // عکس پروفایل فعلی کاربر — روی پست ثبت می‌شود تا هویت واقعی نمایان باشد.
        final photoBytes = ref.read(profilePhotoProvider);
        await ref.read(createPostUseCaseProvider).call(CreatePostParams(
              authorId: user.id,
              authorName: user.displayName,
              authorIsAdmin: user.role == AppUserRole.superAdmin,
              authorAvatarBase64: photoBytes != null ? base64Encode(photoBytes) : null,
              body: text,
              imagesBase64: _images,
            ));
      }
      ref.read(memoryPostsRefreshProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = context.tr('memory.submitFailed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEdit ? context.tr('memory.editStoryTitle') : context.tr('memory.newStoryTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _controller,
                          maxLines: 6,
                          minLines: 4,
                          maxLength: 4000,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            hintText: context.tr('memory.composerHint'),
                            filled: true,
                            fillColor: scheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 84,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _images.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) => Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                    child: Image.memory(base64Decode(_images[i]),
                                        width: 84, height: 84, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: InkWell(
                                      onTap: () => setState(() => _images.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickingImage ? null : _pickImage,
                              icon: _pickingImage
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.image_outlined, size: 18),
                              label: Text(context.tr('memory.addPhoto')),
                            ),
                            const SizedBox(width: 8),
                            Text('${_images.length}/$_maxImagesPerPost',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12.5)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isEdit ? Icons.check_rounded : Icons.send_rounded, size: 20),
                    label: Text(_submitting
                        ? context.tr('memory.submitting')
                        : (_isEdit ? context.tr('memory.saveChanges') : context.tr('memory.publishStory'))),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

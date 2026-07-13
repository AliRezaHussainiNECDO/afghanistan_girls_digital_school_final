import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/permissions/permissions_sheet.dart';
import '../../../../core/student/guardian_link_store.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../parent_dashboard/presentation/providers/guardian_link_providers.dart';
import '../../domain/repositories/profile_repository.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _generatedCode;
  bool _generating = false;
  bool _pickingPhoto = false;

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        // ۱) پیش‌نمایش فوری محلی.
        ref.read(profilePhotoProvider.notifier).state = bytes;
        // ۲) آپلود روی سرور (R2) تا در همهٔ دستگاه‌ها و همهٔ بخش‌ها دیده شود.
        final mime = (file.mimeType != null && file.mimeType!.startsWith('image/'))
            ? file.mimeType!
            : 'image/jpeg';
        final url = await ref
            .read(authSessionProvider.notifier)
            .uploadAvatar(bytes, mime);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(url != null
                ? context.tr('profile.photoUpdated')
                : (ref.read(authSessionProvider.notifier).lastError ??
                    context.tr('common.error'))),
          ));
        }
      }
    } catch (_) {
      // در وب/دسکتاپ در صورت نبود مجوز دسترسی، بی‌صدا نادیده گرفته می‌شود.
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  /// نمایش کد دعوت والدین (بخش ۲.۴ سند): کد بزرگ + دکمهٔ کاپی + توضیح
  /// نحوهٔ استفاده توسط والد. اگر چند فرزند در برنامه باشند، هر فرزند کد
  /// خودش را می‌سازد و والد همهٔ کدها را یکی‌یکی وارد می‌کند (بخش ۱۳ب.۵).
  Future<void> _showInviteCodeDialog(GuardianInviteCode invite) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.family_restroom_rounded, color: scheme.secondary),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('profile.guardianInvite'))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.secondary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    invite.code.split('').join(' '),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'این کد را به پدر یا مادر خود بدهید. آن‌ها پس از ورود به حساب والد، '
                'در «داشبورد والدین» این کد را وارد می‌کنند تا به پیشرفت و نمرات شما '
                'دسترسی فقط‌خواندنی پیدا کنند.',
                style: TextStyle(fontSize: 12.5, height: 1.8, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.timer_outlined, size: 15, color: scheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('اعتبار: ${invite.remainingHours} ساعت (۷۲ ساعت از زمان ساخت)',
                      style: TextStyle(fontSize: 12, color: scheme.tertiary)),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('common.close')),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('کاپی کد'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('کد دعوت کاپی شد')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditProfileDialog(AppUser user) async {
    final nameController = TextEditingController(text: user.displayName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('profile.editProfile')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(labelText: context.tr('profile.displayName')),
            validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('common.required') : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              ref.read(authSessionProvider.notifier).updateDisplayName(nameController.text);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(context.tr('profile.profileUpdated'))));
            },
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('profile.changePassword')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('profile.currentPassword')),
                validator: (v) => (v == null || v.isEmpty) ? context.tr('common.required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('profile.newPassword')),
                validator: (v) =>
                    (v == null || v.length < 6) ? context.tr('common.required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('profile.confirmPassword')),
                validator: (v) =>
                    (v != newController.text) ? context.tr('profile.passwordMismatch') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              // فاز ۱: بدون بک‌اند واقعی — فقط شبیه‌سازی موفقیت‌آمیز بودن عملیات.
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(context.tr('profile.passwordChanged'))));
            },
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('nav.profile'),
      role: user?.role ?? AppUserRole.student,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.warm,
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickingPhoto ? null : _pickPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                        ),
                        child: UserAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          foregroundColor: scheme.primary,
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: scheme.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _pickingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.displayName ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _pickingPhoto ? null : _pickPhoto,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: Text(context.tr('profile.changePhoto'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.edit_rounded,
              color: scheme.primary,
              title: context.tr('profile.editProfile'),
              onTap: user == null ? null : () => _showEditProfileDialog(user),
            ),
            _SettingsTile(
              icon: Icons.lock_rounded,
              color: scheme.secondary,
              title: context.tr('profile.changePassword'),
              onTap: _showChangePasswordDialog,
            ),
          ]),
          const SizedBox(height: 16),

          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.language_rounded,
              color: scheme.tertiary,
              title: context.tr('common.language'),
              trailing: DropdownButton<Locale>(
                value: locale,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: Locale('fa'), child: Text('دری')),
                  DropdownMenuItem(value: Locale('ps'), child: Text('پښتو')),
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(localeProvider.notifier).setLocale(v);
                },
              ),
            ),
            _SettingsTile(
              icon: Icons.brightness_6_rounded,
              color: scheme.tertiary,
              title: context.tr('common.theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: ThemeMode.light, child: Text(context.tr('common.lightMode'))),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(context.tr('common.darkMode'))),
                  DropdownMenuItem(value: ThemeMode.system, child: Text(context.tr('common.systemMode'))),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(themeModeProvider.notifier).setThemeMode(v);
                },
              ),
            ),
            _SettingsTile(
              icon: Icons.verified_user_rounded,
              color: scheme.primary,
              title: 'دسترسی‌های دستگاه',
              subtitle: 'دوربین، میکروفون، گالری، اعلان‌ها',
              trailing: Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
              onTap: () => PermissionsSheet.show(context),
            ),
          ]),

          if (user?.role == AppUserRole.student) ...[
            const SizedBox(height: 16),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.family_restroom_rounded,
                color: scheme.secondary,
                title: context.tr('profile.guardianInvite'),
                subtitle: _generatedCode ?? 'کد ۶ رقمی با ۷۲ ساعت اعتبار، برای اتصال والدین',
                trailing: _generating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.qr_code_rounded, color: scheme.onSurfaceVariant),
                onTap: () async {
                  // طبق بخش ۲.۴ سند: کد در GuardianLinkStore ثبت می‌شود تا والد
                  // واقعاً بتواند با آن متصل شود. نام و صنف شاگرد هم همراه کد
                  // ذخیره می‌شود تا پس از لینک، معلومات درست فرزند نمایش یابد.
                  final student = user!;
                  setState(() => _generating = true);
                  final result = await ref.read(generateGuardianInviteCodeUseCaseProvider).call(
                        GuardianInviteParams(
                          studentId: student.id,
                          studentName:
                              student.displayName.isEmpty ? 'شاگرد' : student.displayName,
                          grade: ref.read(activeGradeProvider),
                        ),
                      );
                  if (!mounted) return;
                  setState(() => _generating = false);
                  result.fold(
                    (f) => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(f.message))),
                    (invite) {
                      setState(() => _generatedCode = invite.code);
                      _showInviteCodeDialog(invite);
                    },
                  );
                },
              ),
            ]),
            // ── درخواست‌های پیوند والدین، در انتظار تأیید شاگرد ──
            // (بخش ۱۳ب.۲ سند: پیوند تا تأیید خود شاگرد فعال نمی‌شود — حافظ
            // عاملیت/agency شاگرد. در حالت Live از سرور خوانده می‌شود.)
            Consumer(
              builder: (context, ref, _) {
                final requests =
                    ref.watch(pendingParentLinksProvider).asData?.value ?? const [];
                if (requests.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _SettingsGroup(children: [
                    for (final r in requests)
                      _SettingsTile(
                        icon: Icons.family_restroom_rounded,
                        color: scheme.tertiary,
                        title: 'درخواست پیوند والد',
                        subtitle: r.parentName.isEmpty
                            ? 'یک والد/سرپرست با کد دعوت شما درخواست اتصال داده است'
                            : '«${r.parentName}» با کد دعوت شما درخواست اتصال داده است',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'تأیید',
                              icon: Icon(Icons.check_circle_rounded,
                                  color: scheme.primary),
                              onPressed: () async {
                                final err = await respondToParentLink(ref,
                                    link: r, approve: true);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(err ??
                                          'پیوند تأیید شد؛ والد شما اکنون خلاصهٔ پیشرفت‌تان را می‌بیند')),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'رد',
                              icon: Icon(Icons.cancel_rounded, color: scheme.error),
                              onPressed: () async {
                                final err = await respondToParentLink(ref,
                                    link: r, approve: false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err ?? 'درخواست پیوند رد شد')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ]),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.logout_rounded,
              color: scheme.error,
              title: context.tr('common.logout'),
              onTap: () async {
                await ref.read(authSessionProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            ),
          ]),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ListTile افکت لمس خود را روی نزدیک‌ترین Material رسم می‌کند؛ بنابراین
    // به‌جای Container رنگی، خود Material را رنگ و قاب می‌دهیم تا هشدار
    // «ListTile background color may be invisible» رفع شود.
    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontWeight: FontWeight.w700)) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

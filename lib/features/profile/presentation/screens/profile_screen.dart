import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/permissions/permissions_sheet.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/info_stat_chip.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../admin/dashboard/presentation/providers/admin_dashboard_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../instructor/presentation/providers/instructor_providers.dart';
import '../../../parent_dashboard/presentation/providers/guardian_link_providers.dart';
import '../../../parent_dashboard/presentation/providers/parent_providers.dart';
import '../../../student_dashboard/presentation/providers/dashboard_providers.dart';
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
                dialogContext.tr('profile.guardianInviteExplain'),
                style: TextStyle(fontSize: 12.5, height: 1.8, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.timer_outlined, size: 15, color: scheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      dialogContext.tr('profile.inviteCodeValidity',
                          {'hours': '${invite.remainingHours}'}),
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
              label: Text(dialogContext.tr('profile.copyCode')),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(context.tr('profile.inviteCodeCopied'))));
              },
            ),
          ],
        );
      },
    );
  }

  /// دیالوگ ویرایش نام — رفع اشکال طراحی: قبلاً یک فیلد «نام نمایشی» واحد
  /// بود که هنگام ذخیره روی اولین فاصله به نام/تخلص تقسیم می‌شد (برای
  /// تخلص‌های چندبخشی نادرست بود). اکنون نام و تخلص جداگانه — همان دو
  /// فیلد واقعیِ جدول `users` (`first_name`/`last_name`) — گرفته و مستقیماً
  /// با [AuthSessionNotifier.updateProfileName] روی سرور ذخیره می‌شود.
  Future<void> _showEditProfileDialog(AppUser user) async {
    final firstNameController = TextEditingController(
      text: user.firstName.trim().isNotEmpty ? user.firstName : user.displayName,
    );
    final lastNameController = TextEditingController(text: user.lastName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('profile.editProfile')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: context.tr('profile.firstName')),
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('common.required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: context.tr('profile.lastName')),
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
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final ok = await ref.read(authSessionProvider.notifier).updateProfileName(
                    firstName: firstNameController.text,
                    lastName: lastNameController.text,
                  );
              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? context.tr('profile.profileUpdated')
                    : (ref.read(authSessionProvider.notifier).lastError ??
                        context.tr('common.error'))),
              ));
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
                // حداقل ۸ کاراکتر — هماهنگ با حداقل واقعیِ سرور (auth.ts
                // /change-password و /reset-password)، تا کاربر پیش از
                // فرستادن درخواست رد نشود.
                validator: (v) =>
                    (v == null || v.length < 8) ? context.tr('common.required') : null,
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
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final notifier = ref.read(authSessionProvider.notifier);
              final ok = await notifier.changePassword(
                currentPassword: currentController.text,
                newPassword: newController.text,
              );
              if (!mounted) return;
              Navigator.of(context).pop();
              if (ok) {
                // سرور همهٔ نشست‌ها (این دستگاه هم) را باطل کرده؛ کاربر باید
                // با رمز تازه دوباره وارد شود.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('profile.passwordChanged'))),
                );
                context.go(AppRoutes.login);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(notifier.lastError ?? context.tr('common.error')),
                ));
              }
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: AppColors.sunriseGradient,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.warm,
            ),
            child: Stack(
              children: [
                // ── دایره‌های تزئینیِ محوِ پس‌زمینه — همان زبان طراحیِ سربرگ
                // منوی کناری، تا کارت پروفایل و Drawer یک حس یکدست بدهند. ──
                Positioned(
                  top: -34,
                  left: -20,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
                  ),
                ),
                Positioned(
                  bottom: -44,
                  right: -26,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
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
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: UserAvatar(
                                radius: 38,
                                backgroundColor: Colors.white,
                                foregroundColor: scheme.primary,
                              ),
                            ).animate().scale(
                                  begin: const Offset(0.6, 0.6),
                                  end: const Offset(1, 1),
                                  duration: 420.ms,
                                  curve: Curves.easeOutBack,
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
                      Text(
                        (user?.fullName.trim().isNotEmpty ?? false) ? user!.fullName : (user?.displayName ?? ''),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ).animate().fadeIn(delay: 100.ms, duration: 280.ms),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                      const SizedBox(height: 6),
                      // ── نشان تأیید ایمیل — وضعیت واقعیِ `emailVerified` ──
                      if (user != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                user.emailVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.emailVerified ? context.tr('profile.verified') : context.tr('profile.notVerified'),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                              if (!user.emailVerified) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => ref.read(authSessionProvider.notifier).resendVerification(),
                                  child: Text(
                                    context.tr('auth.resendVerification'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ).animate().fadeIn(delay: 160.ms, duration: 280.ms),
                      // ── آمار نقش‌محور — طبق منطق همان داشبورد، از منبع
                      // واقعیِ سرور (نه دادهٔ ساختگی). ──
                      if (user != null) ...[
                        const SizedBox(height: 16),
                        _ProfileStatsRow(user: user),
                      ],
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _pickingPhoto ? null : _pickPhoto,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: Text(context.tr('profile.changePhoto'), style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 20),

          _SectionLabel(icon: Icons.manage_accounts_rounded, text: context.tr('profile.accountSection')),
          const SizedBox(height: 8),
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
          ]).animate().fadeIn(delay: 60.ms, duration: 300.ms).slideY(begin: 0.06, end: 0, duration: 300.ms),
          const SizedBox(height: 16),

          _SectionLabel(icon: Icons.tune_rounded, text: context.tr('profile.preferencesSection')),
          const SizedBox(height: 8),
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
                  DropdownMenuItem(value: Locale('fr'), child: Text('Français')),
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
              title: context.tr('profile.devicePermissions'),
              subtitle: context.tr('profile.devicePermissionsSubtitle'),
              trailing: Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
              onTap: () => PermissionsSheet.show(context),
            ),
          ]).animate().fadeIn(delay: 110.ms, duration: 300.ms).slideY(begin: 0.06, end: 0, duration: 300.ms),

          if (user?.role == AppUserRole.student) ...[
            const SizedBox(height: 16),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.family_restroom_rounded,
                color: scheme.secondary,
                title: context.tr('profile.guardianInvite'),
                subtitle: _generatedCode ?? context.tr('profile.guardianInviteSubtitle'),
                trailing: _generating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.qr_code_rounded, color: scheme.onSurfaceVariant),
                onTap: () async {
                  // طبق بخش ۲.۴ سند: کد (در حالت Live روی سرور، در حالت Mock در GuardianLinkMockStore) ثبت می‌شود تا والد
                  // واقعاً بتواند با آن متصل شود. نام و صنف شاگرد هم همراه کد
                  // ذخیره می‌شود تا پس از لینک، معلومات درست فرزند نمایش یابد.
                  final student = user!;
                  setState(() => _generating = true);
                  final result = await ref.read(generateGuardianInviteCodeUseCaseProvider).call(
                        GuardianInviteParams(
                          studentId: student.id,
                          studentName: student.displayName.isEmpty
                              ? context.tr('profile.studentFallback')
                              : student.displayName,
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
                        title: context.tr('profile.parentLinkRequestTitle'),
                        subtitle: r.parentName.isEmpty
                            ? context.tr('profile.parentLinkRequestGeneric')
                            : context.tr('profile.parentLinkRequestNamed', {'name': r.parentName}),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: context.tr('common.confirm'),
                              icon: Icon(Icons.check_circle_rounded,
                                  color: scheme.primary),
                              onPressed: () async {
                                final err = await respondToParentLink(ref,
                                    link: r, approve: true);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(err ??
                                          context.tr('profile.linkApprovedNotice'))),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: context.tr('profile.reject'),
                              icon: Icon(Icons.cancel_rounded, color: scheme.error),
                              onPressed: () async {
                                final err = await respondToParentLink(ref,
                                    link: r, approve: false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err ?? context.tr('profile.linkRejectedNotice'))),
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
          ]).animate().fadeIn(delay: 160.ms, duration: 300.ms).slideY(begin: 0.06, end: 0, duration: 300.ms),
        ],
      ),
    );
  }
}

/// برچسب سربخش — طبق درخواست کاربر برای نمایی «پیشرفته‌تر»، بخش پروفایل
/// اکنون به‌جای فهرست پیوستهٔ کارت‌ها، با عنوان‌های کوچک گروه‌بندی می‌شود
/// (حساب کاربری / ترجیحات برنامه).
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// ردیف آمار نقش‌محورِ کارت سربرگ پروفایل — منطق هر داشبورد را دقیقاً
/// همان‌جا که قبلاً برای Drawer تعریف شد دنبال می‌کند، فقط با چیدمانِ
/// درشت‌تر و مناسب صفحهٔ پروفایل:
///   • شاگرد: صنف، امتیاز فعالیت، سطح، تعداد گواهی‌نامه‌ها.
///   • والد: تعداد فرزندان متصل‌شدهٔ تأییدشده.
///   • مدیر کل: شاگردان ثبت‌نامی، فعال امروز، در معرض خطر.
///   • استاد سمینار: تعداد سمینارهای خودش.
class _ProfileStatsRow extends ConsumerWidget {
  final AppUser user;
  const _ProfileStatsRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (user.role) {
      case AppUserRole.student:
        final summaryAsync = ref.watch(dashboardSummaryProvider(user.id));
        return summaryAsync.when(
          loading: () => const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [InfoStatChipSkeleton(light: true), InfoStatChipSkeleton(light: true)],
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (summary) => Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              InfoStatChip(
                icon: Icons.school_rounded,
                light: true,
                label: context.tr('profile.grade'),
                value: user.currentGrade != null ? '${user.currentGrade}' : '—',
              ),
              InfoStatChip(
                icon: Icons.military_tech_rounded,
                light: true,
                label: context.tr('profile.points'),
                value: '${summary.pointsTotal}',
              ),
              InfoStatChip(
                icon: Icons.trending_up_rounded,
                light: true,
                label: context.tr('profile.level'),
                value: '${summary.pointsLevel}',
              ),
              InfoStatChip(
                icon: Icons.workspace_premium_rounded,
                light: true,
                label: context.tr('parent.certificates'),
                value: '${summary.certificatesCount}',
              ),
            ],
          ),
        );

      case AppUserRole.parent:
        final childrenAsync = ref.watch(linkedChildrenProvider);
        return childrenAsync.when(
          loading: () => const InfoStatChipSkeleton(light: true),
          error: (_, __) => const SizedBox.shrink(),
          data: (children) => InfoStatChip(
            icon: Icons.family_restroom_rounded,
            light: true,
            label: context.tr('profile.linkedChildren'),
            value: '${children.length}',
          ),
        );

      case AppUserRole.superAdmin:
        final statsAsync = ref.watch(adminStatsProvider);
        return statsAsync.when(
          loading: () => const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [InfoStatChipSkeleton(light: true), InfoStatChipSkeleton(light: true)],
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              InfoStatChip(
                icon: Icons.groups_rounded,
                light: true,
                label: context.tr('admin.totalStudents'),
                value: '${stats.totalStudents}',
              ),
              InfoStatChip(
                icon: Icons.bolt_rounded,
                light: true,
                label: context.tr('admin.activeToday'),
                value: '${stats.activeToday}',
              ),
              InfoStatChip(
                icon: Icons.warning_amber_rounded,
                light: true,
                label: context.tr('admin.atRisk'),
                value: '${stats.atRiskCount}',
              ),
            ],
          ),
        );

      case AppUserRole.seminarInstructor:
        final seminarsAsync = ref.watch(myInstructorSeminarsProvider);
        return seminarsAsync.when(
          loading: () => const InfoStatChipSkeleton(light: true),
          error: (_, __) => const SizedBox.shrink(),
          data: (seminars) => InfoStatChip(
            icon: Icons.groups_rounded,
            light: true,
            label: context.tr('profile.mySeminars'),
            value: '${seminars.length}',
          ),
        );
    }
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

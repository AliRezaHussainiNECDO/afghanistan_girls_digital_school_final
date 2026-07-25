import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/admin_manager.dart';
import '../providers/admin_management_providers.dart';
import 'admin_activity_screen.dart';

/// «مدیریت مدیران» — فقط Super Admin: ساخت مدیر زیرمجموعه (role='admin') و
/// تعیین دقیق دسته‌های دسترسی هرکدام (backend: routes/admin.ts `/admin/admins/*`،
/// جدول admin_permissions — Migration 0044). دسترسی این صفحه هم سمت کلاینت
/// (app_router.dart) و هم — مهم‌تر — سمت سرور (requireSuperAdminOnly) قفل است.
class AdminManagementScreen extends ConsumerWidget {
  const AdminManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(adminManagersProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('admin.management'),
      role: AppUserRole.superAdmin,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAdminDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(context.tr('admin.addAdmin')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminManagersProvider),
        child: adminsAsync.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(error: e, onRetry: () => ref.invalidate(adminManagersProvider)),
          data: (admins) {
            if (admins.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 60),
                  Icon(Icons.admin_panel_settings_outlined, size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      context.tr('admin.noAdmins'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: admins.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _AdminCard(admin: admins[i]),
            );
          },
        ),
      ),
    );
  }

  void _showCreateAdminDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _CreateAdminDialog(),
    );
  }
}

class _AdminCard extends ConsumerWidget {
  final AdminManager admin;
  const _AdminCard({required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AdminActivityScreen(admin: admin)),
        ),
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    admin.name.isNotEmpty ? admin.name.substring(0, 1) : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.name.isEmpty ? admin.email : admin.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(admin.email, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (admin.suspended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    context.tr('admin.suspended'),
                    style: TextStyle(fontSize: 10.5, color: scheme.onErrorContainer, fontWeight: FontWeight.w700),
                  ),
                ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: admin.permissions.isEmpty
                ? [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(context.tr('admin.permissionsLabel')),
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ]
                : admin.permissions
                    .map((p) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(context.tr('admin.permission.$p'), style: const TextStyle(fontSize: 11)),
                          backgroundColor: scheme.primaryContainer,
                          labelStyle: TextStyle(color: scheme.onPrimaryContainer),
                        ))
                    .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _EditPermissionsDialog(admin: admin),
                ),
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: Text(context.tr('admin.editPermissions')),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () async {
                  final repo = ref.read(adminManagementRepositoryProvider);
                  final result = await repo.toggleSuspend(admin.id);
                  result.fold(
                    (f) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
                      }
                    },
                    (_) => ref.invalidate(adminManagersProvider),
                  );
                },
                icon: Icon(
                  admin.suspended ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 17,
                  color: admin.suspended ? AppColors.green600 : scheme.error,
                ),
                label: Text(
                  admin.suspended ? context.tr('admin.activateAdmin') : context.tr('admin.suspendAdmin'),
                  style: TextStyle(color: admin.suspended ? AppColors.green600 : scheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// چک‌باکس‌های دسته‌بندی دسترسی — در دو دیالوگ (ساخت/ویرایش) استفاده مجدد می‌شود.
class _PermissionCheckboxes extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const _PermissionCheckboxes({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: kAllAdminPermissions.map((p) {
        final checked = selected.contains(p);
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: checked,
          title: Text(context.tr('admin.permission.$p'), style: const TextStyle(fontSize: 13.5)),
          onChanged: (v) {
            final next = Set<String>.from(selected);
            if (v == true) {
              next.add(p);
            } else {
              next.remove(p);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _CreateAdminDialog extends ConsumerStatefulWidget {
  const _CreateAdminDialog();

  @override
  ConsumerState<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends ConsumerState<_CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  Set<String> _permissions = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(adminManagementRepositoryProvider);
    final result = await repo.createAdmin(
      email: _email.text.trim(),
      password: _password.text,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      permissions: _permissions.toList(),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _saving = false;
        _error = f.message;
      }),
      (_) {
        ref.invalidate(adminManagersProvider);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('admin.addAdmin')),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        decoration: InputDecoration(labelText: context.tr('admin.adminFirstName')),
                        validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('common.required') : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        decoration: InputDecoration(labelText: context.tr('admin.adminLastName')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: context.tr('admin.adminEmail')),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? context.tr('common.required') : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: context.tr('admin.adminPassword')),
                  validator: (v) => (v == null || v.length < 8) ? context.tr('common.required') : null,
                ),
                const SizedBox(height: 14),
                Text(context.tr('admin.permissionsLabel'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                _PermissionCheckboxes(
                  selected: _permissions,
                  onChanged: (next) => setState(() => _permissions = next),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(context.tr('common.save')),
        ),
      ],
    );
  }
}

class _EditPermissionsDialog extends ConsumerStatefulWidget {
  final AdminManager admin;
  const _EditPermissionsDialog({required this.admin});

  @override
  ConsumerState<_EditPermissionsDialog> createState() => _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends ConsumerState<_EditPermissionsDialog> {
  late Set<String> _permissions = Set<String>.from(widget.admin.permissions);
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(adminManagementRepositoryProvider);
    final result = await repo.updatePermissions(widget.admin.id, _permissions.toList());
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _saving = false;
        _error = f.message;
      }),
      (_) {
        ref.invalidate(adminManagersProvider);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.admin.name.isEmpty ? widget.admin.email : widget.admin.name),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PermissionCheckboxes(
                selected: _permissions,
                onChanged: (next) => setState(() => _permissions = next),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(context.tr('common.save')),
        ),
      ],
    );
  }
}

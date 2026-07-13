import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingSeenKey = 'onboarding_seen_v1';

/// آیا کاربر صفحات خوش‌آمدید/معرفی برنامه را قبلاً دیده است؟
/// null = هنوز از حافظه خوانده نشده، false = ندیده، true = دیده.
class OnboardingNotifier extends StateNotifier<bool?> {
  OnboardingNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> markSeen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }
}

final onboardingSeenProvider =
    StateNotifierProvider<OnboardingNotifier, bool?>((ref) => OnboardingNotifier());

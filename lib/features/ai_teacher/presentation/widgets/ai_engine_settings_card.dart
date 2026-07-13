import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../providers/ai_engine_settings_provider.dart';

/// کارت تنظیمات موتور معلم هوشمند در پنل مدیریت — به‌صورت پیش‌فرض خاموش
/// (موتور محلی رایگان فعال است). با فعال‌سازی این گزینه و نصب Ollama روی
/// کامپیوتر مدیر، پاسخ‌ها توسط هوش مصنوعی واقعی تولید می‌شود.
class AiEngineSettingsCard extends ConsumerStatefulWidget {
  const AiEngineSettingsCard({super.key});

  @override
  ConsumerState<AiEngineSettingsCard> createState() => _AiEngineSettingsCardState();
}

class _AiEngineSettingsCardState extends ConsumerState<AiEngineSettingsCard> {
  late TextEditingController _urlController;
  late TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiEngineSettingsProvider);
    _urlController = TextEditingController(text: s.baseUrl);
    _modelController = TextEditingController(text: s.model);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiEngineSettingsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.sunriseGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('موتور هوش مصنوعی (Ollama محلی)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Switch(
                value: settings.useOllama,
                activeThumbColor: Colors.white,
                onChanged: (v) => ref.read(aiEngineSettingsProvider.notifier).update(useOllama: v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            settings.useOllama
                ? 'فعال — پاسخ‌ها ابتدا از Ollama گرفته می‌شود؛ اگر در دسترس نباشد، به‌طور خودکار به موتور محلی رایگان برمی‌گردد.'
                : 'خاموش — معلم هوشمند از موتور محلی رایگان (بدون نیاز به نصب چیزی) استفاده می‌کند. برای فعال‌سازی هوش مصنوعی واقعی: نصب Ollama از ollama.com، سپس دستور «ollama pull llama3.1» در ترمینال، سپس این گزینه را روشن کنید.',
            style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.6),
          ),
          if (settings.useOllama) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniField(
                    label: 'آدرس سرور',
                    controller: _urlController,
                    onSubmitted: (v) =>
                        ref.read(aiEngineSettingsProvider.notifier).update(baseUrl: v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniField(
                    label: 'نام مدل',
                    controller: _modelController,
                    onSubmitted: (v) =>
                        ref.read(aiEngineSettingsProvider.notifier).update(model: v.trim()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  const _MiniField({required this.label, required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      onTapOutside: (_) => onSubmitted(controller.text),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }
}

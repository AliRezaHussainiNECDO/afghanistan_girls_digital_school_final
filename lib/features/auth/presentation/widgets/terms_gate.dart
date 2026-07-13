import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';

/// متن کامل قوانین و شرایط استفاده + سیاست حریم خصوصی — طبق الزامات Google
/// Play و App Store برای اپ‌های دارای کاربر خردسال (کودکان زیر ۱۸ سال).
/// در فاز ۱ فقط به زبان دری نوشته شده؛ ترجمهٔ کامل به پشتو/انگلیسی در فاز
/// بعدی اضافه می‌شود.
const String kTermsAndPrivacyText = '''
۱. دربارهٔ این برنامه
«مکتب دیجیتال دختران افغانستان» یک پلتفرم آموزشی رایگان است که برای کمک به دختران افغان در ادامهٔ یادگیری ساخته شده. با ثبت‌نام در این برنامه، شما (یا در صورتی که زیر ۱۸ سال دارید، والد/سرپرست شما) این قوانین را می‌پذیرید.

۲. چه معلوماتی جمع‌آوری می‌شود
نام، تاریخ تولد، ولایت، صنف تحصیلی، شمارهٔ تماس یا ایمیل (اختیاری)، پیشرفت درسی، نتایج امتحانات، و پیام‌های ارسالی در بخش چت و معلم هوشمند. این معلومات فقط برای ارائهٔ خدمات آموزشی، پیگیری پیشرفت شاگرد و ارتباط با مکتب استفاده می‌شود و هرگز به شرکت‌های تبلیغاتی فروخته نمی‌شود.

۳. ایمنی کودکان و نوجوانان
این برنامه توسط دختران خردسال نیز استفاده می‌شود. به همین دلیل:
  • تمام پیام‌های چت (متنی و صوتی) برای جلوگیری از سوءاستفاده یا محتوای نامناسب توسط سیستم و تیم مدیریت بازبینی می‌شود.
  • کاربران نمی‌توانند اطلاعات تماس شخصی حساس (مانند آدرس دقیق) را در چت به اشتراک بگذارند.
  • هرگونه پیام مشکوک یا آزاردهنده باید فوراً از طریق دکمهٔ «گزارش تخلف» گزارش شود.
  • حساب والدین می‌تواند به حساب فرزند متصل شود تا پیشرفت او را ببیند.

۴. معلم هوشمند (هوش مصنوعی)
پاسخ‌های «معلم هوشمند» بر اساس محتوای کتاب‌های درسی رسمی نصاب تعلیمی افغانستان تولید می‌شود. این پاسخ‌ها ممکن است گاهی ناقص یا نادرست باشند؛ همیشه با معلم واقعی یا کتاب درسی مطابقت دهید. مکالمات با معلم هوشمند برای بهبود کیفیت آموزش ذخیره و بازبینی می‌شود.

۵. رفتار کاربران
استفاده از زبان توهین‌آمیز، تبلیغاتی، سیاسی یا مزاحم در چت و معلم هوشمند ممنوع است. تخلف مکرر می‌تواند به مسدود شدن حساب منجر شود.

۶. حقوق شما
شما (یا والد/سرپرست شما) هر زمان می‌توانید درخواست مشاهده، اصلاح یا حذف کامل معلومات خود را از طریق پروفایل یا با تماس از طریق پشتیبانی مطرح کنید.

۷. تماس با ما
پشتیبانی: support@afghanistangirlsdigitalschool.org

با علامت‌زدن گزینهٔ زیر و ادامهٔ ثبت‌نام، شما تأیید می‌کنید که این قوانین را خوانده و با آن موافق هستید.
''';

/// دیالوگ تمام‌صفحه برای مطالعهٔ کامل قوانین و شرایط.
Future<void> showTermsDialog(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('terms.title'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Text(
                  kTermsAndPrivacyText,
                  style: TextStyle(height: 1.9, fontSize: 14, color: scheme.onSurface),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('common.close')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// چک‌باکس پذیرش قوانین — در فرم ثبت‌نام دانش‌آموز و والدین استفاده می‌شود.
class TermsConsentField extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool showError;

  const TermsConsentField({
    super.key,
    required this.accepted,
    required this.onChanged,
    this.showError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => onChanged(!accepted),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: accepted,
                  onChanged: (v) => onChanged(v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.5),
                        children: [
                          TextSpan(text: '${context.tr('terms.acceptPrefix')} '),
                          TextSpan(
                            text: context.tr('terms.viewFull'),
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: (TapGestureRecognizer()
                              ..onTap = () => showTermsDialog(context)),
                          ),
                          TextSpan(text: ' ${context.tr('terms.acceptSuffix')}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showError && !accepted)
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 12),
            child: Text(
              context.tr('terms.mustAccept'),
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

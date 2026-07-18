import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';

/// متن کامل قوانین و شرایط استفاده + سیاست حریم خصوصی — طبق الزامات Google
/// Play و App Store برای اپ‌های دارای کاربر خردسال (کودکان زیر ۱۸ سال).
/// اکنون هر چهار زبان (دری/پښتو/English/Français) کامل نوشته شده و بر اساس
/// زبان فعال برنامه انتخاب می‌شود — [termsAndPrivacyText].
///
/// ⚠️ این یک متن حقوقی/رعایتی (Legal/Compliance) است — پیشنهاد می‌شود پیش
/// از انتشار نهایی، هر سه ترجمهٔ جدید (پشتو/انگلیسی/فرانسوی) توسط یک
/// حقوق‌دان یا گویشور بومی همان زبان بازبینی شود.
String termsAndPrivacyText(BuildContext context) {
  switch (AppLocalizations.of(context).locale.languageCode) {
    case 'ps':
      return _kTermsPs;
    case 'en':
      return _kTermsEn;
    case 'fr':
      return _kTermsFr;
    case 'fa':
    default:
      return _kTermsFa;
  }
}

const String _kTermsFa = '''
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

const String _kTermsPs = '''
۱. د دې اپلیکیشن په اړه
«د افغان نجونو ډیجیټل ښوونځی» یو وړیا زده‌کړیز پلیټ‌فورم دی چې د افغان نجونو د زده‌کړې دوام لپاره جوړ شوی. په دې اپلیکیشن کې د نوم لیکنې سره، تاسو (یا که تاسو د ۱۸ کلونو څخه کم عمر لرئ، ستاسو مور/پلار یا سرپرست) دا قوانین منئ.

۲. کوم معلومات راټولیږي
نوم، د زیږون نیټه، ولایت، زده‌کړیز ټولګی، د تماس شمېره یا بریښنالیک (اختیاري)، زده‌کړیز پرمختګ، د ازموینو پایلې، او په چیټ او هوښیار ښوونکي برخو کې لیږل شوي پیغامونه. دا معلومات یوازې د زده‌کړیزو خدماتو وړاندې کولو، د زده‌کوونکي پرمختګ تعقیبولو، او له ښوونځي سره اړیکې لپاره کارول کیږي او هیڅکله د اعلاناتو شرکتونو ته نه پلورل کیږي.

۳. د ماشومانو او ځوانانو خوندیتوب
دا اپلیکیشن د کوچنیو نجونو لخوا هم کارول کیږي. له همدې امله:
  • ټول چیټ پیغامونه (متني او غږیز) د ناوړه ګټې اخیستنې یا نامناسب محتوا مخنیوي لپاره د سیسټم او مدیریت ټیم لخوا کتل کیږي.
  • کاروونکي نشي کولی حساس شخصي د تماس معلومات (لکه دقیق پته) په چیټ کې شریک کړي.
  • هر ډول شکمن یا ځورونکی پیغام باید سمدلاسه د «تخلف راپور» تڼۍ له لارې راپور شي.
  • د مور/پلار حساب کولی شي د ماشوم حساب سره وتړل شي ترڅو د هغې پرمختګ وویني.

۴. هوښیار ښوونکی (مصنوعي هوښیارتیا)
د «هوښیار ښوونکي» ځوابونه د افغانستان د رسمي نصاب درسي کتابونو محتوا پر بنسټ جوړیږي. دا ځوابونه ځینې وختونه ناقص یا غلط کیدای شي؛ تل یې د یو ریښتیني ښوونکي یا درسي کتاب سره سمون ورکړئ. د هوښیار ښوونکي سره خبرې اترې د زده‌کړې کیفیت ښه کولو لپاره خوندي او کتل کیږي.

۵. د کاروونکو چلند
په چیټ او هوښیار ښوونکي کې د سپکاوي، تبلیغاتي، سیاسي یا ځورونکي ژبې کارول منع دي. مکرر تخلف کولی شي ستاسو حساب بند کړي.

۶. ستاسو حقونه
تاسو (یا ستاسو مور/پلار) کولی شئ هر وخت د خپلو معلوماتو کتلو، سمولو، یا بشپړ ړنګولو غوښتنه د پروفایل له لارې یا د ملاتړ سره اړیکه نیولو سره وکړئ.

۷. زموږ سره اړیکه
ملاتړ: support@afghanistangirlsdigitalschool.org

د لاندې انتخاب په نښه کولو او د نوم لیکنې په دوام ورکولو سره، تاسو تایید کوئ چې دا قوانین مو لوستلي او ورسره موافق یاست.
''';

const String _kTermsEn = '''
1. About this app
"Afghanistan Girls Digital School" is a free educational platform built to help Afghan girls continue their education. By registering for this app, you (or your parent/guardian, if you are under 18) agree to these terms.

2. What information we collect
Name, date of birth, province, grade level, phone number or email (optional), academic progress, exam results, and messages sent in the chat and AI Teacher sections. This information is used only to provide educational services, track student progress, and communicate with the school, and is never sold to advertisers.

3. Child and teen safety
This app is also used by young girls. For this reason:
  • All chat messages (text and voice) are reviewed by the system and the management team to prevent abuse or inappropriate content.
  • Users cannot share sensitive personal contact information (such as a precise address) in chat.
  • Any suspicious or harassing message must be reported immediately using the "Report" button.
  • A parent account can be linked to a child's account to view their progress.

4. AI Teacher (artificial intelligence)
Responses from the "AI Teacher" are generated based on the content of Afghanistan's official curriculum textbooks. These responses may sometimes be incomplete or incorrect; always verify with a real teacher or textbook. Conversations with the AI Teacher are stored and reviewed to improve education quality.

5. User conduct
Using offensive, promotional, political, or harassing language in chat and with the AI Teacher is prohibited. Repeated violations may result in account suspension.

6. Your rights
You (or your parent/guardian) may at any time request to view, correct, or fully delete your information, through your profile or by contacting support.

7. Contact us
Support: support@afghanistangirlsdigitalschool.org

By checking the box below and continuing registration, you confirm that you have read and agree to these terms.
''';

const String _kTermsFr = '''
1. À propos de cette application
« École numérique des filles d'Afghanistan » est une plateforme éducative gratuite conçue pour aider les filles afghanes à poursuivre leur apprentissage. En vous inscrivant à cette application, vous (ou votre parent/tuteur si vous avez moins de 18 ans) acceptez ces conditions.

2. Quelles informations sont collectées
Nom, date de naissance, province, classe, numéro de téléphone ou e-mail (facultatif), progrès scolaires, résultats d'examens, et messages envoyés dans les sections discussion et professeur IA. Ces informations ne sont utilisées que pour fournir les services éducatifs, suivre les progrès de l'élève et communiquer avec l'école ; elles ne sont jamais vendues à des entreprises publicitaires.

3. Sécurité des enfants et des adolescentes
Cette application est également utilisée par de jeunes filles. Pour cette raison :
  • Tous les messages de discussion (texte et vocal) sont examinés par le système et l'équipe d'administration pour prévenir les abus ou les contenus inappropriés.
  • Les utilisatrices ne peuvent pas partager d'informations de contact personnelles sensibles (comme une adresse précise) dans la discussion.
  • Tout message suspect ou harcelant doit être immédiatement signalé via le bouton « Signaler ».
  • Un compte parent peut être lié au compte d'un enfant pour suivre ses progrès.

4. Professeur IA (intelligence artificielle)
Les réponses du « Professeur IA » sont générées à partir du contenu des manuels scolaires officiels du programme afghan. Ces réponses peuvent parfois être incomplètes ou incorrectes ; vérifiez toujours auprès d'un vrai professeur ou d'un manuel. Les conversations avec le professeur IA sont enregistrées et examinées pour améliorer la qualité de l'enseignement.

5. Comportement des utilisatrices
L'usage d'un langage offensant, promotionnel, politique ou harcelant dans la discussion et avec le professeur IA est interdit. Des violations répétées peuvent entraîner la suspension du compte.

6. Vos droits
Vous (ou votre parent/tuteur) pouvez à tout moment demander à consulter, corriger ou supprimer entièrement vos informations, via votre profil ou en contactant le support.

7. Nous contacter
Support : support@afghanistangirlsdigitalschool.org

En cochant la case ci-dessous et en poursuivant l'inscription, vous confirmez avoir lu et accepté ces conditions.
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
                  termsAndPrivacyText(context),
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

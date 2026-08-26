/**
 * routes/privacy.ts — صفحهٔ عمومیِ سیاست حریم خصوصی/قوانین استفاده.
 *
 * چرا لازم است؟ Google Play و App Store هر دو یک URL عمومی و قابل‌دسترس
 * (نه فقط متن داخل اپ) برای Privacy Policy در Store Listing می‌خواهند.
 * متن این صفحه دقیقاً همان متن ۴زبانهٔ تأییدشده در
 * lib/features/auth/presentation/widgets/terms_gate.dart (Flutter) است —
 * تا اپ و وب‌سایت هرگز از هم جدا نیفتند. اگر آن متن را ویرایش کردید، اینجا
 * را هم به‌روزرسانی کنید (یا برعکس).
 *
 * مسیر: افزوده‌شده به‌عنوان `app.get('/privacy', privacyPolicyHandler)` در
 * index.ts، خارج از `/api/v1/*` چون یک صفحهٔ HTML عمومی است، نه JSON.
 * برای فعال‌شدن روی ریشهٔ دامنهٔ برند، این pattern هم باید در
 * backend/wrangler.toml به‌عنوان Route اضافه شود (کنار همان الگوی /verify/*):
 *   { pattern = "afghanistangirlsdigitalschool.org/privacy", zone_name = "afghanistangirlsdigitalschool.org" }
 */

const brand = 'مکتب دیجیتال دختران افغانستان — Afghanistan Girls Digital School';

type Lang = 'fa' | 'ps' | 'en' | 'fr';

const titles: Record<Lang, string> = {
  fa: 'سیاست حریم خصوصی و قوانین استفاده',
  ps: 'د محرمیت تګلاره او د کارونې قوانین',
  en: 'Privacy Policy & Terms of Use',
  fr: 'Politique de confidentialité et conditions d\'utilisation',
};

const tabLabels: Record<Lang, string> = { fa: 'دری', ps: 'پښتو', en: 'English', fr: 'Français' };
const dirs: Record<Lang, 'rtl' | 'ltr'> = { fa: 'rtl', ps: 'rtl', en: 'ltr', fr: 'ltr' };
const lastUpdated: Record<Lang, string> = {
  fa: 'آخرین به‌روزرسانی: ۲۰۲۶',
  ps: 'وروستی تازه‌کول: ۲۰۲۶',
  en: 'Last updated: 2026',
  fr: 'Dernière mise à jour : 2026',
};

// همان متن‌های دقیق terms_gate.dart — عمداً دوباره‌نویسی نشده تا با اپ همگام بماند.
const texts: Record<Lang, string> = {
  fa: `۱. دربارهٔ این برنامه
«مکتب دیجیتال دختران افغانستان» یک پلتفرم آموزشی رایگان است که برای کمک به دختران افغان در ادامهٔ یادگیری ساخته شده. با ثبت‌نام در این برنامه، شما (یا در صورتی که زیر ۱۸ سال دارید، والد/سرپرست شما) این قوانین را می‌پذیرید.

۲. چه معلوماتی جمع‌آوری می‌شود
نام، تاریخ تولد، ولایت، صنف تحصیلی، شمارهٔ تماس یا ایمیل (اختیاری)، پیشرفت درسی، نتایج امتحانات، و پیام‌های ارسالی در بخش چت و معلم هوشمند. این معلومات فقط برای ارائهٔ خدمات آموزشی، پیگیری پیشرفت شاگرد و ارتباط با مکتب استفاده می‌شود و هرگز به شرکت‌های تبلیغاتی فروخته نمی‌شود. شمارهٔ تماس و تاریخ تولد در پایگاه‌دادهٔ ما به‌صورت رمزنگاری‌شده (AES-256) ذخیره می‌شوند.

۳. ایمنی کودکان و نوجوانان
این برنامه توسط دختران خردسال نیز استفاده می‌شود. به همین دلیل:
  • تمام پیام‌های چت (متنی و صوتی) برای جلوگیری از سوءاستفاده یا محتوای نامناسب توسط سیستم و تیم مدیریت بازبینی می‌شود.
  • کاربران نمی‌توانند اطلاعات تماس شخصی حساس (مانند آدرس دقیق) را در چت به اشتراک بگذارند.
  • هرگونه پیام مشکوک یا آزاردهنده باید فوراً از طریق دکمهٔ «گزارش تخلف» گزارش شود.
  • حساب والدین می‌تواند به حساب فرزند متصل شود تا پیشرفت او را ببیند.
  • این برنامه هیچ تبلیغات شخصی‌سازی‌شده یا رفتاری برای کاربران خردسال نمایش نمی‌دهد.

۴. معلم هوشمند (هوش مصنوعی)
پاسخ‌های «معلم هوشمند» بر اساس محتوای کتاب‌های درسی رسمی نصاب تعلیمی افغانستان تولید می‌شود. این پاسخ‌ها ممکن است گاهی ناقص یا نادرست باشند؛ همیشه با معلم واقعی یا کتاب درسی مطابقت دهید. مکالمات با معلم هوشمند برای بهبود کیفیت آموزش ذخیره و بازبینی می‌شود.

۵. رفتار کاربران
استفاده از زبان توهین‌آمیز، تبلیغاتی، سیاسی یا مزاحم در چت و معلم هوشمند ممنوع است. تخلف مکرر می‌تواند به مسدود شدن حساب منجر شود.

۶. حقوق شما
شما (یا والد/سرپرست شما) هر زمان می‌توانید درخواست مشاهده، اصلاح یا حذف کامل معلومات خود را از طریق پروفایل یا با تماس از طریق پشتیبانی مطرح کنید.

۷. تماس با ما
پشتیبانی: support@afghanistangirlsdigitalschool.org

با استفاده از این برنامه، شما تأیید می‌کنید که این قوانین را خوانده و با آن موافق هستید.`,

  ps: `۱. د دې اپلیکیشن په اړه
«د افغان نجونو ډیجیټل ښوونځی» یو وړیا زده‌کړیز پلیټ‌فورم دی چې د افغان نجونو د زده‌کړې دوام لپاره جوړ شوی. په دې اپلیکیشن کې د نوم لیکنې سره، تاسو (یا که تاسو د ۱۸ کلونو څخه کم عمر لرئ، ستاسو مور/پلار یا سرپرست) دا قوانین منئ.

۲. کوم معلومات راټولیږي
نوم، د زیږون نیټه، ولایت، زده‌کړیز ټولګی، د تماس شمېره یا بریښنالیک (اختیاري)، زده‌کړیز پرمختګ، د ازموینو پایلې، او په چیټ او هوښیار ښوونکي برخو کې لیږل شوي پیغامونه. دا معلومات یوازې د زده‌کړیزو خدماتو وړاندې کولو، د زده‌کوونکي پرمختګ تعقیبولو، او له ښوونځي سره اړیکې لپاره کارول کیږي او هیڅکله د اعلاناتو شرکتونو ته نه پلورل کیږي. د تماس شمېره او زیږون نیټه زموږ په ډیټابیس کې په کوډ شوي (AES-256) بڼه ساتل کیږي.

۳. د ماشومانو او ځوانانو خوندیتوب
دا اپلیکیشن د کوچنیو نجونو لخوا هم کارول کیږي. له همدې امله:
  • ټول چیټ پیغامونه (متني او غږیز) د ناوړه ګټې اخیستنې یا نامناسب محتوا مخنیوي لپاره د سیسټم او مدیریت ټیم لخوا کتل کیږي.
  • کاروونکي نشي کولی حساس شخصي د تماس معلومات (لکه دقیق پته) په چیټ کې شریک کړي.
  • هر ډول شکمن یا ځورونکی پیغام باید سمدلاسه د «تخلف راپور» تڼۍ له لارې راپور شي.
  • د مور/پلار حساب کولی شي د ماشوم حساب سره وتړل شي ترڅو د هغې پرمختګ وویني.
  • دا اپلیکیشن کوچنیو کاروونکو ته هیڅ ډول شخصي‌شوي یا چلندي اعلانات نه ښیي.

۴. هوښیار ښوونکی (مصنوعي هوښیارتیا)
د «هوښیار ښوونکي» ځوابونه د افغانستان د رسمي نصاب درسي کتابونو محتوا پر بنسټ جوړیږي. دا ځوابونه ځینې وختونه ناقص یا غلط کیدای شي؛ تل یې د یو ریښتیني ښوونکي یا درسي کتاب سره سمون ورکړئ. د هوښیار ښوونکي سره خبرې اترې د زده‌کړې کیفیت ښه کولو لپاره خوندي او کتل کیږي.

۵. د کاروونکو چلند
په چیټ او هوښیار ښوونکي کې د سپکاوي، تبلیغاتي، سیاسي یا ځورونکي ژبې کارول منع دي. مکرر تخلف کولی شي ستاسو حساب بند کړي.

۶. ستاسو حقونه
تاسو (یا ستاسو مور/پلار) کولی شئ هر وخت د خپلو معلوماتو کتلو، سمولو، یا بشپړ ړنګولو غوښتنه د پروفایل له لارې یا د ملاتړ سره اړیکه نیولو سره وکړئ.

۷. زموږ سره اړیکه
ملاتړ: support@afghanistangirlsdigitalschool.org

د دې اپلیکیشن په کارولو سره، تاسو تایید کوئ چې دا قوانین مو لوستلي او ورسره موافق یاست.`,

  en: `1. About this app
"Afghanistan Girls Digital School" is a free educational platform built to help Afghan girls continue their education. By registering for this app, you (or your parent/guardian, if you are under 18) agree to these terms.

2. What information we collect
Name, date of birth, province, grade level, phone number or email (optional), academic progress, exam results, and messages sent in the chat and AI Teacher sections. This information is used only to provide educational services, track student progress, and communicate with the school, and is never sold to advertisers. Phone number and date of birth are stored encrypted (AES-256) in our database.

3. Child and teen safety
This app is also used by young girls. For this reason:
  • All chat messages (text and voice) are reviewed by the system and the management team to prevent abuse or inappropriate content.
  • Users cannot share sensitive personal contact information (such as a precise address) in chat.
  • Any suspicious or harassing message must be reported immediately using the "Report" button.
  • A parent account can be linked to a child's account to view their progress.
  • This app shows no personalized or behavioral advertising to child users.

4. AI Teacher (artificial intelligence)
Responses from the "AI Teacher" are generated based on the content of Afghanistan's official curriculum textbooks. These responses may sometimes be incomplete or incorrect; always verify with a real teacher or textbook. Conversations with the AI Teacher are stored and reviewed to improve education quality.

5. User conduct
Using offensive, promotional, political, or harassing language in chat and with the AI Teacher is prohibited. Repeated violations may result in account suspension.

6. Your rights
You (or your parent/guardian) may at any time request to view, correct, or fully delete your information, through your profile or by contacting support.

7. Contact us
Support: support@afghanistangirlsdigitalschool.org

By using this app, you confirm that you have read and agree to these terms.`,

  fr: `1. À propos de cette application
« École numérique des filles d'Afghanistan » est une plateforme éducative gratuite conçue pour aider les filles afghanes à poursuivre leur apprentissage. En vous inscrivant à cette application, vous (ou votre parent/tuteur si vous avez moins de 18 ans) acceptez ces conditions.

2. Quelles informations sont collectées
Nom, date de naissance, province, classe, numéro de téléphone ou e-mail (facultatif), progrès scolaires, résultats d'examens, et messages envoyés dans les sections discussion et professeur IA. Ces informations ne sont utilisées que pour fournir les services éducatifs, suivre les progrès de l'élève et communiquer avec l'école ; elles ne sont jamais vendues à des entreprises publicitaires. Le numéro de téléphone et la date de naissance sont stockés chiffrés (AES-256) dans notre base de données.

3. Sécurité des enfants et des adolescentes
Cette application est également utilisée par de jeunes filles. Pour cette raison :
  • Tous les messages de discussion (texte et vocal) sont examinés par le système et l'équipe d'administration pour prévenir les abus ou les contenus inappropriés.
  • Les utilisatrices ne peuvent pas partager d'informations de contact personnelles sensibles (comme une adresse précise) dans la discussion.
  • Tout message suspect ou harcelant doit être immédiatement signalé via le bouton « Signaler ».
  • Un compte parent peut être lié au compte d'un enfant pour suivre ses progrès.
  • Cette application n'affiche aucune publicité personnalisée ou comportementale aux utilisatrices mineures.

4. Professeur IA (intelligence artificielle)
Les réponses du « Professeur IA » sont générées à partir du contenu des manuels scolaires officiels du programme afghan. Ces réponses peuvent parfois être incomplètes ou incorrectes ; vérifiez toujours auprès d'un vrai professeur ou d'un manuel. Les conversations avec le professeur IA sont enregistrées et examinées pour améliorer la qualité de l'enseignement.

5. Comportement des utilisatrices
L'usage d'un langage offensant, promotionnel, politique ou harcelant dans la discussion et avec le professeur IA est interdit. Des violations répétées peuvent entraîner la suspension du compte.

6. Vos droits
Vous (ou votre parent/tuteur) pouvez à tout moment demander à consulter, corriger ou supprimer entièrement vos informations, via votre profil ou en contactant le support.

7. Nous contacter
Support : support@afghanistangirlsdigitalschool.org

En utilisant cette application, vous confirmez avoir lu et accepté ces conditions.`,
};

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function panel(lang: Lang): string {
  const body = escapeHtml(texts[lang]).replace(/\n/g, '<br>');
  return `<section id="tab-${lang}" class="panel" dir="${dirs[lang]}" lang="${lang}" ${lang === 'fa' ? '' : 'hidden'}>
  <p class="updated">${lastUpdated[lang]}</p>
  <div class="body">${body}</div>
</section>`;
}

/** صفحهٔ عمومی HTML — بدون نیاز به دیتابیس یا ورود، همیشه در دسترس. */
export function privacyPolicyHandler(c: any) {
  const tabs = (['fa', 'ps', 'en', 'fr'] as Lang[])
    .map((l) => `<button class="tab${l === 'fa' ? ' active' : ''}" data-lang="${l}" onclick="showLang('${l}', this)">${tabLabels[l]}</button>`)
    .join('');
  const panels = (['fa', 'ps', 'en', 'fr'] as Lang[]).map(panel).join('\n');

  const html = `<!DOCTYPE html>
<html dir="rtl" lang="fa"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(titles.fa)} — ${escapeHtml(brand)}</title>
<meta name="description" content="${escapeHtml(titles.fa)} — ${escapeHtml(brand)}">
<style>
  :root{color-scheme:light}
  body{margin:0;background:#f4f6f8;font-family:Tahoma,'Segoe UI',sans-serif;color:#1c2530;line-height:1.9}
  .wrap{max-width:760px;margin:0 auto;padding:32px 20px 64px}
  header{margin-bottom:24px}
  header h1{font-size:20px;margin:0}
  .doc-label{font-size:26px;font-weight:800;margin:6px 0 4px;color:#12362a}
  .doc-label .sep{color:#9aa7b0;font-weight:400;margin:0 6px}
  .card{background:#fff;border:1px solid #e3e8ee;border-radius:14px;padding:28px 24px}
  .tabs{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:20px}
  .tab{border:1px solid #d7dee6;background:#fff;border-radius:999px;padding:6px 16px;font-size:13px;cursor:pointer;color:#445;font-family:inherit}
  .tab.active{background:#1c7a5e;border-color:#1c7a5e;color:#fff}
  .updated{color:#77828d;font-size:12.5px;margin:0 0 14px}
  .body{font-size:14.5px}
  .panel[hidden]{display:none}
  footer{text-align:center;color:#93a0ab;font-size:12px;margin-top:28px}
  a{color:#1c7a5e}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>${escapeHtml(brand)}</h1>
    <p class="doc-label" lang="en">Privacy Policy<span class="sep">—</span><span lang="fa">سیاست حریم خصوصی</span></p>
  </header>
  <div class="tabs">${tabs}</div>
  <div class="card">
    ${panels}
  </div>
  <footer>© ${new Date().getFullYear()} Afghanistan Girls Digital School — afghanistangirlsdigitalschool.org</footer>
</div>
<script>
function showLang(lang, btn){
  document.querySelectorAll('.panel').forEach(function(p){ p.hidden = (p.id !== 'tab-' + lang); });
  document.querySelectorAll('.tab').forEach(function(t){ t.classList.remove('active'); });
  btn.classList.add('active');
  document.documentElement.lang = lang;
  document.documentElement.dir = (lang === 'en' || lang === 'fr') ? 'ltr' : 'rtl';
}
</script>
</body></html>`;

  return c.html(html);
}

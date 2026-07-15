/// ابزارهای مشترک «حلقهٔ یادگیری تطبیقی» بین موتورهای مبتنی‌بر LLM
/// (Worker/Ollama) — سیگنال ساختاریافتهٔ درست/غلط از ارزیابی پاسخ شاگرد،
/// بدون این‌که این نشانهٔ فنی هرگز به خودِ شاگرد نمایش داده شود.
library;

/// فقط برای نیت ارزیابی پاسخ (`AiIntent.answerAttempt`) به پرامپت سیستم
/// افزوده می‌شود — از مدل می‌خواهد در پایان پاسخش یک برچسب ساختاریافته
/// بگذارد تا کلاینت بتواند دقت شاگرد را لاگ/امتیازدهی/تطبیق سختی کند.
const String kAnswerCorrectnessInstruction =
    '\n\nدر پایان پاسخت (در یک خط جدا)، دقیقاً یکی از این برچسب‌ها را بنویس '
    '(بدون هیچ توضیح اضافه در همان خط): [[CORRECT]] اگر پاسخ شاگرد کاملاً '
    'درست بود، [[PARTIAL]] اگر تا حدی درست بود، یا [[INCORRECT]] اگر غلط '
    'بود. این برچسب فقط برای سیستم است؛ شاگرد هرگز آن را نمی‌بیند.';

/// راهنمای تطبیق سختی برای پرامپت سیستم — بر اساس چند پاسخ اخیر شاگرد.
String difficultyHintSuffix(String? hint) => hint == null ? '' : '\n\nتطبیق سطح: $hint';

class CorrectnessParseResult {
  final String body;
  final bool? wasCorrect;
  const CorrectnessParseResult(this.body, this.wasCorrect);
}

/// برچسب `[[CORRECT|PARTIAL|INCORRECT]]` را از انتهای پاسخ مدل جدا می‌کند و
/// متن تمیزِ قابل‌نمایش + سیگنال ساختاریافته را برمی‌گرداند. اگر برچسبی
/// پیدا نشود (مدل دستور را رعایت نکرد)، متن دست‌نخورده و سیگنال `null`
/// برمی‌گردد — هرگز خطا نمی‌دهد.
CorrectnessParseResult parseCorrectnessMarker(String raw) {
  final match = RegExp(r'\[\[(CORRECT|PARTIAL|INCORRECT)\]\]\s*$').firstMatch(raw.trim());
  if (match == null) return CorrectnessParseResult(raw.trim(), null);
  final tag = match.group(1);
  final clean = raw.substring(0, match.start).trim();
  final wasCorrect = tag == 'CORRECT' || tag == 'PARTIAL';
  return CorrectnessParseResult(clean.isEmpty ? raw.trim() : clean, wasCorrect);
}

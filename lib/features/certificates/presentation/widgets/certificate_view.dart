import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/certificate.dart';

/// طراحی رسمی و تزئینی گواهی‌نامه — همین ویجت هم در اپ نمایش داده می‌شود و
/// هم (از طریق RepaintBoundary) به PNG/PDF برای دانلود تبدیل می‌گردد.
class CertificateView extends StatelessWidget {
  final Certificate certificate;
  const CertificateView({super.key, required this.certificate});

  static const _gold = Color(0xFFB8860B);
  static const _goldLight = Color(0xFFDDB65C);
  static const _ink = Color(0xFF1F2A20);
  static const _cream = Color(0xFFFDF9EF);
  static const _green = Color(0xFF0E6655);

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  /// آدرس عمومی تأیید اصالت — صفحهٔ HTML بدون نیاز به ورود روی همان Worker
  /// بک‌اند (`GET /certificates/verify/:serial`)؛ پشت QR روی خودِ سند.
  String _verificationUrl(String serial) => '$kApiBaseUrl/certificates/verify/$serial';

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AspectRatio(
        aspectRatio: 1.45,
        child: Container(
          // قاب بیرونی طلایی
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [_gold, _goldLight, _gold],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 18,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Container(
            // زمینهٔ کرم داخلی + خط دوم قاب
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _gold, width: 1.4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 300;
                return Column(
                  children: [
                    // ── سربرگ: لوگو + نام مکتب ──
                    Row(
                      children: [
                        Image.asset(
                          'assets/logo/app_logo_mark.png',
                          width: compact ? 40 : 54,
                          height: compact ? 40 : 54,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.school_rounded,
                              size: compact ? 34 : 46,
                              color: _green),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('مکتب دیجیتال دختران افغانستان',
                                  style: TextStyle(
                                      fontSize: compact ? 11 : 13,
                                      fontWeight: FontWeight.w800,
                                      color: _green)),
                              Text('AFGHANISTAN GIRLS DIGITAL SCHOOL',
                                  style: TextStyle(
                                      fontSize: compact ? 6.5 : 8,
                                      letterSpacing: 1.4,
                                      color: _ink.withValues(alpha: .6))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(context.tr('certificates.serialNumberLabel'),
                                style: TextStyle(
                                    fontSize: compact ? 6.5 : 8,
                                    color: _ink.withValues(alpha: .55))),
                            Text(c.serial,
                                style: TextStyle(
                                    fontSize: compact ? 7.5 : 9,
                                    fontWeight: FontWeight.w700,
                                    color: _ink.withValues(alpha: .8))),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // ── QR تأیید اصالت — لینک به صفحهٔ عمومیِ تأیید سرور؛
                        // هر دانشگاه/کارفرض بدون نیاز به حساب کاربری می‌تواند
                        // اسکن کند و اصالت این سند را آنلاین بررسی کند (طبق
                        // درخواست کاربر برای اعتبار بین‌المللی — همان الگوی
                        // Coursera/edX).
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _gold.withValues(alpha: .5)),
                              ),
                              child: QrImageView(
                                data: _verificationUrl(c.serial),
                                version: QrVersions.auto,
                                size: compact ? 34 : 46,
                                gapless: true,
                                eyeStyle: const QrEyeStyle(color: _ink),
                                dataModuleStyle: const QrDataModuleStyle(color: _ink),
                              ),
                            ),
                            SizedBox(height: compact ? 1 : 2),
                            Text(context.tr('certificates.scanToVerify'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: compact ? 5.5 : 6.5,
                                    color: _ink.withValues(alpha: .55))),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // ── عنوان ──
                    Row(
                      children: [
                        const Expanded(child: _OrnamentLine()),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(context.tr('certificates.completionTitle'),
                              style: TextStyle(
                                  fontSize: compact ? 17 : 22,
                                  fontWeight: FontWeight.w900,
                                  color: _gold.withValues(alpha: .95))),
                        ),
                        const Expanded(child: _OrnamentLine()),
                      ],
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    Text(context.tr('certificates.certifiesText'),
                        style: TextStyle(
                            fontSize: compact ? 9 : 11,
                            color: _ink.withValues(alpha: .75))),
                    SizedBox(height: compact ? 4 : 8),
                    // ── نام شاگرد ──
                    Text(
                      c.studentName,
                      style: TextStyle(
                        fontSize: compact ? 20 : 26,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Text(
                      context.tr('certificates.achievementSentence', {
                        'grade': '${c.grade}',
                        'year': c.yearLabel,
                        'average': c.average.toStringAsFixed(0),
                        'honor': c.honor.isNotEmpty ? ' — ${c.honor}' : '',
                      }),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: compact ? 9.5 : 11.5,
                          height: 1.7,
                          color: _ink.withValues(alpha: .85)),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      // ── استاندارد نصاب آموزشی — طبق کدام معیار شاگرد
                      // ارزیابی شده؛ برای اعتبار بین‌المللی سند (بخش
                      // ۱۷.۴ سند)، به دری و انگلیسی با هم.
                      Text(
                        certificate.curriculumStandardFa,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 8,
                            color: _ink.withValues(alpha: .5)),
                      ),
                      Text(
                        certificate.curriculumStandardEn,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 6.5,
                            letterSpacing: .3,
                            color: _ink.withValues(alpha: .45)),
                      ),
                    ],
                    const Spacer(),
                    // ── پایین: تاریخ | مهر | امضا ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('certificates.issueDateLabel'),
                                  style: TextStyle(
                                      fontSize: compact ? 7 : 8.5,
                                      color: _ink.withValues(alpha: .55))),
                              Text(_fmtDate(c.issuedAt),
                                  style: TextStyle(
                                      fontSize: compact ? 9 : 11,
                                      fontWeight: FontWeight.w700,
                                      color: _ink)),
                            ],
                          ),
                        ),
                        // مهر رسمی
                        Container(
                          width: compact ? 44 : 58,
                          height: compact ? 44 : 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [_green, Color(0xFF16A085)]),
                            border: Border.all(color: _gold, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: _green.withValues(alpha: .35),
                                  blurRadius: 8),
                            ],
                          ),
                          child: Icon(Icons.verified_rounded,
                              color: Colors.white, size: compact ? 22 : 28),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('—————',
                                  style: TextStyle(
                                      fontSize: compact ? 9 : 11,
                                      color: _ink.withValues(alpha: .5))),
                              Text(c.issuedBy,
                                  style: TextStyle(
                                      fontSize: compact ? 9 : 11,
                                      fontWeight: FontWeight.w800,
                                      color: _ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OrnamentLine extends StatelessWidget {
  const _OrnamentLine();

  @override
  Widget build(BuildContext context) => Container(
        height: 1.6,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            CertificateView._gold.withValues(alpha: 0),
            CertificateView._gold,
          ]),
        ),
      );
}

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';

/// حلقهٔ شمارش معکوس سؤال جاری — رنگ با نزدیک‌شدن به پایان زمان از سبز به
/// نارنجی و سرخ تغییر می‌کند تا فوریت را حس کند («سؤال بعد از چند ثانیه
/// دیگر بسته می‌شود»). زمان واقعی از سرور (`endsAt`) می‌آید، نه شمارندهٔ
/// محلی مستقل — تا حتی اگر فریم افت کند، لحظهٔ دقیق پایان هرگز جا نماند.
class ArenaCountdownRing extends StatefulWidget {
  final DateTime endsAt;
  final int totalSeconds;
  final double size;

  const ArenaCountdownRing({super.key, required this.endsAt, required this.totalSeconds, this.size = 76});

  @override
  State<ArenaCountdownRing> createState() => _ArenaCountdownRingState();
}

class _ArenaCountdownRingState extends State<ArenaCountdownRing> {
  late final Stream<int> _ticker = Stream<int>.periodic(const Duration(milliseconds: 200), (_) {
    final remainingMs = widget.endsAt.difference(DateTime.now()).inMilliseconds;
    return remainingMs.clamp(0, widget.totalSeconds * 1000);
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<int>(
      stream: _ticker,
      initialData: widget.totalSeconds * 1000,
      builder: (context, snapshot) {
        final remainingMs = snapshot.data ?? 0;
        final fraction = widget.totalSeconds <= 0 ? 0.0 : (remainingMs / (widget.totalSeconds * 1000)).clamp(0.0, 1.0);
        final seconds = (remainingMs / 1000).ceil();
        final color = fraction > 0.5
            ? AppColors.green500
            : fraction > 0.2
                ? AppColors.gold600
                : AppColors.danger;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text('$seconds', style: TextStyle(fontSize: widget.size * 0.32, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        );
      },
    );
  }
}

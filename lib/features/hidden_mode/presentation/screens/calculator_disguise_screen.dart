import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/hidden_mode_providers.dart';

/// صفحهٔ نمایشیِ «ماشین‌حساب» — وقتی «حالت پنهان» فعال است، این صفحه به‌جای
/// کل برنامه نشان داده می‌شود. طبق طراحیِ توافق‌شده با کاربر:
///
/// • یک ماشین‌حسابِ کاملاً واقعی و کارکردنی است (نه فقط تزئینی) — اگر کسی
///   در چک‌پاینت آن را باز و امتحان کند، دقیقاً مثل یک ماشین‌حساب معمولی
///   محاسبه می‌کند.
/// • بدون هیچ لوگو/برند/متنِ مکتب — رنگ‌بندیِ خنثیِ استاندارد یک اپ
///   ماشین‌حساب، کاملاً مستقل از تمِ نارنجی/سبزِ برنامهٔ اصلی.
/// • رمزِ بازگشایی: کاربر رقم‌های PIN را وارد می‌کند (بدون هیچ عملگری در
///   میان آن‌ها) و روی «=» می‌زند. اگر مطابقت داشت، برنامهٔ واقعی بازمی‌گردد؛
///   اگر نه، دقیقاً مثل یک ماشین‌حسابِ واقعی محاسبه انجام می‌شود — یعنی حتی
///   یک تلاشِ نادرست هم هرگز چیزی «مشکوک» نشان نمی‌دهد.
class CalculatorDisguiseScreen extends ConsumerStatefulWidget {
  const CalculatorDisguiseScreen({super.key});

  @override
  ConsumerState<CalculatorDisguiseScreen> createState() => _CalculatorDisguiseScreenState();
}

class _CalculatorDisguiseScreenState extends ConsumerState<CalculatorDisguiseScreen> {
  String _display = '0';
  double? _operand1;
  String? _pendingOp;
  bool _resetOnNextDigit = false;
  String _pinBuffer = '';
  bool _checkingPin = false;

  static const _bg = Color(0xFF15171B);
  static const _displayColor = Colors.white;
  static const _numColor = Color(0xFF2B2E33);
  static const _opColor = Color(0xFF3A3D42);
  static const _accent = Color(0xFFF0A94E);

  String _formatNumber(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    var s = v.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  double _compute(double a, double b, String op) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b == 0 ? double.nan : a / b;
      default:
        return b;
    }
  }

  void _onDigit(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_resetOnNextDigit || _display == '0') {
        _display = d;
        _resetOnNextDigit = false;
      } else {
        _display += d;
      }
      _pinBuffer += d;
    });
  }

  void _onDot() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_resetOnNextDigit) {
        _display = '0.';
        _resetOnNextDigit = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
      _pinBuffer = ''; // نقطه بخشی از PIN نیست — رشتهٔ تلاش را باطل می‌کند
    });
  }

  void _onOperator(String op) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_operand1 != null && !_resetOnNextDigit && _pendingOp != null) {
        _operand1 = _compute(_operand1!, double.tryParse(_display) ?? 0, _pendingOp!);
        _display = _formatNumber(_operand1!);
      } else {
        _operand1 = double.tryParse(_display) ?? 0;
      }
      _pendingOp = op;
      _resetOnNextDigit = true;
      _pinBuffer = '';
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _display = '0';
      _operand1 = null;
      _pendingOp = null;
      _resetOnNextDigit = false;
      _pinBuffer = '';
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
      if (_pinBuffer.isNotEmpty) {
        _pinBuffer = _pinBuffer.substring(0, _pinBuffer.length - 1);
      }
    });
  }

  void _onToggleSign() {
    HapticFeedback.selectionClick();
    setState(() {
      final v = double.tryParse(_display) ?? 0;
      _display = _formatNumber(v * -1);
      _pinBuffer = '';
    });
  }

  void _onPercent() {
    HapticFeedback.selectionClick();
    setState(() {
      final v = double.tryParse(_display) ?? 0;
      _display = _formatNumber(v / 100);
      _pinBuffer = '';
    });
  }

  Future<void> _onEquals() async {
    HapticFeedback.lightImpact();
    final attempt = _pinBuffer;
    setState(() => _pinBuffer = '');

    if (attempt.length >= 3) {
      setState(() => _checkingPin = true);
      final ok = await ref.read(hiddenModeProvider.notifier).reveal(attempt);
      if (!mounted) return;
      setState(() => _checkingPin = false);
      if (ok) return; // روتر خودش به برنامهٔ واقعی هدایت می‌کند
    }

    setState(() {
      if (_pendingOp != null && _operand1 != null) {
        final result = _compute(_operand1!, double.tryParse(_display) ?? 0, _pendingOp!);
        _display = _formatNumber(result);
      }
      _operand1 = null;
      _pendingOp = null;
      _resetOnNextDigit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_pendingOp != null)
                        Text(
                          '${_formatNumber(_operand1 ?? 0)} $_pendingOp',
                          style: const TextStyle(color: Colors.white38, fontSize: 20),
                        ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        child: Text(
                          _display,
                          key: ValueKey(_display),
                          style: const TextStyle(
                            color: _displayColor,
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    Row(children: [
                      _CalcButton(label: 'C', color: _opColor, textColor: _accent, onTap: _onClear),
                      _CalcButton(label: '±', color: _opColor, textColor: Colors.white, onTap: _onToggleSign),
                      _CalcButton(label: '%', color: _opColor, textColor: Colors.white, onTap: _onPercent),
                      _CalcButton(label: '÷', color: _opColor, textColor: _accent, onTap: () => _onOperator('÷')),
                    ]),
                    Row(children: [
                      _CalcButton(label: '7', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('7')),
                      _CalcButton(label: '8', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('8')),
                      _CalcButton(label: '9', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('9')),
                      _CalcButton(label: '×', color: _opColor, textColor: _accent, onTap: () => _onOperator('×')),
                    ]),
                    Row(children: [
                      _CalcButton(label: '4', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('4')),
                      _CalcButton(label: '5', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('5')),
                      _CalcButton(label: '6', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('6')),
                      _CalcButton(label: '-', color: _opColor, textColor: _accent, onTap: () => _onOperator('-')),
                    ]),
                    Row(children: [
                      _CalcButton(label: '1', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('1')),
                      _CalcButton(label: '2', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('2')),
                      _CalcButton(label: '3', color: _numColor, textColor: Colors.white, onTap: () => _onDigit('3')),
                      _CalcButton(label: '+', color: _opColor, textColor: _accent, onTap: () => _onOperator('+')),
                    ]),
                    Row(children: [
                      _CalcButton(
                        label: '0',
                        color: _numColor,
                        textColor: Colors.white,
                        flex: 2,
                        alignment: Alignment.centerLeft,
                        onTap: () => _onDigit('0'),
                      ),
                      _CalcButton(label: '.', color: _numColor, textColor: Colors.white, onTap: _onDot),
                      _CalcButton(
                        label: '=',
                        color: _accent,
                        textColor: Colors.black,
                        loading: _checkingPin,
                        onTap: _onEquals,
                        onLongPress: _onBackspace,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final int flex;
  final Alignment alignment;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CalcButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.flex = 1,
    this.alignment = Alignment.center,
    this.loading = false,
    this.onLongPress,
  });

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: widget.flex,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 90),
            child: Container(
              height: 68,
              alignment: widget.alignment == Alignment.centerLeft
                  ? Alignment.centerLeft
                  : Alignment.center,
              padding: widget.alignment == Alignment.centerLeft
                  ? const EdgeInsets.only(left: 26)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.flex > 1 ? 34 : 34),
              ),
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: widget.textColor),
                    )
                  : Text(
                      widget.label,
                      style: TextStyle(fontSize: 26, color: widget.textColor, fontWeight: FontWeight.w500),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

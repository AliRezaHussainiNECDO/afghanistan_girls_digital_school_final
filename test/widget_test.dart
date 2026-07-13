// تست دودی (Smoke Test) پایه — فقط بررسی می‌کند که ریشهٔ اپ بدون خطا
// ساخته و رندر می‌شود. تست پیش‌فرض قالب Flutter (Counter/MyApp) که اینجا
// وجود نداشت با این تست واقعی جایگزین شد.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afghanistan_girls_digital_school/app/app.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();

    expect(find.byType(App), findsOneWidget);
  });
}

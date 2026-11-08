import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_reflection/main.dart';

void main() {
  testWidgets('يعرض التطبيق الواجهة العربية الرئيسية', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final store = LocalStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(SerenityApp(store: store));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('سكون'), findsOneWidget);
    expect(find.text('خذ لحظة لنفسك'), findsOneWidget);
    expect(find.text('يعمل دون اتصال'), findsOneWidget);
  });

  testWidgets('ينتقل إلى شاشة التنفس ويعرض التحكم', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final store = LocalStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(SerenityApp(store: store));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('تنفّس').last);
    await tester.pumpAndSettle();
    expect(find.text('تنفّس ببطء'), findsOneWidget);
    expect(find.text('ابدأ التنفّس'), findsOneWidget);
  });

  testWidgets('ينتقل إلى اليوميات ويحفظ المسار المحلي', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final store = LocalStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(SerenityApp(store: store));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('مذكراتي'));
    await tester.pumpAndSettle();
    expect(find.text('ملاحظتك الهادئة'), findsOneWidget);
    expect(find.text('حفظ محلي'), findsOneWidget);
  });
}

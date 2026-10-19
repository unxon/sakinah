import 'package:flutter_test/flutter_test.dart';
import 'package:sakeena/app/sakeena_app.dart';
import 'package:sakeena/core/storage/local_store.dart';

void main() {
  testWidgets('application shell renders the brand after bootstrap',
      (tester) async {
    await tester.pumpWidget(SakeenaApp(store: LocalStore.inMemory()));
    await tester.pumpAndSettle();
    expect(find.text('سَكينة'), findsOneWidget);
    expect(find.text('مكتبتك'), findsNothing);
  });
}

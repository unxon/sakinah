import 'package:flutter_test/flutter_test.dart';
import 'package:sakeena/core/storage/local_store.dart';

void main() {
  test(
      'in-memory store persists favorites, counts, and personal text within its lifecycle',
      () async {
    final store = LocalStore.inMemory();
    await store.open();
    await store.setFavorite('evening-001', true);
    await store.addCount('evening-001');
    final id = await store.addPersonal('دعائي', 'يا رب املأ قلبي سكينة.');

    var snapshot = await store.load();
    expect(snapshot.favorites, contains('evening-001'));
    expect(snapshot.counts['evening-001'], 1);
    expect(snapshot.personal.single['title'], 'دعائي');

    await store.updatePersonal(id, 'دعائي المعدل', 'يا رب زدني سكينة.');
    snapshot = await store.load();
    expect(snapshot.personal.single['title'], 'دعائي المعدل');

    await store.deletePersonal(id);
    expect((await store.load()).personal, isEmpty);

    final planId = await store.addPlan('خطة هادئة', 'كل مساء');
    await store.setSetting('darkMode', '1');
    var updated = await store.load();
    expect(updated.plans.any((plan) => plan['id'] == planId), isTrue);
    expect(updated.settings['darkMode'], '1');

    await store.deletePlan(planId);
    updated = await store.load();
    expect(updated.plans.any((plan) => plan['id'] == planId), isFalse);
  });
}

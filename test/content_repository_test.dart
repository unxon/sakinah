import 'package:flutter_test/flutter_test.dart';
import 'package:sakeena/data/content/asset_devotion_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the packaged Arabic devotion catalog', () async {
    final items = await const AssetDevotionRepository().list();
    expect(items, isNotEmpty);
    expect(items.first.packageId, 'core-ar');
    expect(items.first.verified, isTrue);
  });
}

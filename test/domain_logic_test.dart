import 'package:flutter_test/flutter_test.dart';

int safeCounter(int current, int target) =>
    current >= target ? target : current + 1;
Set<String> mergeCounterEvents(Set<String> left, Set<String> right) =>
    {...left, ...right};

void main() {
  test('counter never exceeds target', () {
    expect(safeCounter(4, 5), 5);
    expect(safeCounter(5, 5), 5);
  });

  test('counter merge is idempotent by event id', () {
    expect(mergeCounterEvents({'a', 'b'}, {'b', 'c'}), {'a', 'b', 'c'});
    expect(mergeCounterEvents({'a'}, {'a'}).length, 1);
  });
}

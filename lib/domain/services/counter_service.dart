class CounterService {
  const CounterService();

  int nextValue({required int current, required int target}) {
    if (current >= target) return target;
    return current + 1;
  }
}

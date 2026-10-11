import 'package:every_door/providers/need_update.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  test('needMapUpdateProvider can be created and notifies listeners', () {
    final container = ProviderContainer.test();

    // Creating the provider must not throw. Without explicit type arguments
    // the state type is inferred as dynamic, and creating the provider fails
    // with "is not a subtype of type ... of 'value'".
    expect(container.read(needMapUpdateProvider), isFalse);

    int triggered = 0;
    container.listen(needMapUpdateProvider, (previous, next) => triggered++);

    final notifier = container.read(needMapUpdateProvider.notifier);
    notifier.trigger();
    expect(triggered, 1);

    // The state never changes, but listeners must be notified anyway.
    notifier.trigger();
    expect(triggered, 2);
    expect(container.read(needMapUpdateProvider), isFalse);
  });
}

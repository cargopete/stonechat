import 'package:flutter_test/flutter_test.dart';
import 'package:stonechat/src/chat/chat_service.dart';

void main() {
  group('outboxBackoff', () {
    test('starts at 2s and doubles', () {
      expect(outboxBackoff(0), const Duration(seconds: 2));
      expect(outboxBackoff(1), const Duration(seconds: 4));
      expect(outboxBackoff(2), const Duration(seconds: 8));
      expect(outboxBackoff(3), const Duration(seconds: 16));
    });

    test('caps at 5 minutes', () {
      expect(outboxBackoff(20), const Duration(minutes: 5));
      expect(outboxBackoff(1000), const Duration(minutes: 5));
    });

    test('is monotonic non-decreasing', () {
      var previous = Duration.zero;
      for (var i = 0; i < 30; i++) {
        final current = outboxBackoff(i);
        expect(current >= previous, isTrue);
        previous = current;
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/utils/money.dart';

void main() {
  test('parse and format minor currency units without doubles', () {
    expect(parseCnyMinor('28.50'), 2850);
    expect(parseCnyMinor('28.5'), 2850);
    expect(parseCnyMinor('12'), 1200);
    expect(formatCny(2850), '¥28.50');
    expect(formatCny(-1200), '-¥12.00');
  });
  test('invalid amount is rejected', () {
    expect(() => parseCnyMinor('0.00'), throwsFormatException);
    expect(() => parseCnyMinor('1.234'), throwsFormatException);
    expect(() => parseCnyMinor('-2'), throwsFormatException);
  });
}

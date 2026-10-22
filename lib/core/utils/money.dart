String formatCny(int amountMinor) {
  final sign = amountMinor < 0 ? '-' : '';
  final absolute = amountMinor.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final grouped = whole.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '$sign¥$grouped.$fraction';
}

int parseCnyMinor(String raw) {
  final value = raw.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('请输入有效金额，最多两位小数');
  }
  final parts = value.split('.');
  final yuan = int.parse(parts[0]);
  final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
  // Prevent overflow in intermediate multiplications.
  if (yuan > 1000000000) throw const FormatException('金额超过允许范围');
  final total = yuan * 100 + cents;
  if (total <= 0) throw const FormatException('金额必须大于 0');
  return total;
}

String localYmd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

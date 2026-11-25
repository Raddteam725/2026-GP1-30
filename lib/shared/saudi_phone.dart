String? normalizeSaudiPhone(String? value) {
  if (value == null) return null;
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = arabicIndic.indexOf(char);
    buffer.write(index >= 0 ? '$index' : char);
  }
  var digits = buffer.toString().replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  final String national;
  if (digits.startsWith('00966')) {
    national = digits.substring(5);
  } else if (digits.startsWith('966')) {
    national = digits.substring(3);
  } else if (digits.startsWith('0')) {
    national = digits.substring(1);
  } else {
    return null;
  }
  return RegExp(r'^5[0-9]{8}$').hasMatch(national) ? '+966$national' : null;
}

import 'package:flutter/services.dart';

/// Keeps a typed +90 prefix editable while accepting common Turkish formats.
class TurkishPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0090') && digits.length > 12) {
      digits = digits.substring(4);
    }
    if (digits.startsWith('90') && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);

    final originalDigitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final adjustedOffset = originalDigitsBeforeCursor.clamp(0, digits.length);

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: adjustedOffset),
      composing: TextRange.empty,
    );
  }
}

/// Canonical login identifier for Turkish mobile numbers.
/// Accepts national, country-code, and common international-prefix formats.
String? normalizeTurkishPhoneNumber(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0090') && digits.length == 14) {
    digits = digits.substring(4);
  } else if (digits.startsWith('90') && digits.length == 12) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  if (digits.length != 10 || !digits.startsWith('5')) return null;
  return '+90$digits';
}

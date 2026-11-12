import 'package:flutter/services.dart';

/// Shows a fixed +90 prefix while storing only the Turkish national number.
/// Accepts pasted +90..., 0-prefixed and 10-digit national input.
class TurkishPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    var removedPrefixLength = 0;

    if (digits.startsWith('90') && digits.length >= 12) {
      digits = digits.substring(2);
      removedPrefixLength = 2;
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
      removedPrefixLength += 1;
    }
    if (digits.length > 10) digits = digits.substring(0, 10);

    final originalDigitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final adjustedOffset = (originalDigitsBeforeCursor - removedPrefixLength)
        .clamp(0, digits.length);

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: adjustedOffset),
      composing: TextRange.empty,
    );
  }
}

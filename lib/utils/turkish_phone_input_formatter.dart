import 'package:flutter/services.dart';

/// Keeps a typed +90 prefix editable while accepting common Turkish formats.
class TurkishPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
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

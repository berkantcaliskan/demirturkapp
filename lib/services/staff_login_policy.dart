import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../utils/turkish_phone_input_formatter.dart';

/// Input behavior only. Access and roles always come from the authenticated
/// server profile; matching a phone number grants no staff permission.
// These deterministic input hints are not credentials or an authorization boundary.
// Do not add plaintext employee phone numbers to the public app source.
bool usesStaffPasswordInput(String phone) {
  final normalized = normalizeTurkishPhoneNumber(phone);
  if (normalized == null) return false;
  return const {
    '3518b21011229b487a2ab36024378c99d15486d0484eae00ccf97b2afbdcfe2c',
    '734fa78cf78d75009d5fed3e6c1aa474cb5555a75715f0415f579fff3b085df1',
    'b099c2a56d5812f1ea06be1049dc1908630969addd468c2f105530afebbd254b',
    'bb752d864a119930738cec8d07c54632a8b64657194ef5b094b29769308e7767',
    '46bfc831d79fd4b5687b9cf5d85a911cb2419799dc08e6e0ee2f6d8e1cddc0ba',
    '20a2618e00a4ed2435796b527eecf6f36d037c27f23ab1d70e0fdca00143d73d',
  }.contains(sha256.convert(utf8.encode(normalized)).toString());
}

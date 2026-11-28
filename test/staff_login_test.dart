import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/screens/auth/auth_screen.dart';
import 'package:senet_takip/services/app_state.dart';
import 'package:senet_takip/services/staff_login_policy.dart';

void main() {
  test('Staff input hints normalize all supported phone formats and do not grant roles', () {
    for (final value in [
      '0530 552 44 54',
      '+90 (530) 552-44-54',
      '5305524454',
      '00905305524454',
    ]) {
      expect(usesStaffPasswordInput(value), isTrue);
    }
    expect(usesStaffPasswordInput('5990000000'), isFalse);
    expect(AppState().currentRole.name, 'customer');
  });
  testWidgets(
    'A staff number silently enables long passwords and normal deletion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(MaterialApp(home: AuthScreen(appState: state)));
      await tester.enterText(find.byType(TextFormField).first, '5305524454');
      await tester.pumpAndSettle();
      final password = find.byType(TextFormField).last;
      await tester.enterText(password, 'FixtureOnly42LongPassword');
      await tester.pump();
      var editor = tester.widget<EditableText>(find.byType(EditableText).last);
      expect(editor.keyboardType, TextInputType.visiblePassword);
      expect(editor.controller.text, 'FixtureOnly42LongPassword');
      expect(find.textContaining('personel', findRichText: true), findsNothing);
      expect(find.byKey(const ValueKey('password-dot-0')), findsNothing);
      await tester.enterText(password, 'FixtureOnly42LongPasswor');
      await tester.pump();
      editor = tester.widget<EditableText>(find.byType(EditableText).last);
      expect(editor.controller.text, 'FixtureOnly42LongPasswor');
      await tester.enterText(password, '');
      await tester.pump();
      expect(editor.controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/screens/auth/auth_screen.dart';
import 'package:senet_takip/services/app_state.dart';

void main() {
  testWidgets('one sign-in screen serves customers and staff with company contact links', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AuthScreen(appState: state)));

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
    expect(find.byTooltip('Sahibinden mağazalarımız'), findsOneWidget);
    expect(find.byTooltip('iletisim@demirturkinsaat.com'), findsOneWidget);

    expect(find.byTooltip('Yönetici girişi'), findsNothing);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.byTooltip('Instagram'), findsOneWidget);
    expect(find.byTooltip('0 (531) 373 00 54'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

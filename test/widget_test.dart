import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/main.dart';

void main() {
  testWidgets('SenetTakipApp loads customer dashboard and switches to admin',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SenetTakipApp());

    expect(find.text('DemirtürkApp'), findsOneWidget);
    expect(find.text('KALAN TOPLAM SENET BORCU'), findsOneWidget);

    await tester.tap(find.text('Yöneticiye Geç'));
    await tester.pumpAndSettle();

    expect(find.text('ŞİRKET GENEL SENET & TAHSİLAT ÖZETİ'), findsOneWidget);
  });
}

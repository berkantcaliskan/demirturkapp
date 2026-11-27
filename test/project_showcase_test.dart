import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/screens/customer/customer_project_showcase.dart';

void main() {
  testWidgets('project cards open their own gallery and return to contact', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var contactRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerProjectShowcase(
            bottomPadding: 64,
            onContact: () => contactRequests++,
          ),
        ),
      ),
    );

    for (final project in [
      'Yenişehir',
      'Asel Doğa Evleri',
      'Asel Doğa Evleri 3',
      'Asel Doğa Evleri 4',
      'Almina 2',
    ]) {
      final card = find.text(project);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text(project), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Fotoğraf 2'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      final contact = find.text('Bilgi alın');
      await tester.ensureVisible(contact);
      await tester.pumpAndSettle();
      await tester.tap(contact);
      await tester.pumpAndSettle();
      expect(find.text('Projelerimiz'), findsOneWidget);
    }
    expect(contactRequests, 5);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('covers rotate every five seconds with staggered changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CustomerProjectShowcase(bottomPadding: 0)),
      ),
    );

    String? coverLabel(String assetName) => tester
        .widget<Image>(
          find
              .descendant(
                of: find.byKey(ValueKey('project-card-$assetName')),
                matching: find.byType(Image),
              )
              .last,
        )
        .semanticLabel;

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));
    expect(coverLabel('yenisehir'), 'Yenişehir, fotoğraf 2');
    expect(coverLabel('asel'), 'Asel Doğa Evleri, fotoğraf 1');
    expect(coverLabel('asel3'), 'Asel Doğa Evleri 3, fotoğraf 1');

    await tester.pump(const Duration(seconds: 1));
    expect(coverLabel('yenisehir'), 'Yenişehir, fotoğraf 2');
    expect(coverLabel('asel'), 'Asel Doğa Evleri, fotoğraf 2');
    expect(coverLabel('asel3'), 'Asel Doğa Evleri 3, fotoğraf 1');

    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(coverLabel('yenisehir'), 'Yenişehir, fotoğraf 3');
    expect(coverLabel('asel'), 'Asel Doğa Evleri, fotoğraf 2');
    expect(coverLabel('asel3'), 'Asel Doğa Evleri 3, fotoğraf 2');
    expect(coverLabel('asel4'), 'Asel Doğa Evleri 4, fotoğraf 2');
    expect(coverLabel('almina'), 'Almina 2, fotoğraf 2');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

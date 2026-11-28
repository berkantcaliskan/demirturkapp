import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/main.dart';
import 'package:senet_takip/services/app_state.dart';
import 'package:senet_takip/widgets/website_blurred_background.dart';

AppState demoFixture() => AppState()
  ..replaceBackendCustomerData(
    customerRow: {
      'id': 'example',
      'full_name': 'Örnek Müşteri',
      'phone': '+905555555555',
      'contract_number': 'ORNEK-2026-001',
      'contract_status': 'approved',
      'project_name': 'Yenişehir',
      'unit_label': 'A Blok · Daire 12 · 2+1',
      'project_status': 'Örnek konut kaydı',
      'down_payment_amount': 1500000,
      'is_demo': true,
      'assigned_advisor_name': 'Ertuğrul',
    },
    noteRows: [
      for (var i = 1; i <= 50; i++)
        {
          'id': 'note-$i',
          'customer_id': 'example',
          'note_number': 'ORNEK-${i.toString().padLeft(3, '0')}',
          'installment_index': i,
          'total_installments': 50,
          'amount': 35000,
          'status': 'pending',
          'due_date': DateTime(2026, 12 + i - 1, 28).toIso8601String(),
        },
    ],
    bankRows: [],
  );

void main() {
  setUpAll(() async {
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'));
    await loader.load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in ['.SF Pro Text', '.SF Pro Display']) {
      await (FontLoader(family)
            ..addFont(
              rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf')))
          .load();
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Customer shell fits $size $brightness and renders four sample pages',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final state = demoFixture();
          addTearDown(state.dispose);
          final key = GlobalKey();
          const font = TextStyle(fontFamily: 'Plus Jakarta Sans');
          final theme = ThemeData(
            brightness: brightness,
            fontFamily: 'Plus Jakarta Sans',
            cupertinoOverrideTheme: const CupertinoThemeData(
              textTheme: CupertinoTextThemeData(
                textStyle: font,
                actionTextStyle: font,
                tabLabelTextStyle: font,
                navTitleTextStyle: font,
                navLargeTitleTextStyle: font,
                navActionTextStyle: font,
                pickerTextStyle: font,
                dateTimePickerTextStyle: font,
              ),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 47, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                ),
                child: RepaintBoundary(
                  key: key,
                  child: WebsiteBlurredBackground(
                    child: MainShell(
                      appState: state,
                      onLogout: () async {},
                      connectBackend: false,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          final logo = find.text('DEMİRTÜRK');
          expect(tester.getTopLeft(logo).dy, lessThan(90));
          expect(tester.getSize(logo).height, greaterThan(14));
          for (final item in [
            ('Başlangıç', '01-baslangic'),
            ('Ödemelerim', '02-odemelerim'),
            ('İletişim', '03-iletisim'),
            ('Evim', '04-evim'),
          ]) {
            await tester.tap(find.text(item.$1).last);
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(tester.getTopLeft(logo).dy, lessThan(90));
            if (Platform.environment['CAPTURE_CUSTOMER_PREVIEWS'] == '1' &&
                size.width == 390) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 3);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final output = File(
                  '../work/storefront-preview/${brightness.name}-${item.$2}.png',
                );
                await output.parent.create(recursive: true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

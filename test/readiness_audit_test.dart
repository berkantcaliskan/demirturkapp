import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/models/app_models.dart';
import 'package:senet_takip/screens/admin/admin_dashboard_screen.dart';
import 'package:senet_takip/screens/admin/admin_support_inbox_screen.dart';
import 'package:senet_takip/screens/auth/auth_screen.dart';
import 'package:senet_takip/screens/customer/customer_home_screen.dart';
import 'package:senet_takip/screens/customer/customer_notes_screen.dart';
import 'package:senet_takip/screens/customer/customer_project_screen.dart';
import 'package:senet_takip/screens/customer/customer_project_showcase.dart';
import 'package:senet_takip/services/app_state.dart';
import 'package:senet_takip/services/portal_repository.dart';
import 'package:senet_takip/utils/turkish_phone_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditInboxRepository extends PortalRepository {
  AuditInboxRepository() : super(SupabaseClient('https://example.invalid', 'test',
    authOptions: const AuthClientOptions(autoRefreshToken: false)));

  @override
  Future<List<Map<String, dynamic>>> loadMyTickets() async => [];

  @override
  Stream<List<Map<String, dynamic>>> watchMyTickets() => const Stream.empty();
}

AppState fixture() => AppState()
  ..replaceBackendCustomerData(
    customerRow: {
      'id': '10000000-0000-0000-0000-000000000001',
      'full_name': 'Denetim Müşterisi',
      'phone': '+905990000001',
      'contract_number': '2026/000001',
      'contract_status': 'approved',
      'project_name': 'Asel Doğa Evleri 3',
      'unit_label': 'A Blok 12',
    },
    noteRows: [
      for (final status in ['pending', 'paid', 'overdue', 'verifying'])
        {
          'id': status,
          'customer_id': '10000000-0000-0000-0000-000000000001',
          'note_number': 'SNT-$status',
          'installment_index': 1,
          'total_installments': 4,
          'amount': 123456.78,
          'due_date': '2026-11-24',
          'status': status,
        },
    ],
    bankRows: [],
  );

Future<void> mount(WidgetTester tester, Widget child,
    {Brightness brightness = Brightness.light, double scale = 1}) async {
  await tester.binding.setSurfaceSize(const Size(360, 780));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness, useMaterial3: true, fontFamily: 'Plus Jakarta Sans'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));
    await fonts.load();
  });
  test('phone identifiers accept common Turkish number formats', () {
    for (final input in [
      '0530 552 44 54', '5305524454', '+90 530 552 44 54',
      '905305524454', '00905305524454',
    ]) {
      expect(normalizeTurkishPhoneNumber(input), '+905305524454');
    }
    expect(normalizeTurkishPhoneNumber('1234'), isNull);
    expect(normalizeTurkishPhoneNumber('+902125524454'), isNull);
  });

  test('phone formatter allows complete deletion and middle edits', () {
    final formatter = TurkishPhoneInputFormatter();
    expect(formatter.formatEditUpdate(
      const TextEditingValue(text: '5305524454', selection: TextSelection.collapsed(offset: 10)),
      TextEditingValue.empty,
    ).text, '');
    expect(formatter.formatEditUpdate(
      const TextEditingValue(text: '5305524454'),
      const TextEditingValue(text: '530524454', selection: TextSelection.collapsed(offset: 4)),
    ).selection.baseOffset, 4);
  });

  testWidgets('password stays numeric, masked and editable after entering six digits', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, AuthScreen(appState: state));
    final password = find.byType(TextFormField).last;
    await tester.enterText(password, '123456');
    await tester.pump(const Duration(milliseconds: 700));
    final editor = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(editor.obscureText, isTrue);
    expect(editor.keyboardType, TextInputType.number);
    await tester.tap(password);
    await tester.enterText(password, '12345');
    await tester.pump(const Duration(milliseconds: 700));
    expect(editor.controller.text, '12345');
    await tester.enterText(password, '');
    await tester.pump(const Duration(milliseconds: 700));
    expect(editor.controller.text, '');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('customer and staff screens render at $brightness scale $scale', (tester) async {
        final state = fixture();
        addTearDown(state.dispose);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final layoutErrors = <String>[];
        final screens = <Widget>[
          AuthScreen(appState: state),
          CustomerHomeScreen(appState: state, onNavigateTab: (_) {}, readOnly: true),
          CustomerNotesScreen(appState: state, readOnly: true),
          CustomerProjectScreen(appState: state),
          const CustomerProjectShowcase(bottomPadding: 0),
        ];
        for (final screen in screens) {
          await mount(tester, screen, brightness: brightness, scale: scale);
          final error = tester.takeException();
          if (error != null) layoutErrors.add('${screen.runtimeType}: $error');
          await tester.pumpWidget(const SizedBox());
        }
        for (final role in [UserRole.salesAdvisor, UserRole.accounting, UserRole.management]) {
          state.setRole(role);
          for (var tab = 0; tab < (role == UserRole.salesAdvisor ? 4 : 5); tab++) {
            await mount(tester, AdminDashboardScreen(appState: state,
              activeTabIndex: tab, onPreviewCustomer: (_) {}),
              brightness: brightness, scale: scale);
            final error = tester.takeException();
            if (error != null) layoutErrors.add('$role tab $tab: $error');
            await tester.pumpWidget(const SizedBox());
          }
        }
        expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n'));
      });
    }
  }

  testWidgets('staff inbox title is readable in the light theme', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const key = ValueKey('audit-inbox');
    await mount(tester, RepaintBoundary(key: key,
      child: ColoredBox(color: Colors.white,
        child: AdminSupportInboxScreen(repository: AuditInboxRepository()))));
    await tester.pump(const Duration(milliseconds: 100));
    final title = tester.widget<Text>(find.text('Müşteri Mesajları'));
    expect(title.style?.color, isNot(Colors.white));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

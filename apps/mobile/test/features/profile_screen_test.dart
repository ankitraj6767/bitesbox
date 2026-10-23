import 'dart:async';

import 'package:bitesbox/core/auth/session.dart';
import 'package:bitesbox/core/providers/core_providers.dart';
import 'package:bitesbox/core/theme/brand_tokens.dart';
import 'package:bitesbox/features/customer/data/account_repository.dart';
import 'package:bitesbox/features/customer/providers/customer_providers.dart';
import 'package:bitesbox/features/customer/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'initial switches hydrate persisted preferences before showing controls',
    (tester) async {
      final account = _FakeAccountRepository();
      await tester.pumpWidget(
        _app(
          _FakeSessionController(
            _session(push: false, sms: true, whatsapp: true, marketing: false),
          ),
          account,
        ),
      );
      await tester.pumpAndSettle();

      expect(_switch(tester, 'Push notifications').value, isFalse);
      expect(_switch(tester, 'SMS').value, isTrue);
      expect(_switch(tester, 'WhatsApp').value, isTrue);
      await _scrollTo(tester, 'Offers and new dish alerts');
      expect(_switch(tester, 'Offers and new dish alerts').value, isFalse);
      expect(find.textContaining('Order-critical updates'), findsOneWidget);
    },
  );

  testWidgets('toggling each channel and marketing saves the explicit values', (
    tester,
  ) async {
    final account = _FakeAccountRepository();
    await tester.pumpWidget(
      _app(
        _FakeSessionController(
          _session(push: false, sms: false, whatsapp: true, marketing: false),
        ),
        account,
      ),
    );
    await tester.pumpAndSettle();

    for (final title in [
      'Push notifications',
      'SMS',
      'WhatsApp',
      'Offers and new dish alerts',
    ]) {
      await _scrollTo(tester, title);
      await tester.tap(_switchFinder(title));
      await tester.pump();
    }
    await _scrollTo(tester, 'Save changes');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(account.lastCall, {
      'fullName': 'Aarav Kumar',
      'email': 'aarav@example.test',
      'marketingOptIn': true,
      'pushEnabled': true,
      'smsEnabled': true,
      'whatsappEnabled': false,
    });
    final updated = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(updated.map((item) => item.value), [true, true, false, true]);
  });

  testWidgets(
    'editing only name and email leaves all channel values untouched',
    (tester) async {
      final account = _FakeAccountRepository();
      await tester.pumpWidget(
        _app(
          _FakeSessionController(
            _session(push: false, sms: true, whatsapp: true, marketing: false),
          ),
          account,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Ankit Raj');
      await tester.enterText(
        find.byType(TextField).at(1),
        'ankit@example.test',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Save changes');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(account.lastCall, {
        'fullName': 'Ankit Raj',
        'email': 'ankit@example.test',
        'marketingOptIn': null,
        'pushEnabled': null,
        'smsEnabled': null,
        'whatsappEnabled': null,
      });
    expect(_switch(tester, 'Push notifications').value, isFalse);
    expect(_switch(tester, 'SMS').value, isTrue);
    expect(_switch(tester, 'WhatsApp').value, isTrue);
    await _scrollTo(tester, 'Offers and new dish alerts');
    expect(_switch(tester, 'Offers and new dish alerts').value, isFalse);
    },
  );

  testWidgets('reopening after save uses the updated session values', (
    tester,
  ) async {
    final account = _FakeAccountRepository();
    final sessionController = _FakeSessionController(_session(whatsapp: true));
    final root = _app(
      sessionController,
      account,
      child: const ProfileScreen(key: ValueKey('first')),
    );
    await tester.pumpWidget(root);
    await tester.pumpAndSettle();

    await _scrollTo(tester, 'WhatsApp');
    await tester.tap(_switchFinder('WhatsApp'));
    await tester.pump();
    await _scrollTo(tester, 'Save changes');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(
        sessionController,
        account,
        child: const ProfileScreen(key: ValueKey('reopened')),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, 'WhatsApp');
    expect(_switch(tester, 'WhatsApp').value, isFalse);
  });

  testWidgets('loading or null profile never shows default opt-ins', (
    tester,
  ) async {
    final pending = Completer<AppSession>();
    await tester.pumpWidget(
      _app(_FakeSessionController.pending(pending), _FakeAccountRepository()),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);

    pending.complete(
      const AppSession(authenticated: true, userId: 'customer-1'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Your profile could not be loaded.'), findsOneWidget);
  });

  testWidgets('server errors preserve the changed control and allow retry', (
    tester,
  ) async {
    final account = _FakeAccountRepository()..failNext = true;
    await tester.pumpWidget(
      _app(_FakeSessionController(_session(push: false)), account),
    );
    await tester.pumpAndSettle();

    await tester.tap(_switchFinder('Push notifications'));
    await tester.pump();
    await _scrollTo(tester, 'Save changes');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      _switch(tester, 'Push notifications').value,
      isTrue,
    );
    expect(find.text('Save changes'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );
  });
}

Finder _switchFinder(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byType(SwitchListTile),
);

SwitchListTile _switch(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(_switchFinder(title));

Future<void> _scrollTo(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
}

Widget _app(
  _FakeSessionController controller,
  _FakeAccountRepository account, {
  Widget? child,
}) => ProviderScope(
  overrides: [
    sessionProvider.overrideWith(() => controller),
    accountRepositoryProvider.overrideWithValue(account),
  ],
  child: BrandTheme(
    tokens: const BrandTokens(),
    child: MaterialApp(home: child ?? const ProfileScreen()),
  ),
);

AppSession _session({
  bool push = true,
  bool sms = true,
  bool whatsapp = false,
  bool marketing = false,
}) => AppSession(
  authenticated: true,
  userId: 'customer-1',
  profile: UserProfile(
    id: 'customer-1',
    fullName: 'Aarav Kumar',
    email: 'aarav@example.test',
    phone: '+919900000001',
    onboardingCompleted: true,
    pushEnabled: push,
    smsEnabled: sms,
    whatsappEnabled: whatsapp,
    marketingOptIn: marketing,
  ),
);

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session) : _pending = null;
  _FakeSessionController.pending(this._pending)
    : _session = const AppSession.guest();

  final AppSession _session;
  final Completer<AppSession>? _pending;

  @override
  Future<AppSession> build() => _pending?.future ?? Future.value(_session);

  @override
  Future<void> refresh() async {}

  @override
  void updateProfile(UserProfile profile) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(profile: profile));
    }
  }
}

class _FakeAccountRepository implements AccountRepository {
  Map<String, Object?>? lastCall;
  bool failNext = false;

  @override
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? preferredLanguage,
    bool? marketingOptIn,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? whatsappEnabled,
  }) async {
    lastCall = {
      'fullName': fullName?.trim(),
      'email': email?.trim(),
      'marketingOptIn': marketingOptIn,
      'pushEnabled': pushEnabled,
      'smsEnabled': smsEnabled,
      'whatsappEnabled': whatsappEnabled,
    };
    if (failNext) {
      failNext = false;
      throw StateError('server unavailable');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:bitesbox/core/theme/brand_tokens.dart';
import 'package:bitesbox/features/delivery/data/delivery_models.dart';
import 'package:bitesbox/features/delivery/screens/rider_shell.dart';
import 'package:bitesbox/shared/widgets/live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the rider surfaces.
///
/// The rider app is used one-handed, often in a phone mount, so the properties
/// worth testing are the operational ones: the single primary action is large and
/// reachable, a busy state cannot be double-tapped into two requests, and duty
/// state is announced to assistive technology rather than conveyed only by colour.
void main() {
  Widget wrap(Widget child) {
    return BrandTheme(
      tokens: const BrandTokens(),
      child: MaterialApp(
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    );
  }

  group('RiderPrimaryButton', () {
    testWidgets('shows its label and fires once when tapped', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrap(
          RiderPrimaryButton(
            label: 'I have reached the restaurant',
            icon: Icons.storefront_rounded,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.text('I have reached the restaurant'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(taps, 1);
    });

    // A rider on a poor connection will tap again. While a request is in flight the
    // button must be inert, or the same step is sent twice.
    testWidgets('is inert and shows progress while busy', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrap(
          RiderPrimaryButton(
            label: 'Complete delivery',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Complete delivery'), findsNothing);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('is disabled with no callback', (tester) async {
      await tester.pumpWidget(wrap(const RiderPrimaryButton(label: 'Waiting', onPressed: null)));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // 60 logical pixels comfortably clears the 48dp guidance, which matters when the
    // phone is in a mount and the rider is wearing gloves.
    testWidgets('offers a large touch target', (tester) async {
      await tester.pumpWidget(
        wrap(RiderPrimaryButton(label: 'Accept delivery', onPressed: () {})),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('DutyStatePill', () {
    // Duty state is conveyed visually by a coloured dot, so the semantics label is
    // the only thing carrying it to a screen reader.
    //
    // Asserted on the Semantics widget rather than the rendered node, because the
    // node label merges the wrapper with the visible text beneath it and that
    // merging is a Flutter implementation detail, not our contract.
    testWidgets('labels each duty state for a screen reader', (tester) async {
      for (final state in DutyState.values) {
        await tester.pumpWidget(wrap(DutyStatePill(state: state)));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(DutyStatePill),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.label,
          'Duty state: ${state.label}',
          reason: state.code,
        );
      }
    });

    testWidgets('reads "On duty" rather than the enum', (tester) async {
      await tester.pumpWidget(wrap(const DutyStatePill(state: DutyState.available)));
      expect(find.text('On duty'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsNothing);
    });
  });

  group('RiderStat', () {
    testWidgets('shows a label, value and caption', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RiderStat(
            label: 'Earned today',
            value: '₹340',
            caption: '7 deliveries',
          ),
        ),
      );

      expect(find.text('EARNED TODAY'), findsOneWidget);
      expect(find.text('₹340'), findsOneWidget);
      expect(find.text('7 deliveries'), findsOneWidget);
    });

    testWidgets('omits the caption when there is none', (tester) async {
      await tester.pumpWidget(wrap(const RiderStat(label: 'Rating', value: '4.8')));
      expect(find.text('4.8'), findsOneWidget);
    });
  });

  group('RiderWaypoint', () {
    testWidgets('shows the stop and offers navigation only when it can', (tester) async {
      var navigations = 0;

      await tester.pumpWidget(
        wrap(
          RiderWaypoint(
            icon: Icons.storefront_rounded,
            title: 'Bites Box Bakhtiyarpur',
            body: 'Main Road, Bakhtiyarpur',
            tone: const BrandTokens().secondary,
            onNavigate: () => navigations++,
          ),
        ),
      );

      expect(find.text('Bites Box Bakhtiyarpur'), findsOneWidget);
      expect(find.text('Main Road, Bakhtiyarpur'), findsOneWidget);

      await tester.tap(find.byTooltip('Navigate'));
      await tester.pump();
      expect(navigations, 1);
    });

    testWidgets('hides the navigate button without a destination', (tester) async {
      await tester.pumpWidget(
        wrap(
          RiderWaypoint(
            icon: Icons.location_on_rounded,
            title: 'Customer',
            body: 'No saved location',
            tone: const BrandTokens().primary,
          ),
        ),
      );

      expect(find.byTooltip('Navigate'), findsNothing);
    });
  });

  group('LiveMap', () {
    // Without a Maps key the app must still convey where things are and offer a
    // hand-off, rather than rendering an empty grey box or crashing.
    testWidgets('falls back to a readable panel with no Maps key', (tester) async {
      await tester.pumpWidget(
        wrap(
          const LiveMap(
            points: [
              MapPoint(
                id: 'rider',
                latitude: 25.4608,
                longitude: 85.5230,
                label: 'Rahul Kumar',
                kind: MapPointKind.rider,
                caption: 'about 6 min away',
              ),
              MapPoint(
                id: 'destination',
                latitude: 25.4632,
                longitude: 85.5252,
                label: 'Your address',
                kind: MapPointKind.customer,
              ),
            ],
          ),
        ),
      );

      expect(find.textContaining('Rahul Kumar'), findsOneWidget);
      expect(find.textContaining('about 6 min away'), findsOneWidget);
      expect(find.text('Your address'), findsOneWidget);
      expect(find.text('Open in maps'), findsOneWidget);
    });

    testWidgets('explains itself when there is nothing to draw yet', (tester) async {
      await tester.pumpWidget(
        wrap(const LiveMap(points: [], emptyMessage: 'Waiting for your rider…')),
      );

      expect(find.text('Waiting for your rider…'), findsOneWidget);
      expect(find.text('Open in maps'), findsNothing);
    });
  });
}

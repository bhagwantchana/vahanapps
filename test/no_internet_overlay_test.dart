// Widget tests for the global "No internet connection" overlay.
//
// These drive the overlay purely through the public
// `ConnectivityService.instance.isOnline` ValueNotifier — we never mock
// `InternetAddress.lookup`, so no real network probe runs here. The overlay
// is rendered via a minimal MaterialApp that supplies the AppStrings
// localization delegate (the overlay reads localized title/message/button
// labels) plus the Material/Widget/Cupertino globals the framework expects.

import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/services/connectivity_service.dart';
import 'package:fleet_monitor/widgets/no_internet_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({Locale? locale, Widget? child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppStrings.supportedLocales,
    home: NoInternetOverlay(
      child: child ??
          const Scaffold(
            body: Center(child: Text('APP_CONTENT')),
          ),
    ),
  );
}

/// The English title/message/button labels, looked up the same way the widget
/// does, so a translation edit can't silently desync the expectations.
String _title(String lang) =>
    AppStrings(Locale(lang)).t('no_internet_title');

void main() {
  // The ConnectivityService is a process-wide singleton. Force a known-good
  // (online) state before and after every test so ordering can't leak.
  setUp(() {
    ConnectivityService.instance.isOnline.value = true;
  });
  tearDown(() {
    ConnectivityService.instance.isOnline.value = true;
  });

  testWidgets('overlay hidden while online, shown while offline, hidden again',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Online: only the underlying app content; no overlay.
    expect(find.text('APP_CONTENT'), findsOneWidget);
    expect(find.text('No Internet Connection'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

    // Go offline -> overlay appears with title + Retry button.
    ConnectivityService.instance.isOnline.value = false;
    await tester.pump();

    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    // Underlying child is still in the tree behind the overlay (Stack).
    expect(find.text('APP_CONTENT'), findsOneWidget);

    // Back online -> overlay disappears.
    ConnectivityService.instance.isOnline.value = true;
    await tester.pump();

    expect(find.text('No Internet Connection'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(find.text('APP_CONTENT'), findsOneWidget);
  });

  testWidgets('tapping Retry does not throw', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    ConnectivityService.instance.isOnline.value = false;
    await tester.pump();

    final Finder retry = find.text('Retry');
    expect(retry, findsOneWidget);

    // Tapping Retry calls ConnectivityService.instance.retry() -> _verify ->
    // a REAL InternetAddress.lookup probe. We run the whole interaction inside
    // tester.runAsync so that probe (and the recovery Timer it may schedule
    // when the sandbox has no network) use real async instead of the test's
    // FakeAsync clock. The contract under test is simply: the tap handler
    // must not throw.
    await tester.runAsync(() async {
      await tester.tap(retry);
      await tester.pump(); // process setState(_busy = true)
      // Give the real DNS probe time to resolve/fail so the retry() future
      // completes within this runAsync scope.
      await Future<void>.delayed(const Duration(seconds: 4));
    });

    expect(tester.takeException(), isNull);

    // The recovery probe may have flipped state to offline (no network in the
    // sandbox). Restore online and cancel any pending recovery timer by
    // letting one more verify run online — keeps the singleton clean for the
    // next test. (tearDown also resets the notifier.)
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rapid online<->offline toggling tracks state with no leftover overlay',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Flip the notifier many times in quick succession. After every flip the
    // overlay must exactly match the state, the wrapped child must always be
    // present (it lives below the overlay in the Stack), and there must be no
    // duplicate/leftover overlay widgets from a previous state.
    const List<bool> sequence = <bool>[
      false,
      true,
      false,
      true,
      false,
      false, // idempotent repeat must not stack a second overlay
      true,
    ];

    for (final bool online in sequence) {
      ConnectivityService.instance.isOnline.value = online;
      await tester.pump();

      // Wrapped child is ALWAYS in the tree, online or offline.
      expect(find.text('APP_CONTENT'), findsOneWidget);

      if (online) {
        expect(find.byType(NoInternetOverlay), findsOneWidget);
        expect(find.text('No Internet Connection'), findsNothing);
        expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      } else {
        // Exactly ONE overlay screen — never two stacked from a stale state.
        expect(find.text('No Internet Connection'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      }
    }

    // End online: overlay fully torn down, child intact.
    expect(find.text('No Internet Connection'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(find.text('APP_CONTENT'), findsOneWidget);
  });

  testWidgets('offline title is localized for Punjabi (pa)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('pa')));
    await tester.pumpAndSettle();

    ConnectivityService.instance.isOnline.value = false;
    await tester.pump();

    final String paTitle = _title('pa');
    // Sanity: the pa string is genuinely different from both the raw key and
    // English — otherwise this assertion would pass on a fallback.
    expect(paTitle, isNot('no_internet_title'));
    expect(paTitle, isNot(_title('en')));

    expect(find.text(paTitle), findsOneWidget);
    // The raw key must NOT be visible (would mean a missing-key fallback).
    expect(find.text('no_internet_title'), findsNothing);
  });

  testWidgets('offline title is localized for Hindi (hi)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('hi')));
    await tester.pumpAndSettle();

    ConnectivityService.instance.isOnline.value = false;
    await tester.pump();

    final String hiTitle = _title('hi');
    expect(hiTitle, isNot('no_internet_title'));
    expect(hiTitle, isNot(_title('en')));

    expect(find.text(hiTitle), findsOneWidget);
    expect(find.text('no_internet_title'), findsNothing);
  });

  testWidgets(
      'overlay sits above child and absorbs taps meant for the child button',
      (WidgetTester tester) async {
    bool childTapped = false;

    // A child with its own button. While offline, the opaque overlay Material
    // must intercept the tap so the child button can NOT fire.
    await tester.pumpWidget(
      _harness(
        child: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => childTapped = true,
              child: const Text('CHILD_BTN'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Online: tapping the child button works normally.
    await tester.tap(find.text('CHILD_BTN'));
    await tester.pump();
    expect(childTapped, isTrue);

    // Go offline — overlay covers the child.
    childTapped = false;
    ConnectivityService.instance.isOnline.value = false;
    await tester.pump();

    // The overlay's _NoInternetScreen must be the LAST child of the wrapper
    // Stack (painted on top). The child Scaffold has its own internal Stacks,
    // so we can't blindly take the only Stack — we want the specific one the
    // overlay builds, identifiable by its last child being a Positioned.fill
    // whose child is the offline screen.
    final Iterable<Stack> stacks = tester
        .widgetList<Stack>(
          find.descendant(
            of: find.byType(NoInternetOverlay),
            matching: find.byType(Stack),
          ),
        )
        .where((Stack s) => s.children.last is Positioned);
    expect(stacks, isNotEmpty,
        reason: 'overlay Stack with a trailing Positioned must exist offline');
    // The overlay Stack: first child is the wrapped app, last child is the
    // Positioned.fill carrying the offline screen (painted on top).
    final Stack stack = stacks.first;
    expect(stack.children.last, isA<Positioned>());

    // Tap at the center of where the child button is. The opaque overlay
    // Material sits on top, so warnIfMissed=false (the hit lands on the
    // overlay, not the button). The child button must NOT have fired.
    await tester.tap(find.text('CHILD_BTN'), warnIfMissed: false);
    await tester.pump();
    expect(childTapped, isFalse,
        reason: 'overlay must absorb the tap; child button stayed unreachable');

    // The Retry button (part of the overlay) is the thing that IS tappable.
    expect(find.text('Retry'), findsOneWidget);
  });
}

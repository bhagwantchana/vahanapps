import 'dart:async';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/settings_cubit/settings_cubit.dart';
import 'package:fleet_monitor/firebase_options.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/routes.dart';
import 'package:fleet_monitor/screens/splash_screen.dart';
import 'package:fleet_monitor/services/array_providers.dart';
import 'package:fleet_monitor/services/connectivity_service.dart';
import 'package:fleet_monitor/services/local_notification.dart';
import 'package:fleet_monitor/widgets/no_internet_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<void> main() async {
  // Crashlytics needs `runZonedGuarded` to catch async errors that the
  // FlutterError handler doesn't see. We wrap the whole bootstrap in a
  // zone and forward every uncaught error to Crashlytics.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Render the MapLibre platform view via Android Hybrid Composition so the
    // native map attaches to the Activity (not a Virtual Display). Without
    // this, tapping a map attribution link crashed the app with an
    // AndroidRuntimeException — the native showWebPage() called
    // context.startActivity from a non-Activity context without
    // FLAG_ACTIVITY_NEW_TASK. Hybrid composition fixes the crash and keeps the
    // clickable OpenStreetMap / OpenFreeMap attribution intact.
    MapLibreMap.useHybridComposition = true;

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Crashlytics setup is best-effort. If the project doesn't have
    // Crashlytics enabled in the Firebase console (or the native plugin
    // failed to link), the app must still boot — we just lose crash
    // reporting until it's configured. Without this try/catch, a missing
    // Crashlytics service kills the app on first launch which is exactly
    // the symptom we hit.
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = (errorDetails) {
        crashlytics.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e, st) {
      // Crashlytics couldn't init — log to console only so the rest of
      // the boot continues. Common reasons: console hasn't enabled the
      // Crashlytics product on this Firebase project, google-services
      // JSON is stale, or the Crashlytics Gradle plugin failed to apply.
      // ignore: avoid_print
      print('Crashlytics init skipped: $e\n$st');
    }

    await CustomNotificationSoundService().initialize();
    // Start watching internet reachability so the global "No internet" overlay
    // can take over when connectivity drops (see NoInternetOverlay below).
    ConnectivityService.instance.init();
    Bloc.observer = MyBlocObserver();
    runApp(const MyApp());
  }, (error, stack) {
    // Async errors that escaped the zones above. Try Crashlytics, fall
    // back to console so the error isn't silently swallowed when
    // Crashlytics is unavailable.
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // ignore: avoid_print
      print('Uncaught zone error: $error\n$stack');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CustomNotificationSoundService().flushPendingNavigation();
    });
    return MultiBlocProvider(
      providers: ArrayProviders.providers,
      // SettingsCubit drives locale + themeMode at runtime. The BlocBuilder
      // here rebuilds MaterialApp when the user changes language / theme
      // in the profile screen so the change is immediate, app-wide.
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            // Localisation: ships with English, Hindi, Punjabi. Device locale
            // is the default; user can override via Profile → Language. The
            // SettingsCubit-backed `locale` above takes priority over the
            // device when non-null.
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppStrings.supportedLocales,
            // Global "No internet" screen layered above every route. It only
            // surfaces when a real reachability probe fails, and auto-dismisses
            // when the connection returns.
            builder: (context, child) =>
                NoInternetOverlay(child: child ?? const SizedBox.shrink()),
            onGenerateRoute: Routes.onGenerateRoute,
            initialRoute: SplashScreen.routeName,
          );
        },
      ),
    );
  }
}

class MyBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase<dynamic> bloc) {
    log('Created: $bloc');
    super.onCreate(bloc);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    log('Change in $bloc: $change');
    super.onChange(bloc, change);
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    log('Transition in $bloc: $transition');
    super.onTransition(bloc, transition);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    log('Closed: $bloc');
    super.onClose(bloc);
  }
}

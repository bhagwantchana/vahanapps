import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/firebase_options.dart';
import 'package:fleet_monitor/routes.dart';
import 'package:fleet_monitor/screens/splash_screen.dart';
import 'package:fleet_monitor/services/array_providers.dart';
import 'package:fleet_monitor/services/local_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CustomNotificationSoundService().initialize();
  Bloc.observer = MyBlocObserver();
  runApp(const MyApp());
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.system,
        onGenerateRoute: Routes.onGenerateRoute,
        initialRoute: SplashScreen.routeName,
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

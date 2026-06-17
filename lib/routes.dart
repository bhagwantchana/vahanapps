import 'package:fleet_monitor/providers/login_provider.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/screens/splash_screen.dart';
import 'package:fleet_monitor/screens/sub_users_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class Routes {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case LoginScreen.routeName:
        return CupertinoPageRoute<dynamic>(
          builder: (context) => ChangeNotifierProvider<LoginProvider>(
            create: (context) => LoginProvider(context),
            child: const LoginScreen(),
          ),
        );
      case SplashScreen.routeName:
        return CupertinoPageRoute<dynamic>(
          builder: (context) => const SplashScreen(),
        );
      case DashboardScreen.routeName:
        final initialIndex = settings.arguments is int
            ? settings.arguments as int
            : 0;
        return CupertinoPageRoute<dynamic>(
          builder: (context) => DashboardScreen(initialIndex: initialIndex),
        );
      case SubUsersScreen.routeName:
        return CupertinoPageRoute<dynamic>(
          builder: (context) => const SubUsersScreen(),
        );
      default:
        return null;
    }
  }
}

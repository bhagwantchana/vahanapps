// import 'package:fleet_monitor/cubits/user_cubit/user_cubit.dart';
// import 'package:fleet_monitor/cubits/user_cubit/user_state.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// class Functions {
//   void goToNextScreen() {
//     UserState userState = BlocProvider.of<UserCubit>(context).state;
//     if (userState is UserLoggedInState) {
//       print("$userState state_11");
//       Navigator.popUntil(context, (route) => route.isFirst);
//       Navigator.pushReplacementNamed(context, HomeScreen.routeName);
//     } else if (userState is UserLoggedOutState) {
//       print("$userState state_12");
//       Navigator.popUntil(context, (route) => route.isFirst);
//       Navigator.pushReplacementNamed(context, LoginScreen.routeName);
//     } else if (userState is UserErrorState) {
//       print("$userState state_13");
//       Navigator.popUntil(context, (route) => route.isFirst);
//       Navigator.pushReplacementNamed(context, LoginScreen.routeName);
//     }
//   }
// }

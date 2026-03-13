import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';

class ArrayProviders {
  static List<SingleChildWidget> providers = [
    BlocProvider(create: (context) => AuthCubit()),
    BlocProvider(create: (context) => HomeCubit()),
    BlocProvider(create: (context) => ProfileCubit()),
  ];
}

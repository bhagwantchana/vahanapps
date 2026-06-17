import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/settings_cubit/settings_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';

class ArrayProviders {
  static List<SingleChildWidget> providers = <SingleChildWidget>[
    BlocProvider<AuthCubit>(create: (context) => AuthCubit()),
    BlocProvider<VehicleCubit>(create: (context) => VehicleCubit()),
    BlocProvider<ProfileCubit>(create: (context) => ProfileCubit()),
    BlocProvider<HomeCubit>(create: (context) => HomeCubit()),
    BlocProvider<SingleTrackCubit>(create: (context) => SingleTrackCubit()),
    BlocProvider<AlertsCubit>(create: (context) => AlertsCubit()),
    // SettingsCubit holds locale + theme overrides; loads persisted prefs
    // asynchronously on construction. Keep it last so other cubits don't
    // accidentally depend on a not-yet-loaded settings state.
    BlocProvider<SettingsCubit>(create: (context) => SettingsCubit()),
  ];
}

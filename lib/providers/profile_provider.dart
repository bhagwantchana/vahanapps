// import 'dart:async';
// import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
// import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker/image_picker.dart';

// class ProfileProvider with ChangeNotifier {
//   final BuildContext context;
//   ProfileProvider(this.context) {
//     _listenToProfileCubit();
//   }
//   bool isLoading = false;
//   String error = "";

//   final nameController = TextEditingController();
//   final emailController = TextEditingController();
//   final phoneController = TextEditingController();
//   String profileImageUrl = "";
//   final formKey = GlobalKey<FormState>();
//   StreamSubscription? profileSubscription;

//   void setLoading(bool value) {
//     isLoading = value;
//     notifyListeners();
//   }

//   void setError(String value) {
//     error = value;
//     notifyListeners();
//   }

//   void _listenToProfileCubit() {
//     profileSubscription = BlocProvider.of<ProfileCubit>(context).stream.listen((
//       profileState,
//     ) {
//       if (profileState is ProfileLoadingState) {
//         isLoading = true;
//         error = "";
//         notifyListeners();
//       } else if (profileState is ProfileErrorState) {
//         isLoading = false;
//         error = profileState.message;
//         notifyListeners();
//       } else if (profileState is ProfileLoggedInState &&
//           profileState.userProfileModel?.data != null) {
//         isLoading = false;
//         error = "";
//         final userData = profileState.userProfileModel!.data!;
//         nameController.text =
//             "${userData.firstName ?? ""} ${userData.lastName ?? ""}".trim();
//         emailController.text = userData.email ?? "";
//         phoneController.text = userData.phone ?? "";
//         if (userData.image != null && userData.image!.isNotEmpty) {
//           profileImageUrl = userData.image!;
//         }
//         notifyListeners();
//       } else {
//         isLoading = false;
//         error = "";
//         notifyListeners();
//       }
//     });
//   }

//   Future<void> pickImage() async {
//     final image = await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (image != null) {
//       profileImageUrl = image.path;
//       notifyListeners();
//     }
//   }

//   Future<void> saveProfile() async {
//     setLoading(true);
//     debugPrint("Saving Profile Changes:");
//     debugPrint("Name: ${nameController.text}");
//     debugPrint("Email: ${emailController.text}");
//     debugPrint("Profile Image: $profileImageUrl");
//     // Simulate API call
//     await Future.delayed(const Duration(seconds: 1));
//     setLoading(false);
//   }

//   @override
//   void dispose() {
//     profileSubscription?.cancel();
//     nameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     super.dispose();
//   }
// }

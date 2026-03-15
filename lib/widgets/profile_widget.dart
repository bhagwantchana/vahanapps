import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isEditing = false;
  String? _pickedImagePath;

  Future<void> _pickImage(Data userData) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImagePath = image.path;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider _getAvatarImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImageProvider(imageUrl);
    } else {
      return FileImage(File(imageUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoadingState) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Loading your profile...",
                        style: TextStyle(
                          color: AppColors.secondary.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (state is ProfileErrorState) {
                return Center(child: Text("Error: ${state.message}"));
              }
              final userData = state.userProfileModel?.data;

              if (userData == null) {
                return const Center(
                  child: CustomText(text: 'No profile found'),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: _buildProfileCard(userData),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Data userData) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 24, right: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Profile",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = !_isEditing;
                          if (!_isEditing) {
                            _pickedImagePath = null;
                          }
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? AppColors.green.withValues(alpha: 0.1)
                              : AppColors.blueLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isEditing ? Icons.check : Icons.edit_outlined,
                          color: _isEditing
                              ? AppColors.green
                              : AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Stack(
                alignment: Alignment.center,
                children: [
                  const Divider(color: AppColors.lightGrey, thickness: 1),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundImage: _getAvatarImage(
                        _pickedImagePath ?? userData.image ?? "",
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right:
                        (MediaQuery.of(context).size.width - 40) / 2 - 65 + 10,
                    child: InkWell(
                      onTap: _isEditing ? () => _pickImage(userData) : null,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? AppColors.green
                              : AppColors.secondary.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isEditing
                              ? Icons.camera_alt_outlined
                              : Icons.lock_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildAnimatedField(
                      0,
                      Icons.person_outline,
                      "Full Name",
                      userData.firstName!,
                      isReadOnly: !_isEditing,
                      onChanged: (value) {
                        userData.firstName = value;
                      },
                    ),
                    _buildAnimatedField(
                      0,
                      Icons.person_outline,
                      "Last Name",
                      userData.lastName!,
                      isReadOnly: !_isEditing,
                      onChanged: (value) {
                        userData.lastName = value;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildAnimatedField(
                      1,
                      Icons.email_outlined,
                      "Email Address",
                      userData.email!,
                      isReadOnly: !_isEditing,
                      onChanged: (value) {
                        userData.email = value;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildAnimatedField(
                      2,
                      Icons.phone_outlined,
                      "Phone",
                      userData.phone!,
                      prefix: _buildCountryPrefix(),
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 20),

                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      _buildSaveButton(userData, _pickedImagePath),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(Data userData, String? file) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final staggerAnimation = CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: staggerAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(staggerAnimation),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () async {
            if (mounted) {
              setState(() {
                _isEditing = false;
                _pickedImagePath = null;
              });
              BlocProvider.of<ProfileCubit>(context).updateProfile(
                name: userData.firstName,
                lastNam: userData.lastName,
                email: userData.email,
                file: file,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            "Save Changes",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryPrefix() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              image: DecorationImage(
                image: AssetImage(Assets.images.indianFlag.path),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CustomText(text: "•", color: AppColors.accent, fontSize: 20),
        ],
      ),
    );
  }

  Widget _buildAnimatedField(
    int index,
    IconData icon,
    String label,
    String value, {
    bool isDropdown = false,
    Widget? prefix,
    bool isReadOnly = false,
    Function(String)? onChanged,
  }) {
    final staggerAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        (0.2 + (index * 0.1)).clamp(0.0, 1.0),
        (0.7 + (index * 0.1)).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );

    return FadeTransition(
      opacity: staggerAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.1, 0),
          end: Offset.zero,
        ).animate(staggerAnimation),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.secondary, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.lightGrey.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  if (prefix != null) prefix,
                  Expanded(
                    child: TextFormField(
                      initialValue: value,
                      readOnly: isReadOnly,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: onChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (isDropdown)
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.secondary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

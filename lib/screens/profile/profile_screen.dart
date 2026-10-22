import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

import '../auth/ChangePasswordScreen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firstName = AuthDataHelper.getFirstName();
    final lastName = AuthDataHelper.getLastName();
    final fullName = [firstName, lastName]
        .where((s) => s.trim().isNotEmpty)
        .join(' ')
        .trim();
    final displayName = fullName.isNotEmpty ? fullName : 'User';
    final email = AuthDataHelper.getEmail();
    final mobile = AuthDataHelper.getMobile();

    final fullNameCtrl = TextEditingController(text: displayName);
    final usernameCtrl = TextEditingController(text: mobile);
    final emailCtrl    = TextEditingController(text: email);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(title: "Profile", onActionPressed: () {}),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Profile photo — uses the real stored URL for the logged-in user.
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey.shade200,
                    child: ClipOval(child: _buildCurrentUserAvatar()),
                  ),
                  Container(
                    height: 28,
                    width: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.main,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: AppColors.white, size: 16),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Text(
                displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                email,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              _buildField("Full Name", fullNameCtrl),
              _buildField("Username", usernameCtrl),
              _buildField("Email", emailCtrl),

              const SizedBox(height: 20),

              MainButton(text: 'Save Changes', onPressed: () {}),

              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Change Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.main,
                  side: const BorderSide(color: AppColors.main),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the current logged-in user's profile picture.
  /// Priority: stored network URL → stored local file path → default icon.
  Widget _buildCurrentUserAvatar() {
    final url = AuthDataHelper.getProfileImage();

    if (url.isNotEmpty && url.startsWith('http')) {
      return FadeInImage.assetNetwork(
        placeholder: 'assets/icons/default_ic_user.png',
        image: url,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    }

    if (url.isNotEmpty) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, width: 90, height: 90, fit: BoxFit.cover);
      }
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Image.asset(
      'assets/icons/default_ic_user.png',
      width: 90,
      height: 90,
      fit: BoxFit.cover,
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.main, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

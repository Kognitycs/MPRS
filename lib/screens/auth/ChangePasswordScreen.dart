import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _oldVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateOldPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your current password';
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter a new password';
    if (value.trim().length < 6) return 'Password must be at least 6 characters';
    if (value.trim() == _oldPasswordCtrl.text.trim()) {
      return 'New password must differ from current password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please confirm your new password';
    if (value.trim() != _newPasswordCtrl.text.trim()) return 'Passwords do not match';
    return null;
  }

  // ── API call ──────────────────────────────────────────────────────────────

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    ProgressLoader.show(context);

    try {
      final token = AuthDataHelper.getToken();

      // ✅ Prepare request body
      final requestBody = {
        'oldPassword': _oldPasswordCtrl.text.trim(),
        'newPassword': _newPasswordCtrl.text.trim(),
        'confirmPassword': _confirmPasswordCtrl.text.trim(),
      };

      // ✅ Debug print
      print("REQUEST BODY: ${jsonEncode(requestBody)}");
      print("TOKEN: $token");
      print("URL: ${ApiConstants.changePassword}");

      // ✅ API call (ONLY ONCE)
      final response = await HttpClientHelper.postWithBearer(
        ApiConstants.changePassword,
        token,
        body: jsonEncode(requestBody), // 🔥 IMPORTANT
        headers: {
          'Content-Type': 'application/json',
        },
      );

      ProgressLoader.hide(context);

      if (!mounted) return;

      // ✅ Success
      if (response.statusCode == 200) {
        showSnackBar(
          context,
          'Password changed successfully',
          backgroundColor: AppColors.green,
        );

        Navigator.pop(context);
      } else {
        // ❌ Error handling
        String message = 'Something went wrong';
        try {
          final decoded = jsonDecode(response.data);
          message = decoded['message'] ?? message;
        } catch (_) {}

        showSnackBar(
          context,
          message,
          backgroundColor: AppColors.secondary,
        );
      }
    } catch (e) {
      ProgressLoader.hide(context);

      if (mounted) {
        showSnackBar(
          context,
          'Error: $e',
          backgroundColor: AppColors.secondary,
        );
      }
    }
  }
  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CommonAppBar(title: 'Change Password'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.main_10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.main.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.main, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update your password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.main,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose a strong password with at least 6 characters.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildPasswordField(
                controller: _oldPasswordCtrl,
                label: 'Current Password',
                isVisible: _oldVisible,
                onToggle: () => setState(() => _oldVisible = !_oldVisible),
                validator: _validateOldPassword,
              ),

              const SizedBox(height: 16),

              _buildPasswordField(
                controller: _newPasswordCtrl,
                label: 'New Password',
                isVisible: _newVisible,
                onToggle: () => setState(() => _newVisible = !_newVisible),
                validator: _validateNewPassword,
              ),

              const SizedBox(height: 16),

              _buildPasswordField(
                controller: _confirmPasswordCtrl,
                label: 'Confirm New Password',
                isVisible: _confirmVisible,
                onToggle: () => setState(() => _confirmVisible = !_confirmVisible),
                validator: _validateConfirmPassword,
              ),

              const SizedBox(height: 36),

              MainButton(text: 'Update Password', onPressed: _changePassword),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,

        filled: true,
        fillColor: AppColors.white,

        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey,
            size: 22,
          ),
          onPressed: onToggle,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.main, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.secondary, fontSize: 12),

        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}
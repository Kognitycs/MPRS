import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/model/country_code_model.dart';
import 'package:mprs_android/model/template_list_response.dart';

const _signupFieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.zero,
  borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 1),
);

/// Signup screen text field: label above, red asterisk after label, sharp border.
Widget buildSignupTextField({
  required String label,
  String? hint,
  TextEditingController? controller,
  Function(String)? onChanged,
  bool editable = true,
  bool isRequired = false,
  TextInputType inputType = TextInputType.text,
  bool obscureText = false,
  String? errorText,
  List<TextInputFormatter>? inputFormatters,
}) {
  final hasError = errorText != null;

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTextStyles.montserratSemiBold.copyWith(
              fontSize: 14,
              color: AppColors.black,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: inputType,
          enabled: editable,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          style: AppTextStyles.montserratSemiBold.copyWith(
            fontSize: 14,
            color: editable ? AppColors.black : AppColors.grey,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.montserratRegular.copyWith(
              fontSize: 14,
              color: AppColors.lightGrey,
            ),
            filled: true,
            fillColor: editable ? AppColors.white : Colors.grey.shade200,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            enabledBorder: _signupFieldBorder.copyWith(
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF1A1A1A),
                width: 1,
              ),
            ),
            focusedBorder: _signupFieldBorder.copyWith(
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF1A1A1A),
                width: 1,
              ),
            ),
            disabledBorder: _signupFieldBorder,
            errorBorder: _signupFieldBorder.copyWith(
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: _signupFieldBorder.copyWith(
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

/// Signup screen dropdown: same label/border styling as [buildSignupTextField].
Widget buildSignupDropdown({
  required BuildContext context,
  required String label,
  required String hint,
  required List<String> items,
  required String? value,
  required Function(String?) onChanged,
  bool isRequired = false,
  String? errorText,
  bool enabled = true,
}) {
  final hasError = errorText != null;

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTextStyles.montserratSemiBold.copyWith(
              fontSize: 14,
              color: AppColors.black,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: enabled
              ? () {
                  _showSearchableDropdown(
                    context: context,
                    title: label,
                    items: items,
                    onSelected: onChanged,
                  );
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: value == null ? hint : null,
              hintStyle: AppTextStyles.montserratRegular.copyWith(
                fontSize: 14,
                color: AppColors.lightGrey,
              ),
              filled: true,
              fillColor: enabled ? AppColors.white : Colors.grey.shade200,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.black,
              ),
              enabledBorder: _signupFieldBorder.copyWith(
                borderSide: BorderSide(
                  color: hasError ? Colors.red : const Color(0xFF1A1A1A),
                  width: 1,
                ),
              ),
              focusedBorder: _signupFieldBorder.copyWith(
                borderSide: BorderSide(
                  color: hasError ? Colors.red : const Color(0xFF1A1A1A),
                  width: 1,
                ),
              ),
              disabledBorder: _signupFieldBorder,
              errorBorder: _signupFieldBorder.copyWith(
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: _signupFieldBorder.copyWith(
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
            ),
            child: Text(
              value ?? '',
              style: AppTextStyles.montserratSemiBold.copyWith(
                fontSize: 14,
                color: enabled ? AppColors.black : AppColors.grey,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

/// Signup screen password field with the same styling as [buildSignupTextField].
Widget buildSignupPasswordField({
  required String label,
  String? hint,
  TextEditingController? controller,
  Function(String)? onChanged,
  bool isRequired = false,
  bool obscureText = false,
  VoidCallback? onTogglePassword,
  String? errorText,
}) {
  final hasError = errorText != null;

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTextStyles.montserratSemiBold.copyWith(
              fontSize: 14,
              color: AppColors.black,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          style: AppTextStyles.montserratSemiBold.copyWith(
            fontSize: 14,
            color: AppColors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.montserratRegular.copyWith(
              fontSize: 14,
              color: AppColors.lightGrey,
            ),
            filled: true,
            fillColor: AppColors.white,
            suffixIcon: onTogglePassword == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.lightGrey,
                      size: 22,
                    ),
                    onPressed: onTogglePassword,
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            enabledBorder: _signupFieldBorder.copyWith(
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF1A1A1A),
                width: 1,
              ),
            ),
            focusedBorder: _signupFieldBorder.copyWith(
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF1A1A1A),
                width: 1,
              ),
            ),
            errorBorder: _signupFieldBorder.copyWith(
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: _signupFieldBorder.copyWith(
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

/// Country code selector prefix for signup mobile fields (inside the text box).
Widget buildSignupCountryPrefix({
  required CountryCodeModel? country,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (country != null) ...[
          Text(country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(
            country.dialCode,
            style: AppTextStyles.montserratSemiBold.copyWith(
              fontSize: 14,
              color: AppColors.black,
            ),
          ),
        ] else
          const Text('+'),
        const SizedBox(width: 4),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      ],
    ),
  );
}

/// Signup mobile field with country code picker (same UX as login, signup styling).
Widget buildSignupMobileField({
  required BuildContext context,
  required String label,
  String? hint,
  required TextEditingController controller,
  required CountryCodeModel selectedCountry,
  required List<CountryCodeModel> countryCodes,
  required ValueChanged<CountryCodeModel> onCountrySelected,
  bool isRequired = false,
  String? errorText,
  Function(String)? onChanged,
  List<TextInputFormatter>? inputFormatters,
  bool showVerifyAction = false,
  bool isMobileVerified = false,
  VoidCallback? onVerifyTap,
}) {
  final hasError = errorText != null;

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTextStyles.montserratSemiBold.copyWith(
              fontSize: 14,
              color: AppColors.black,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(
              color: hasError ? Colors.red : const Color(0xFF1A1A1A),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: TextInputType.phone,
                  inputFormatters: inputFormatters,
                  style: AppTextStyles.montserratSemiBold.copyWith(
                    fontSize: 14,
                    color: AppColors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.montserratRegular.copyWith(
                      fontSize: 14,
                      color: AppColors.lightGrey,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8),
                      child: buildSignupCountryPrefix(
                        country: selectedCountry,
                        onTap: () {
                          showSearchableCountryDropdown(
                            context: context,
                            title: 'Country Code',
                            items: countryCodes,
                            onSelected: onCountrySelected,
                          );
                        },
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (showVerifyAction)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: isMobileVerified ? null : onVerifyTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      isMobileVerified ? 'Verified' : 'Verify',
                      style: AppTextStyles.montserratSemiBold.copyWith(
                        fontSize: 14,
                        color: isMobileVerified
                            ? AppColors.green
                            : AppColors.secondary,
                        decoration: isMobileVerified
                            ? null
                            : TextDecoration.underline,
                        decorationColor: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

Widget buildPasswordField({
  required String label,
  String? hint,
  TextEditingController? controller,
  Function(String)? onChanged,
  bool editable = true,
  bool isRequired = false,
  TextInputType inputType = TextInputType.text,
  bool obscureText = false,
  VoidCallback? onTogglePassword,
  String? errorText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: inputType,
          readOnly: !editable,
          obscureText: obscureText,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            // 🔴 Mandatory star before label
            label: RichText(
              text: TextSpan(
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: '* ',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  TextSpan(
                    text: label,
                    style: TextStyle(color: AppColors.lightGrey, fontSize: 16),
                  ),
                ],
              ),
            ),
            hintText: hint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintStyle: TextStyle(color: AppColors.lightGrey, fontSize: 15),
            filled: true,
            fillColor: AppColors.white,
            suffixIcon:
                onTogglePassword == null
                    ? null
                    : IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.lightGrey,
                      ),
                      onPressed: onTogglePassword,
                    ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightGrey),
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

        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

Widget buildRoundedDropdown({
  required BuildContext context,
  required String label,
  required String hint,
  required List<String> items,
  required String? value,
  required Function(String?) onChanged,
  bool enabled = true,
  String? errorText, // <-- NEW
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: enabled ? () {
            _showSearchableDropdown(
              context: context,
              title: label,
              items: items,
              onSelected: (selectedValue) {
                onChanged(selectedValue);
              },
            );
          } : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: TextStyle(color: AppColors.lightGrey, fontSize: 16),
              hintText: hint,
              filled: true,
              fillColor: enabled ? AppColors.white : Colors.grey[200],
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.lightGrey,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.main,
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            child: Text(
              value ?? hint,
              style: TextStyle(
                fontSize: 16,
                color: value == null ? AppColors.lightGrey : (enabled ? Colors.black : Colors.grey),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // ▼ SHOW ERROR
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

Widget buildRoundedDropdownWithArrow({
  required BuildContext context,
  required String label,
  required String hint,
  bool isRequired = false,

  required List<String> items,
  required String? value,
  required Function(String?)? onChanged,
  bool enabled = true,
  String? errorText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap:
              (enabled && onChanged != null)
                  ? () {
                    _showSearchableDropdown(
                      context: context,
                      title: label,
                      items: items,
                      onSelected: (selectedValue) {
                        onChanged(selectedValue);
                      },
                    );
                  }
                  : null,
          child: InputDecorator(
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: '* ',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: (enabled && onChanged != null) 
                            ? AppColors.lightGrey 
                            : Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: TextStyle(
                color: (enabled && onChanged != null) 
                    ? AppColors.lightGrey 
                    : Colors.grey.shade400,
                fontSize: 16,
              ),
              hintText: hint,
              filled: true,
              fillColor: (enabled && onChanged != null) 
                  ? AppColors.white 
                  : Colors.grey.shade100,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null 
                      ? Colors.red 
                      : (enabled && onChanged != null)
                          ? AppColors.lightGrey
                          : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.main,
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value ?? hint,
                  style: TextStyle(
                    fontSize: 16,
                    color: value == null 
                        ? AppColors.lightGrey 
                        : (enabled && onChanged != null)
                            ? Colors.black
                            : Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: (enabled && onChanged != null) 
                      ? AppColors.lightGrey 
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),

        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

Widget buildRoundedDropdownWithCheckbox({
  required BuildContext context,
  required String label,
  required String hint,
  bool isRequired = false,
  required List<String> items,
  required List<String> selectedValues,
  required Function(List<String>) onChanged,
  String? errorText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            // Open bottom sheet with checkboxes
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) {
                List<String> tempSelected = List.from(selectedValues);
                return StatefulBuilder(
                  builder: (context, setState) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...items.map((item) {
                              final isChecked = tempSelected.contains(item);
                              return CheckboxListTile(
                                title: Text(item),
                                value: isChecked,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      tempSelected.add(item);
                                    } else {
                                      tempSelected.remove(item);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                onChanged(tempSelected);
                                Navigator.pop(context);
                              },
                              child: const Text("Done"),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          child: InputDecorator(
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: '* ',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: AppColors.lightGrey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: hint,
              filled: true,
              fillColor: AppColors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.lightGrey,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.main,
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedValues.isEmpty ? hint : selectedValues.join(", "),
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          selectedValues.isEmpty
                              ? AppColors.lightGrey
                              : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.lightGrey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),

        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

Widget buildRoundedDropdownForSchedule({
  required BuildContext context,
  required String label,
  required String hint,
  bool isRequired = false,
  required Function(DateTime) onSelectedDateTime,
  String? selectedValue,
  String? errorText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final choice = await showModalBottomSheet<String>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text("Send Immediate"),
                      onTap: () {
                        Navigator.pop(context, "Send Immediate");
                      },
                    ),
                    ListTile(
                      title: const Text("Custom"),
                      onTap: () {
                        Navigator.pop(context, "Custom");
                      },
                    ),
                  ],
                );
              },
            );

            if (choice == null) return;

            if (choice == "Send Immediate") {
              onSelectedDateTime(DateTime.now());
            } else if (choice == "Custom") {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (pickedDate == null) return;

              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (pickedTime == null) return;

              final finalDateTime = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              onSelectedDateTime(finalDateTime);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: '* ',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: AppColors.lightGrey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: hint,
              filled: true,
              fillColor: AppColors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.lightGrey,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.main,
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedValue ?? hint,
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          selectedValue == null
                              ? AppColors.lightGrey
                              : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.lightGrey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

// Updated Dropdown Widget
String _templateDropdownLabel(TemplateModel template) {
  final name = (template.templateName ?? '').trim();
  if (name.isNotEmpty) return name;

  final header = (template.templateHeader ?? '').trim();
  if (header.isNotEmpty) return header;

  final type = (template.templateType ?? '').trim();
  if (type.isNotEmpty) return type;

  return 'Template';
}

Widget buildRoundedDropdownWithTemplates({
  required BuildContext context,
  required String label,
  bool isRequired = false,
  required String hint,
  required List<TemplateModel> items,
  required TemplateModel? selectedItem,
  required Function(TemplateModel?) onChanged,
  String? errorText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap:
              items.isEmpty
                  ? null
                  : () {
                    _showSearchableDropdownTemplates(
              context: context,
              title: label,
              items: items,
              onSelected: (TemplateModel item) {
                onChanged(item);
              },
            );
          },
          child: InputDecorator(
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: '* ',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: AppColors.lightGrey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: TextStyle(color: AppColors.lightGrey, fontSize: 16),
              hintText: hint,
              filled: true,
              fillColor: AppColors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.lightGrey,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.main,
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedItem != null
                      ? _templateDropdownLabel(selectedItem)
                      : hint,
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        selectedItem == null
                            ? AppColors.lightGrey
                            : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.lightGrey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

// Updated Modal for TemplateModel
Future<void> _showSearchableDropdownTemplates({
  required BuildContext context,
  required String title,
  required List<TemplateModel> items,
  required Function(TemplateModel) onSelected,
}) async {
  TextEditingController searchController = TextEditingController();
  List<TemplateModel> filtered = List.from(items);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        filtered =
                            items
                                .where(
                                  (e) =>
                                      (e.templateType ?? "")
                                          .toLowerCase()
                                          .contains(value.toLowerCase()) ||
                                      (e.templateName ?? "")
                                          .toLowerCase()
                                          .contains(value.toLowerCase()) ||
                                      (e.templateHeader ?? "")
                                          .toLowerCase()
                                          .contains(value.toLowerCase()),
                                )
                                .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? const Center(
                              child: Text(
                                'No templates found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final item = filtered[index];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(item);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.templateType ?? "",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.templateName ?? "",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.templateHeader ?? "",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Divider(), // optional: separates each item
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showSearchableDropdown({
  required BuildContext context,
  required String title,
  required List<String> items,
  required Function(String) onSelected,
}) async {
  TextEditingController searchController = TextEditingController();
  List<String> filtered = List.from(items);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true, // very important
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔍 Search input
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        filtered =
                            items
                                .where(
                                  (e) => e.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ),
                                )
                                .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        return ListTile(
                          title: Text(filtered[index]),
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(filtered[index]);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget buildUserTextField({
  required String label,
  String? hint,
  TextEditingController? controller,
  Function(String)? onChanged,
  bool editable = true,
  bool isRequired = false,
  TextInputType inputType = TextInputType.text,
  bool obscureText = false,
  VoidCallback? onTogglePassword,
  String? errorText,
  List<TextInputFormatter>? inputFormatters,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: inputType,
          enabled: editable,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          style: TextStyle(
            color: editable ? Colors.black : Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            label: RichText(
              text: TextSpan(
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: '* ',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  TextSpan(
                    text: label,
                    style: TextStyle(color: AppColors.lightGrey, fontSize: 16),
                  ),
                ],
              ),
            ),
            hintText: hint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(color: AppColors.lightGrey, fontSize: 16),
            hintStyle: TextStyle(color: AppColors.lightGrey, fontSize: 15),
            filled: true,
            fillColor: editable ? AppColors.white : Colors.grey[200],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightGrey),
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

        // ▼ Inline ERROR below the field
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

Widget buildMessageTextField({
  required String label,
  String? hint,
  bool isRequired = false,
  TextEditingController? controller,
  Function(String)? onChanged,
  bool editable = true,
  TextInputType inputType = TextInputType.text,
  bool obscureText = false,
  VoidCallback? onTogglePassword,
  String? errorText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: inputType,
          readOnly: !editable,
          obscureText: obscureText,

          // ▼ NEW LINES
          minLines: 5, // show 5 lines by default
          maxLines: 5, // after 5 lines it scrolls

          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            label: RichText(
              text: TextSpan(
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: '* ',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  TextSpan(
                    text: label,
                    style: TextStyle(color: AppColors.lightGrey, fontSize: 16),
                  ),
                ],
              ),
            ),
            hintText: hint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(color: AppColors.lightGrey, fontSize: 16),
            hintStyle: TextStyle(color: AppColors.lightGrey, fontSize: 15),
            filled: true,
            fillColor: AppColors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightGrey),
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

        // ▼ Inline ERROR below the field
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

Widget buildCountryCodeWithMobileField({
  required BuildContext context,
  required CountryCodeModel? selectedCountry,
  required List<CountryCodeModel> items,
  required Function(CountryCodeModel) onCountryChanged,
  required TextEditingController mobileController,
  String? errorText,
  Function(String)? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        /// 🌍 COUNTRY CODE DROPDOWN
        GestureDetector(
          onTap: () {
            showSearchableCountryDropdown(
              context: context,
              title: "Country Code",
              items: items,
              onSelected: onCountryChanged,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              border: Border.all(
                color: errorText != null ? Colors.red : AppColors.lightGrey,
                width: 1.3,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedCountry != null) ...[
                  Text(
                    selectedCountry.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedCountry.dialCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  const Text("+"),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),

        /// 📱 MOBILE NUMBER FIELD
        Expanded(
          child: TextFormField(
            controller: mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: "Mobile Number",
              counterText: "",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: true,
              fillColor: AppColors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.lightGrey,
                  width: 1.3,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red : AppColors.main,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showSearchableCountryDropdown({
  required BuildContext context,
  required String title,
  required List<CountryCodeModel> items,
  required Function(CountryCodeModel) onSelected,
}) async {
  TextEditingController searchController = TextEditingController();
  List<CountryCodeModel> filtered = List.from(items);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// 🔍 SEARCH
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        filtered =
                            items
                                .where(
                                  (e) =>
                                      e.name.toLowerCase().contains(
                                        value.toLowerCase(),
                                      ) ||
                                      e.dialCode.contains(value),
                                )
                                .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search country or code",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final country = filtered[index];
                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(country.name),
                          trailing: Text(country.dialCode),
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(country);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

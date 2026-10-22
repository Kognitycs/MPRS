import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class SearchUserBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;

  const SearchUserBar({
    this.hintText = "Search user",
    this.onChanged,
    this.onSubmitted,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.grey, size: 22),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
      ),
    );
  }
}

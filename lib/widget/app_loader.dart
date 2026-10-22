import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: AppColors.main));
  }
}

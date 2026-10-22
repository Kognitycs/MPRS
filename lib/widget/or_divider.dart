
import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class OrDivider extends StatelessWidget {
  final Color dividerColor;
  final double thickness;
  final String text;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;

  const OrDivider({
    Key? key,
    this.dividerColor = AppColors.lightGrey,
    this.thickness = 1.0,
    this.text = "Or",
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = TextStyle(
      color: dividerColor,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, thickness: thickness)),
        Padding(
          padding: padding,
          child: Text(text, style: textStyle ?? defaultTextStyle),
        ),
        Expanded(child: Divider(color: dividerColor, thickness: thickness)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;

  final String label;
  final String? hint;
  final String? errorText;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;

  final int maxLines;
  final int? maxLength;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16.sp,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        counterStyle: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12.sp,
        ),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15.sp,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 15.sp,
        ),
        errorStyle: TextStyle(
          color: scheme.error,
          fontSize: 12.sp,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 15.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppRadii.medium.r,
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppRadii.medium.r,
          ),
          borderSide: BorderSide(
            color: AppColors.divider.withValues(
              alpha: 0.55,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppRadii.medium.r,
          ),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppRadii.medium.r,
          ),
          borderSide: BorderSide(
            color: scheme.error.withValues(
              alpha: 0.75,
            ),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppRadii.medium.r,
          ),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1.4,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppRadii.medium.r,
          ),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
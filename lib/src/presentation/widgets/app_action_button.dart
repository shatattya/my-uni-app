import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

enum AppActionButtonVariant {
  primary,
  secondary,
  destructive,
}

class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  final IconData? icon;
  final bool isLoading;
  final AppActionButtonVariant variant;

  final double height;

  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppActionButtonVariant.primary,
    this.height = 52,
  });

  Color _backgroundColor(BuildContext context) {
    switch (variant) {
      case AppActionButtonVariant.primary:
        return AppColors.primary;

      case AppActionButtonVariant.secondary:
        return AppColors.elevatedSurface;

      case AppActionButtonVariant.destructive:
        return Colors.redAccent;
    }
  }

  Color _foregroundColor(BuildContext context) {
    switch (variant) {
      case AppActionButtonVariant.primary:
      case AppActionButtonVariant.destructive:
        return Colors.white;

      case AppActionButtonVariant.secondary:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _foregroundColor(context);

    return SizedBox(
      width: double.infinity,
      height: height.h,
      child: Semantics(
        button: true,
        enabled: onPressed != null && !isLoading,
        label: isLoading ? '$label, loading' : label,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: _backgroundColor(context),
            foregroundColor: foregroundColor,
            disabledBackgroundColor:
            AppColors.elevatedSurface.withValues(alpha: 0.55),
            disabledForegroundColor:
            AppColors.textTertiary.withValues(alpha: 0.65),
            minimumSize: Size(
              double.infinity,
              height.h,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppRadii.medium.r,
              ),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: isLoading
                ? SizedBox(
              key: const ValueKey('loading'),
              width: 22.r,
              height: 22.r,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor,
                ),
              ),
            )
                : Row(
              key: const ValueKey('content'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20.r,
                  ),
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
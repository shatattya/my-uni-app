import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

class HomeFeatureTile extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Future<String>? labelBuilder;
  final VoidCallback? onTap;

  const HomeFeatureTile({
    super.key,
    required this.icon,
    this.label,
    this.labelBuilder,
    this.onTap,
  }) : assert(
  (label != null) != (labelBuilder != null),
  'Provide exactly one of label or labelBuilder.',
  );

  bool get _isEnabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      button: _isEnabled,
      enabled: _isEnabled,
      label: label ?? 'Loading',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: _isEnabled
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(
              AppRadii.medium.r,
            ),
            border: Border.all(
              color: _isEnabled
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.03),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              AppRadii.medium.r,
            ),
            splashColor: primary.withValues(alpha: 0.10),
            highlightColor: primary.withValues(alpha: 0.05),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.r,
                    height: 50.r,
                    decoration: BoxDecoration(
                      color: _isEnabled
                          ? primary.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(
                        14.r,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: _isEnabled
                          ? primary
                          : AppColors.textTertiary,
                      size: 25.r,
                    ),
                  ),
                  SizedBox(width: 11.w),
                  Expanded(
                    child: labelBuilder != null
                        ? FutureBuilder<String>(
                      future: labelBuilder,
                      initialData: 'Events',
                      builder: (context, snapshot) {
                        return _buildLabel(
                          context,
                          snapshot.data ?? 'Events',
                        );
                      },
                    )
                        : _buildLabel(
                      context,
                      label!,
                    ),
                  ),
                  if (_isEnabled) ...[
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                      size: 20.r,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(
      BuildContext context,
      String text,
      ) {
    return Text(
      text.replaceAll('\n', ' '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: _isEnabled
            ? AppColors.textPrimary
            : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
    );
  }
}
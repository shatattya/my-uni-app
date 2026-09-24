import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/app_theme.dart';

class LibrarySearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasText = controller.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.textTertiary,
          size: 21.r,
        ),
        suffixIcon: hasText
            ? IconButton(
          onPressed: onClear,
          tooltip: 'Clear search',
          icon: Icon(
            Icons.close_rounded,
            color: AppColors.textTertiary,
            size: 19.r,
          ),
        )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 14.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium.r),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium.r),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium.r),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.60),
          ),
        ),
      ),
    );
  }
}

class SemesterSelector extends StatelessWidget {
  final int selectedSemester;
  final ValueChanged<int> onSelected;

  const SemesterSelector({
    super.key,
    required this.selectedSemester,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 42.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final semester = index + 1;
          final selected = semester == selectedSemester;

          return Semantics(
            button: true,
            selected: selected,
            label:
            'Semester $semester${selected ? ', selected' : ''}',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999.r),
              child: Ink(
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: InkWell(
                  onTap: () => onSelected(semester),
                  borderRadius: BorderRadius.circular(999.r),
                  splashColor:
                  colorScheme.primary.withValues(alpha: 0.10),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                    ),
                    child: Center(
                      child: Text(
                        'Sem $semester',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LibrarySectionLabel extends StatelessWidget {
  final String title;
  final String? trailing;

  const LibrarySectionLabel({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class LibraryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? query;

  const LibraryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76.r,
                height: 76.r,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: 0.09,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 38.r,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (query != null && query!.trim().isNotEmpty) ...[
                SizedBox(height: 7.h),
                Text(
                  'Try a different search term.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryErrorState extends StatelessWidget {
  final String message;

  const LibraryErrorState({
    super.key,
    this.message = 'Could not load this library.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 42.r,
                color: colorScheme.error,
              ),
              SizedBox(height: 12.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
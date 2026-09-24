import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable accessible touch target.
///
/// Provides:
/// - Material ink/ripple feedback
/// - minimum touch target sizing
/// - semantic button information
/// - selected-state semantics
/// - protection against accidental rapid repeated taps
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;

  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  final double minWidth;
  final double minHeight;

  final bool selected;

  /// Prevents accidental rapid repeated activation.
  final Duration tapGuardDuration;

  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppRadii.medium),
    ),
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.minWidth = 48,
    this.minHeight = 48,
    this.selected = false,
    this.tapGuardDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  DateTime? _lastTapAt;

  bool get _isEnabled => widget.onTap != null;

  void _handleTap() {
    final callback = widget.onTap;

    if (callback == null) {
      return;
    }

    final now = DateTime.now();
    final previousTap = _lastTapAt;

    if (previousTap != null &&
        now.difference(previousTap) < widget.tapGuardDuration) {
      return;
    }

    _lastTapAt = now;
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: _isEnabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minWidth,
            minHeight: widget.minHeight,
          ),
          child: Material(
            type: MaterialType.transparency,
            color: widget.backgroundColor ?? Colors.transparent,
            borderRadius: widget.borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isEnabled ? _handleTap : null,
              borderRadius: widget.borderRadius,
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
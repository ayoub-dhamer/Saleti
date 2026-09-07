import 'package:flutter/material.dart';

/// Accessible replacement for the bare `GestureDetector(child: Icon(...))`
/// pattern used across the app for icon-only controls (delete, refresh,
/// dismiss, font size, etc). Wraps TapScale's animation with proper
/// Semantics so screen readers announce a meaningful label and role
/// instead of nothing, and shows a Tooltip for sighted users on
/// long-press/hover as a bonus.
class IconAction extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String label;
  final bool selected;

  const IconAction({
    super.key,
    required this.child,
    required this.onTap,
    required this.label,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: Tooltip(
        message: label,
        child: _TapScaleInner(
          onTap: onTap,
          onLongPress: onLongPress,
          child: child,
        ),
      ),
    );
  }
}

class _TapScaleInner extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TapScaleInner({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_TapScaleInner> createState() => _TapScaleInnerState();
}

class _TapScaleInnerState extends State<_TapScaleInner> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.9),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme.dart';

/// A tappable rounded surface (Material + InkWell) that draws a clear ring
/// while it has keyboard focus. Material's default focus overlay on cards is
/// a faint tint that is easy to miss.
class FocusCard extends StatefulWidget {
  const FocusCard({super.key, required this.color, required this.onTap, required this.child, this.radius = 16});
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final double radius;

  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: _focused ? Border.all(color: deep, width: 3) : null,
        borderRadius: radius,
      ),
      child: Material(
        color: widget.color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          // Keyboard only: no ring after a tap.
          onFocusChange: (hasFocus) => setState(
            () => _focused = hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

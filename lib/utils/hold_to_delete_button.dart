import 'package:flutter/material.dart';

class HoldToDeleteButton extends StatefulWidget {
  final VoidCallback onConfirmed;

  const HoldToDeleteButton({super.key, required this.onConfirmed});

  @override
  State<HoldToDeleteButton> createState() => _HoldToDeleteButtonState();
}

class _HoldToDeleteButtonState extends State<HoldToDeleteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onConfirmed();
              _reset();
            }
          });
  }

  void _reset() {
    _controller.reset();
    setState(() => _isHolding = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    setState(() => _isHolding = true);
    _controller.forward();
  }

  void _cancelHold() {
    _controller.reset();
    setState(() => _isHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      child: SizedBox(
        width: 100,
        height: 50,
        child: Center(
          child: _isHolding
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) => CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 3,
                    color: Colors.redAccent,
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                  ),
                )
              : const Text(
                  "Delete",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

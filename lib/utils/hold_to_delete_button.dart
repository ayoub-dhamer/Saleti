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
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // time to confirm
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onConfirmed();
      }
    });
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _isLongPressing = true);
    _controller.forward(from: 0);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_controller.isAnimating) _controller.reset();
    setState(() => _isLongPressing = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isLongPressing)
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: _controller.value,
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _isLongPressing ? '' : 'Delete',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

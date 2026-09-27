import 'package:flutter/material.dart';

class EyelashIcon extends StatelessWidget {
  final bool isObscured;
  final VoidCallback onTap;
  final Color? color;

  const EyelashIcon({
    super.key,
    required this.isObscured,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white : const Color(0xFF1E1E1E));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: isObscured
            ? CustomPaint(
                size: const Size(26, 18),
                painter: _ClosedEyePainter(color: effectiveColor),
              )
            : Icon(
                Icons.visibility_outlined,
                color: effectiveColor,
                size: 22,
              ),
      ),
    );
  }
}

class _ClosedEyePainter extends CustomPainter {
  final Color color;

  _ClosedEyePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw bottom curved eyelid
    final path = Path();
    path.moveTo(2, size.height * 0.35);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 0.75,
      size.width - 2,
      size.height * 0.35,
    );
    canvas.drawPath(path, paint);

    // Draw eyelashes radiating downward
    final lashPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 4 lashes
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.55),
      Offset(size.width * 0.16, size.height * 0.88),
      lashPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.40, size.height * 0.65),
      Offset(size.width * 0.38, size.height * 0.98),
      lashPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.60, size.height * 0.65),
      Offset(size.width * 0.62, size.height * 0.98),
      lashPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.55),
      Offset(size.width * 0.84, size.height * 0.88),
      lashPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClosedEyePainter oldDelegate) =>
      color != oldDelegate.color;
}

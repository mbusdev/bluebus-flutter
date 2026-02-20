import 'package:flutter/material.dart';

class InnerShadow extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final double blurRadius;
  final Color color;
  final Offset offset;
  final BorderRadius borderRadius;

  const InnerShadow({
    super.key,
    required this.child,
    this.isActive = true,
    this.blurRadius = 8.0,
    this.color = Colors.black26,
    this.offset = const Offset(4, 4),
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    return CustomPaint(
      foregroundPainter: _InnerShadowPainter(
        blurRadius: blurRadius,
        color: color,
        offset: offset,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _InnerShadowPainter extends CustomPainter {
  final double blurRadius;
  final Color color;
  final Offset offset;
  final BorderRadius borderRadius;

  _InnerShadowPainter({
    required this.blurRadius,
    required this.color,
    required this.offset,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    
    // Flutter converts blurRadius to sigma for hardware acceleration
    final sigma = blurRadius * 0.57735 + 0.5;

    canvas.clipRRect(rrect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = blurRadius * 2 // Thick enough to bleed inward
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    canvas.drawRRect(rrect.shift(offset), paint);
  }

  @override
  bool shouldRepaint(covariant _InnerShadowPainter oldDelegate) {
    return oldDelegate.blurRadius != blurRadius ||
        oldDelegate.color != color ||
        oldDelegate.offset != offset ||
        oldDelegate.borderRadius != borderRadius;
  }
}
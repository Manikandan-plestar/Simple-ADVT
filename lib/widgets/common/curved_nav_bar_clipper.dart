import 'package:flutter/material.dart';

class CurvedNavBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    final center = width / 2;
    final curveWidth = 70.0;
    final curveHeight = 32.0;

    path.moveTo(0, 12);
    path.quadraticBezierTo(0, 0, 12, 0);

    path.lineTo(center - curveWidth, 0);

    path.cubicTo(
      center - curveWidth / 2,
      0,
      center - curveWidth / 2,
      curveHeight,
      center,
      curveHeight,
    );

    path.cubicTo(
      center + curveWidth / 2,
      curveHeight,
      center + curveWidth / 2,
      0,
      center + curveWidth,
      0,
    );

    path.lineTo(width - 12, 0);
    path.quadraticBezierTo(width, 0, width, 12);
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

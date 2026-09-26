import 'package:flutter/material.dart';

class RouteMapWidget extends StatelessWidget {
  const RouteMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFA7F3D0)), // Emerald 200
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // Emerald 500
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Driving Route',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '12 mins • 3.4 km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route Map Simulation Box
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 160,
              width: double.infinity,
              color: const Color(0xFFF1F5F9), // Slate 100
              child: Stack(
                children: [
                  // Map Grid Lines & Route Curve Painter
                  CustomPaint(
                    size: const Size(double.infinity, 160),
                    painter: _MapRoutePainter(),
                  ),

                  // Route via text badge
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        'via Mount Rd & Usman Rd',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'Fastest route available now with usual light traffic towards destination showroom.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 6;

    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), gridPaint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), gridPaint);

    // Route Path
    final routePath = Path();
    final start = Offset(size.width * 0.15, size.height * 0.75);
    final end = Offset(size.width * 0.85, size.height * 0.25);

    routePath.moveTo(start.dx, start.dy);
    routePath.cubicTo(
      size.width * 0.35,
      size.height * 0.75,
      size.width * 0.35,
      size.height * 0.35,
      size.width * 0.65,
      size.height * 0.35,
    );
    routePath.lineTo(end.dx, end.dy);

    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(routePath, routePaint);

    // Start Pin (Blue)
    final startOuter = Paint()..color = const Color(0x403B82F6);
    final startInner = Paint()..color = const Color(0xFF2563EB);
    canvas.drawCircle(start, 12, startOuter);
    canvas.drawCircle(start, 6, startInner);

    // End Pin (Red)
    final endOuter = Paint()..color = const Color(0x40EF4444);
    final endInner = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(end, 12, endOuter);
    canvas.drawCircle(end, 6, endInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

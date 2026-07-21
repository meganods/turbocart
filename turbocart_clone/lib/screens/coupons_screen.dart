import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Coupons & Offers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: TurbocartColors.textDark,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('coupons')
            .where('active', isEqualTo: true)
            .where('expiryDate', isGreaterThan: Timestamp.now())
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading coupons'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: TurbocartColors.primary));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No coupons available right now', style: TextStyle(color: TurbocartColors.textGrey)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Available Coupons', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TurbocartColors.textDark)),
              const SizedBox(height: 16),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CouponCard(data: data),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CouponCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final code = data['code']?.toString() ?? 'COUPON';
    final desc = data['description']?.toString() ?? 'Get discount on this order';
    final minOrder = (data['minOrderAmount'] as num?)?.toDouble() ?? 0.0;
    final type = data['type']?.toString() ?? 'flat'; // freeDelivery, percent, flat
    final expiry = data['expiryDate'] as Timestamp?;

    IconData typeIcon;
    if (type == 'freeDelivery') {
      typeIcon = Icons.local_shipping_outlined;
    } else if (type == 'percent') {
      typeIcon = Icons.percent;
    } else {
      typeIcon = Icons.currency_rupee;
    }

    String expiryText = '';
    if (expiry != null) {
      expiryText = 'Expires on ${DateFormat('dd MMM yyyy').format(expiry.toDate())}';
    }

    return CustomPaint(
      painter: _CouponTicketPainter(),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Green Strip
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(typeIcon, size: 16, color: const Color(0xFF0C831F)),
                            const SizedBox(width: 6),
                            Text(
                              code,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0C831F)),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: code));
                            SnackBarUtils.showTopSnackBar(context, 'Coupon code copied', backgroundColor: TurbocartColors.primary);
                          },
                          child: const Text(
                            'COPY',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TurbocartColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Middle Row
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    // Bottom Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Min order ₹${minOrder.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, color: TurbocartColors.textGrey),
                        ),
                        Text(
                          expiryText,
                          style: const TextStyle(fontSize: 11, color: TurbocartColors.textGrey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponTicketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    // Draw main background
    canvas.drawRRect(rRect, paint);
    
    // Draw outer border (solid or dashed, the prompt asked for dashed border around whole card, but standard tickets usually just have dashed divider. I will do solid outer, dashed inner for simplicity, or dashed outer if specifically needed. Prompt: "Border is dashed using CustomPainter drawing dashed border around the whole card.")
    _drawDashedBorder(canvas, rRect, borderPaint);

    // Draw dashed divider
    final dividerY = size.height - 35;
    
    // Cutouts
    final path = Path();
    path.addArc(Rect.fromCenter(center: Offset(0, dividerY), width: 16, height: 16), -3.14 / 2, 3.14);
    path.addArc(Rect.fromCenter(center: Offset(size.width, dividerY), width: 16, height: 16), 3.14 / 2, 3.14);

    // Clear cutouts
    canvas.drawPath(path, Paint()..color = const Color(0xFFF5F5F5)..style = PaintingStyle.fill..blendMode = BlendMode.srcOver);
    
    // Draw dashed line
    double startX = 12;
    while (startX < size.width - 12) {
      canvas.drawLine(Offset(startX, dividerY), Offset(startX + 4, dividerY), dashPaint);
      startX += 8;
    }
  }

  void _drawDashedBorder(Canvas canvas, RRect rrect, Paint paint) {
    // A simple approximation for a dashed border on RRect
    Path path = Path()..addRRect(rrect);
    PathMetrics pathMetrics = path.computeMetrics();
    Path dashedPath = Path();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        dashedPath.addPath(
          pathMetric.extractPath(distance, distance + 5.0),
          Offset.zero,
        );
        distance += 10.0;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

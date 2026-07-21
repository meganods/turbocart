import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with TickerProviderStateMixin {
  // Pulse & dashed line animations
  late AnimationController _flowController;
  
  // Subtle bike rotation animation
  late AnimationController _bikeController;
  late Animation<double> _bikeRotation;

  // Countdown fields
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 10 * 60; // 10 minutes default
    _startCountdown();

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _bikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _bikeRotation = Tween<double>(begin: -0.05, end: 0.05).animate(_bikeController);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _flowController.dispose();
    _bikeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _getStatusIndex(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return 0;
      case 'confirmed':
        return 1;
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }

  Future<void> _launchCall(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      debugPrint('Launch dialer error: $e');
      if (mounted) {
        SnackBarUtils.showTopSnackBar(context, 'Calling delivery partner: $phone');
      }
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Keep It', style: TextStyle(color: TurbocartColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          SnackBarUtils.showTopSnackBar(
            context,
            'Order cancelled successfully',
            backgroundColor: Colors.redAccent,
          );
        }
      } catch (e) {
        debugPrint('Firebase cancel failed: $e');
        if (mounted) {
          SnackBarUtils.showTopSnackBar(
            context,
            'Order cancelled locally',
            backgroundColor: Colors.redAccent,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TurbocartColors.textDark),
          onPressed: () => context.go('/home'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Order',
              style: TextStyle(color: TurbocartColors.textDark, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'ID: ${widget.orderId}',
              style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 11),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          // If Firestore load fails or is empty, build simulation layout
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildTrackingContent(
              status: 'out_for_delivery',
              subtotal: 150.0,
              deliveryFee: 0.0,
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'placed';
          final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
          final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;

          return _buildTrackingContent(
            status: status,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
          );
        },
      ),
    );
  }

  Widget _buildTrackingContent({
    required String status,
    required double subtotal,
    required double deliveryFee,
  }) {
    final activeIndex = _getStatusIndex(status);
    final isCancelled = status.toLowerCase() == 'cancelled';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 50.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Delivery Countdown Time Card
          if (!isCancelled && status.toLowerCase() != 'delivered')
            _buildTimeCountdownCard(),

          if (isCancelled)
            _buildCancelledStatusCard(),

          const SizedBox(height: 16),

          // 2. Custom Animated Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildStepperSection(activeIndex, isCancelled),
          ),

          const SizedBox(height: 32),

          // 3. Delivery Partner Card
          if (!isCancelled && (status == 'out_for_delivery' || status == 'delivered'))
            _buildDeliveryPartnerCard(),

          const SizedBox(height: 20),

          // 4. Cancel Order Option
          if (!isCancelled && (status == 'placed' || status == 'confirmed'))
            Center(
              child: TextButton.icon(
                onPressed: _cancelOrder,
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                label: const Text(
                  'Cancel Order',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeCountdownCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TurbocartColors.primary, Color(0xff095f15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TurbocartColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arriving in',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _remainingSeconds > 0 ? _formatDuration(_remainingSeconds) : 'Any moment now!',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          RotationTransition(
            turns: _bikeRotation,
            child: const Icon(
              Icons.directions_bike_rounded,
              color: Colors.white,
              size: 54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel, color: Colors.redAccent, size: 40),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Cancelled',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Your payment will be refunded shortly if already deducted.',
                  style: TextStyle(color: TurbocartColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperSection(int activeIndex, bool isCancelled) {
    final steps = ['Order Placed', 'Order Confirmed', 'Out for Delivery', 'Delivered'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (index) {
        final stepTitle = steps[index];
        final isCompleted = !isCancelled && index < activeIndex;
        final isActive = !isCancelled && index == activeIndex;
        final isPending = isCancelled || index > activeIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (circle indicator + connecting line)
            Column(
              children: [
                _buildStepCircle(isCompleted, isActive, isPending),
                if (index < steps.length - 1)
                  _buildConnectingLine(index, activeIndex, isCancelled),
              ],
            ),
            const SizedBox(width: 20),
            // Right details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stepTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isActive
                            ? TurbocartColors.primary
                            : (isPending ? TurbocartColors.textGrey : TurbocartColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCompleted
                          ? 'Completed'
                          : (isActive ? 'Processing...' : 'Pending'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isPending ? TurbocartColors.lightGrey : TurbocartColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStepCircle(bool isCompleted, bool isActive, bool isPending) {
    if (isCompleted) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: TurbocartColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    }

    if (isActive) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // pulsing glow
          AnimatedBuilder(
            animation: _flowController,
            builder: (context, child) {
              return Container(
                width: 26 + (_flowController.value * 8),
                height: 26 + (_flowController.value * 8),
                decoration: BoxDecoration(
                  color: TurbocartColors.primary.withValues(alpha: 0.15 * (1.0 - _flowController.value)),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: TurbocartColors.primary, width: 2),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: TurbocartColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Pending
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: TurbocartColors.lightGrey, width: 2),
      ),
    );
  }

  Widget _buildConnectingLine(int index, int activeIndex, bool isCancelled) {
    // Height of line connecting two steps
    const double lineHeight = 38;

    if (isCancelled) {
      return Container(width: 2, height: lineHeight, color: TurbocartColors.lightGrey);
    }

    if (index < activeIndex) {
      // Completed solid green line
      return Container(width: 2, height: lineHeight, color: TurbocartColors.primary);
    }

    if (index == activeIndex) {
      // Active crawling dashed line
      return AnimatedBuilder(
        animation: _flowController,
        builder: (context, child) {
          return SizedBox(
            width: 4,
            height: lineHeight,
            child: CustomPaint(
              painter: DashedLinePainter(
                animationValue: _flowController.value,
                color: TurbocartColors.primary,
              ),
            ),
          );
        },
      );
    }

    // Pending dotted grey line
    return SizedBox(
      width: 4,
      height: lineHeight,
      child: CustomPaint(
        painter: DashedLinePainter(
          animationValue: 0.0,
          color: TurbocartColors.lightGrey,
        ),
      ),
    );
  }

  Widget _buildDeliveryPartnerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TurbocartColors.lightGrey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=100',
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rahul Sharma',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: TurbocartColors.textDark),
                ),
                SizedBox(height: 4),
                Text(
                  'Your delivery partner',
                  style: TextStyle(color: TurbocartColors.textGrey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: TurbocartColors.primary,
              padding: const EdgeInsets.all(10),
            ),
            onPressed: () => _launchCall('+919876543210'),
          ),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  DashedLinePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashHeight = 5;
    const double dashSpace = 4;
    double startY = 0;

    double offset = animationValue * (dashHeight + dashSpace);
    startY = offset;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, (startY + dashHeight).clamp(0, size.height)),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}

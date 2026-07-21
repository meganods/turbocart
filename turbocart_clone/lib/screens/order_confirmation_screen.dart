import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;
  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  int _cancelTimerSeconds = 60;
  Timer? _cancelTimer;

  @override
  void initState() {
    super.initState();
    _startCancelTimer();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _startCancelTimer() {
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_cancelTimerSeconds > 0) {
            _cancelTimerSeconds--;
          } else {
            _cancelTimer?.cancel();
          }
        });
      }
    });
  }

  Future<void> _cancelOrder() async {
    _cancelTimer?.cancel();
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': 'cancelled'});

      if (mounted) {
        SnackBarUtils.showTopSnackBar(context, 'Order Cancelled Successfully');
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Failed to cancel order: $e');
      if (mounted) {
        SnackBarUtils.showTopSnackBar(context, 'Failed to cancel order: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Prevent back navigation to payment or cart
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Lottie checkmark success animation
                Lottie.network(
                  'https://assets10.lottiefiles.com/packages/lf20_aw714qpa.json', // Premium success green checkmark
                  height: 180,
                  repeat: false,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: TurbocartColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 64),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 2. Heading
                const Text(
                  'Order Placed Successfully!',
                  style: TextStyle(
                    color: TurbocartColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Order ID
                Text(
                  'Order ID: ${widget.orderId}',
                  style: const TextStyle(
                    color: TurbocartColors.textGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Estimated Delivery
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: TurbocartColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TurbocartColors.lightGrey.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_filled, color: TurbocartColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Estimated delivery: 10 minutes',
                        style: TextStyle(
                          color: TurbocartColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Cancellation Countdown Panel ──
                if (_cancelTimerSeconds > 0) ...[
                  Text(
                    'Cancel available for $_cancelTimerSeconds more seconds',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _cancelOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],

                const SizedBox(height: 32),

                // 5. Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            context.go('/order-tracking', extra: widget.orderId);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: TurbocartColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Track Order',
                            style: TextStyle(
                              color: TurbocartColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => context.go('/home'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TurbocartColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Continue Shopping',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

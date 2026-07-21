import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';


class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final statusIndex = _getStatusIndex(order.status);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt.toDate());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Order Header Info
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order ID: ${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      _buildStatusChip(order.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Placed on $formattedDate', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Timeline Stepper
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: _buildTrackingTimeline(statusIndex),
            ),
            const SizedBox(height: 10),

            // Itemized List
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items Ordered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(height: 20),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: item.product.images.isNotEmpty
                                ? Image.network(item.product.images.first, fit: BoxFit.cover)
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('${item.quantity} x ${item.variant}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('₹${(item.price * item.quantity).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bill Summary Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bill Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildBillRow('Item Subtotal', '₹${order.subtotal.toInt()}'),
                  _buildBillRow('Delivery Fee', order.deliveryFee == 0 ? 'FREE' : '₹${order.deliveryFee.toInt()}', isGreen: order.deliveryFee == 0),
                  if (order.couponDiscount > 0)
                    _buildBillRow('Coupon Discount (${order.couponCode})', '-₹${order.couponDiscount.toInt()}', isGreen: true),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount Paid', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      Text('₹${order.total.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Payment and Delivery Address Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Method: ${order.paymentMethod.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Divider(height: 24),
                  const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(
                    '${order.address['label'] ?? 'HOME'}: ${order.address['text'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isGreen ? const Color(0xFF0C831F) : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'placed':
        color = Colors.blue;
        break;
      case 'confirmed':
        color = Colors.orange;
        break;
      case 'out_for_delivery':
        color = Colors.purple;
        break;
      case 'delivered':
        color = const Color(0xFF0C831F);
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
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
      default:
        return 0;
    }
  }

  Widget _buildTrackingTimeline(int currentStep) {
    final steps = ['Order Placed', 'Confirmed', 'Out for Delivery', 'Delivered'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == 0 ? Colors.transparent : (isCompleted ? const Color(0xFF0C831F) : Colors.grey[300]),
                    ),
                  ),
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted ? const Color(0xFF0C831F) : Colors.grey,
                    size: 20,
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == steps.length - 1 ? Colors.transparent : (index < currentStep ? const Color(0xFF0C831F) : Colors.grey[300]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: index == currentStep ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? const Color(0xFF0C831F) : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final isActive = order.status.toLowerCase() != 'delivered' && order.status.toLowerCase() != 'cancelled';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: isActive
            ? ElevatedButton(
                onPressed: () => context.go('/order-tracking/${order.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Track Order Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              )
            : OutlinedButton(
                onPressed: () {
                  final cart = Provider.of<CartProvider>(context, listen: false);
                  for (var item in order.items) {
                    final dummyProd = Product(
                      id: item.product.id,
                      name: item.product.name,
                      brand: '',
                      category: '',
                      subcategory: '',
                      description: '',
                      images: item.product.images,
                      tags: [],
                      price: item.price,
                      mrp: item.price,
                      rating: 4.8,
                      discount: 0,
                      stock: 10,
                      reviewCount: 0,
                      isDeal: false,
                      isBestSeller: false,
                      weight: item.variant,
                      unit: '',
                    );
                    cart.addItem(dummyProd, item.variant, item.price);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Items added to cart!'), backgroundColor: Color(0xFF0C831F)),
                  );
                  context.go('/home');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0C831F), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Reorder All Items', style: TextStyle(color: Color(0xFF0C831F), fontWeight: FontWeight.bold, fontSize: 14)),
              ),
      ),
    );
  }
}

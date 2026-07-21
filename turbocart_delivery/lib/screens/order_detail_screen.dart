import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/delivery_orders_provider.dart';
import '../models/order_model.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0C831F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: Text(
          'Order Details',
          style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primaryGreen)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final order = OrderModel.fromMap(snapshot.data!.id, snapshot.data!.data() as Map<String, dynamic>);
          final address = order.address;
          final name = address['name'] ?? 'Customer';
          final phone = address['phone'] ?? '';
          final flat = address['flat'] ?? '';
          final area = address['area'] ?? '';
          final landmark = address['landmark'] ?? '';
          final fullAddress = '$flat, $area${landmark.isNotEmpty ? ' ($landmark)' : ''}';
          final lat = (address['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (address['longitude'] as num?)?.toDouble() ?? 0.0;

          final isConfirmed = order.status == 'confirmed';
          final isOutForDelivery = order.status == 'out_for_delivery';
          final isDelivered = order.status == 'delivered';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CURRENT STATUS', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.status.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDelivered
                                          ? primaryGreen
                                          : (isConfirmed ? Colors.amber.shade700 : Colors.blue.shade700),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                isDelivered
                                    ? Icons.check_circle
                                    : (isConfirmed ? Icons.hourglass_top : Icons.directions_bike),
                                color: isDelivered
                                    ? primaryGreen
                                    : (isConfirmed ? Colors.amber : Colors.blue),
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CUSTOMER & DELIVERY LOCATION', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                                        const SizedBox(height: 2),
                                        Text(phone, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  if (phone.isNotEmpty)
                                    IconButton(
                                      onPressed: () => _makeCall(phone),
                                      icon: const Icon(Icons.call, color: primaryGreen),
                                      style: IconButton.styleFrom(
                                        backgroundColor: primaryGreen.withOpacity(0.08),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fullAddress, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                                        if (lat != 0.0 && lng != 0.0) ...[
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            onPressed: () => _openMaps(lat, lng),
                                            icon: const Icon(Icons.navigation_outlined, size: 16),
                                            label: const Text('Navigate'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryGreen.withOpacity(0.08),
                                              foregroundColor: primaryGreen,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Package checklist
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PACKAGE ITEMS (${order.items.length})',
                                style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 24),
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
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${item.quantity}x',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151))),
                                            if (item.variant.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(item.variant, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Update Button
              if (!isDelivered)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(context, order.id, isConfirmed ? 'out_for_delivery' : 'delivered'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConfirmed ? primaryGreen : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      isConfirmed ? 'MARK AS PICKED UP (START DELIVERY)' : 'MARK AS DELIVERED',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _updateStatus(BuildContext context, String id, String status) async {
    final provider = Provider.of<DeliveryOrdersProvider>(context, listen: false);
    final success = await provider.updateOrderStatus(id, status);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Order state updated' : 'Update failed'),
          backgroundColor: success ? const Color(0xFF0C831F) : Colors.redAccent,
        ),
      );
    }
  }
}

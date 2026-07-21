import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/delivery_auth_provider.dart';
import '../providers/delivery_orders_provider.dart';
import '../models/order_model.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  double _commissionRate = 50.0;
  bool _loadingRate = true;

  @override
  void initState() {
    super.initState();
    _fetchRate();
  }

  void _fetchRate() async {
    final provider = Provider.of<DeliveryOrdersProvider>(context, listen: false);
    final rate = await provider.fetchCommissionRate();
    if (mounted) {
      setState(() {
        _commissionRate = rate;
        _loadingRate = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<DeliveryAuthProvider>(context);
    final partner = authProvider.partner;
    const primaryGreen = Color(0xFF0C831F);

    if (partner == null) {
      return const Scaffold(
        body: Center(child: Text('Loading partner profile...')),
      );
    }

    final ordersProvider = Provider.of<DeliveryOrdersProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: const Text(
          'My Earnings',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loadingRate
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primaryGreen)))
          : StreamBuilder<List<OrderModel>>(
              stream: ordersProvider.streamCompletedOrders(partner.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primaryGreen)));
                }

                final completedOrders = snapshot.data ?? [];

                // Math checks:
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final startOfWeek = todayStart.subtract(Duration(days: now.weekday - 1));

                final todayDeliveries = completedOrders.where((o) {
                  if (o.deliveredAt == null) return false;
                  return o.deliveredAt!.toDate().isAfter(todayStart);
                }).toList();

                final weekDeliveries = completedOrders.where((o) {
                  if (o.deliveredAt == null) return false;
                  return o.deliveredAt!.toDate().isAfter(startOfWeek);
                }).toList();

                final todayEarnings = todayDeliveries.length * _commissionRate;
                final weekEarnings = weekDeliveries.length * _commissionRate;

                return Column(
                  children: [
                    // Top stats banner
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0C831F), Color(0xFF16A34A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("TODAY'S EARNINGS", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('₹${todayEarnings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('${todayDeliveries.length} deliveries', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("THIS WEEK'S TOTAL", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('₹${weekEarnings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('${weekDeliveries.length} deliveries', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Rate Per Delivery:', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
                                Text('₹${_commissionRate.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Text(
                            'DELIVERY HISTORY (${completedOrders.length})',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),

                    // List of items
                    Expanded(
                      child: completedOrders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, color: Colors.grey.shade400, size: 48),
                                  const SizedBox(height: 8),
                                  const Text('No delivery records found', style: TextStyle(color: Color(0xFF6B7280))),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: completedOrders.length,
                              itemBuilder: (context, index) {
                                final order = completedOrders[index];
                                final timeStr = order.deliveredAt != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(order.deliveredAt!.toDate())
                                    : DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt.toDate());

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  color: Colors.white,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFDCFCE7),
                                      child: Icon(Icons.check, color: primaryGreen),
                                    ),
                                    title: Text(
                                      'Order ID: #${order.id.substring(0, 8).toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ),
                                    trailing: Text(
                                      '+₹${_commissionRate.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 15),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

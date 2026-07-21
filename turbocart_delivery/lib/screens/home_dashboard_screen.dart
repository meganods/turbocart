import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/delivery_auth_provider.dart';
import '../providers/delivery_orders_provider.dart';
import '../models/order_model.dart';
import 'order_detail_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            const Icon(Icons.delivery_dining, color: primaryGreen, size: 28),
            const SizedBox(width: 8),
            const Text(
              'TurboCart Delivery',
              style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF4B5563)),
            tooltip: 'Earnings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EarningsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF4B5563)),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: primaryGreen,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Active Orders'),
            Tab(text: 'Completed History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveOrdersTab(partner.uid),
          _buildCompletedOrdersTab(partner.uid),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersTab(String partnerId) {
    final ordersProvider = Provider.of<DeliveryOrdersProvider>(context);

    return StreamBuilder<List<OrderModel>>(
      stream: ordersProvider.streamActiveOrders(partnerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF0C831F))));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading orders: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No active assigned orders',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You will be notified when admin assigns an order.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order, isActive: true);
          },
        );
      },
    );
  }

  Widget _buildCompletedOrdersTab(String partnerId) {
    final ordersProvider = Provider.of<DeliveryOrdersProvider>(context);

    return StreamBuilder<List<OrderModel>>(
      stream: ordersProvider.streamCompletedOrders(partnerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF0C831F))));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading history: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No completed deliveries yet',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order, isActive: false);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, {required bool isActive}) {
    const primaryGreen = Color(0xFF0C831F);
    final isConfirmed = order.status == 'confirmed';
    final addressMap = order.address;
    final flat = addressMap['flat'] ?? '';
    final area = addressMap['area'] ?? '';
    final landmark = addressMap['landmark'] ?? '';
    final fullAddress = '$flat, $area${landmark.isNotEmpty ? ' ($landmark)' : ''}';
    final customerName = addressMap['name'] ?? 'Customer';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(orderId: order.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header ID + Status Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order ID: #${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isConfirmed ? Colors.amber.shade50 : Colors.blue.shade50)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? (isConfirmed ? Colors.amber.shade700 : Colors.blue.shade700)
                            : primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_pin, color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fullAddress,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${order.items.length} items',
                    style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '₹${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 15),
                  ),
                ],
              ),

              // Completed delivery date representation
              if (!isActive && order.deliveredAt != null) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivered On:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(order.deliveredAt!.toDate()),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontSize: 12),
                    ),
                  ],
                ),
              ],

              // Action Buttons for Active Tab
              if (isActive) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    if (isConfirmed)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateOrderState(order.id, 'out_for_delivery'),
                          icon: const Icon(Icons.directions_bike),
                          label: const Text('Pick Up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateOrderState(order.id, 'delivered'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Delivered'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _updateOrderState(String orderId, String status) async {
    final provider = Provider.of<DeliveryOrdersProvider>(context, listen: false);
    final success = await provider.updateOrderStatus(orderId, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Order state updated successfully' : 'Failed to update order status'),
          backgroundColor: success ? const Color(0xFF0C831F) : Colors.redAccent,
        ),
      );
    }
  }
}

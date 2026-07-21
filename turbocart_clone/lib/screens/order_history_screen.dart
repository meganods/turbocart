import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getUid() => FirebaseAuth.instance.currentUser?.uid ?? 'mock_uid_123';

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed': return Colors.orangeAccent;
      case 'confirmed': return Colors.blueAccent;
      case 'out_for_delivery': return Colors.deepPurpleAccent;
      case 'delivered': return TurbocartColors.primary;
      case 'cancelled': return Colors.redAccent;
      default: return TurbocartColors.textGrey;
    }
  }

  void _reorderItems(BuildContext context, List<dynamic> items, CartProvider cart) {
    for (var item in items) {
      cart.addItem(
        item['id'] ?? '',
        item['title'] ?? '',
        (item['price'] as num?)?.toDouble() ?? 0.0,
        item['imageUrl'] ?? '',
        item['unit'] ?? 'each',
      );
    }
    SnackBarUtils.showTopSnackBar(context, 'Items added back to cart!',
        backgroundColor: TurbocartColors.primary);
    context.go('/cart');
  }

  void _showOrderDetailsDialog(BuildContext context, Map<String, dynamic> data, String orderId) {
    final items = data['items'] as List<dynamic>? ?? [];
    final address = data['address'] as Map<String, dynamic>? ?? {};
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final payment = data['paymentMethod'] ?? 'COD';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order ID: $orderId',
                    style: const TextStyle(fontSize: 12, color: TurbocartColors.textGrey)),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['title']} (${item['unit']}) × ${item['quantity']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                const Text('Delivery Address:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${address['title'] ?? "Home"}: ${address['addressLine'] ?? ""}',
                    style: const TextStyle(fontSize: 12)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Method:', style: TextStyle(fontSize: 12)),
                    Text(payment.toString().toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TurbocartColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: TurbocartColors.textGrey)),
          ),
        ],
      ),
    );
  }



  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders, String tab) {
    if (tab == 'All') return orders;
    return orders.where((data) {
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (tab == 'Active') return status == 'placed' || status == 'confirmed' || status == 'out_for_delivery';
      if (tab == 'Completed') return status == 'delivered';
      if (tab == 'Cancelled') return status == 'cancelled';
      return true;
    }).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final uid = _getUid();

    return Scaffold(
      backgroundColor: TurbocartColors.surface,
      appBar: AppBar(
        title: const Text('Your Orders',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: TurbocartColors.textDark,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: TurbocartColors.primary,
          unselectedLabelColor: TurbocartColors.textGrey,
          indicatorColor: TurbocartColors.primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // ── Always resolve to a usable orders list ──
          List<Map<String, dynamic>> displayOrders;

          if (snapshot.hasError) {
            // Firebase permission denied or unavailable → show empty list
            displayOrders = [];
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: TurbocartColors.primary));
          } else {
            final docs = snapshot.data?.docs ?? [];
            displayOrders = docs
                .map((d) => {'_id': d.id, ...d.data() as Map<String, dynamic>})
                .toList();
          }

          return TabBarView(
            controller: _tabController,
            children: ['All', 'Active', 'Completed', 'Cancelled'].map((tabName) {
              final filtered = _filterOrders(displayOrders, tabName);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 64, color: TurbocartColors.lightGrey),
                      const SizedBox(height: 12),
                      Text('No $tabName orders',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: TurbocartColors.textDark)),
                      const SizedBox(height: 6),
                      Text(
                        tabName == 'All'
                            ? 'Your orders will appear here'
                            : 'Nothing here yet',
                        style: const TextStyle(
                            color: TurbocartColors.textGrey, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final data = filtered[index];
                  final orderId = data['_id'] ?? 'ORD${index + 1001}';
                  final status = data['status'] ?? 'placed';
                  final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                  final items = data['items'] as List<dynamic>? ?? [];

                  // Format date
                  String formattedDate = 'Recent Order';
                  final ts = data['createdAt'];
                  if (ts is Timestamp) {
                    formattedDate =
                        DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
                  } else if (ts is String) {
                    formattedDate = ts;
                  }

                  return _OrderCard(
                    orderId: orderId,
                    status: status,
                    total: total,
                    items: items,
                    formattedDate: formattedDate,
                    statusColor: _getStatusColor(status),
                    onViewDetails: () => _showOrderDetailsDialog(context, data, orderId),
                    onReorder: () => _reorderItems(context, items, cart),
                    onTrack: () => context.push('/order-tracking', extra: orderId),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Order Card Widget
// ──────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final String orderId;
  final String status;
  final double total;
  final List<dynamic> items;
  final String formattedDate;
  final Color statusColor;
  final VoidCallback onViewDetails;
  final VoidCallback onReorder;
  final VoidCallback onTrack;

  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.total,
    required this.items,
    required this.formattedDate,
    required this.statusColor,
    required this.onViewDetails,
    required this.onReorder,
    required this.onTrack,
  });

  String get _statusLabel => status.replaceAll('_', ' ').toUpperCase();

  bool get _isActive =>
      status == 'placed' || status == 'confirmed' || status == 'out_for_delivery';

  bool get _isDelivered => status == 'delivered';

  bool get _isCancelled => status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TurbocartColors.lightGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date + Status badge ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(formattedDate,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: TurbocartColors.textDark)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Product name chips ──
            if (items.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...items.take(3).map((item) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: TurbocartColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TurbocartColors.lightGrey),
                        ),
                        child: Text(
                          item['title'] ?? '',
                          style: const TextStyle(fontSize: 11, color: TurbocartColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                  if (items.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TurbocartColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TurbocartColors.lightGrey),
                      ),
                      child: Text(
                        '+${items.length - 3} more',
                        style: const TextStyle(
                            fontSize: 11,
                            color: TurbocartColors.textGrey,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ── Summary ──
            Text(
              '${items.length} item${items.length != 1 ? 's' : ''} · ₹${total.toStringAsFixed(2)} total',
              style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 12),
            ),

            const Divider(height: 20),

            // ── Action buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onViewDetails,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('View Details',
                      style: TextStyle(
                          color: TurbocartColors.primary, fontWeight: FontWeight.bold)),
                ),
                if (_isDelivered)
                  OutlinedButton.icon(
                    onPressed: onReorder,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reorder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TurbocartColors.primary,
                      side: const BorderSide(color: TurbocartColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                if (_isActive)
                  ElevatedButton.icon(
                    onPressed: onTrack,
                    icon: const Icon(Icons.location_on, size: 14),
                    label: const Text('Track', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TurbocartColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                if (_isCancelled)
                  const Text('Order Cancelled',
                      style: TextStyle(
                          color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

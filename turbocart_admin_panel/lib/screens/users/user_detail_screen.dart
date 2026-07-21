import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';

class UserDetailAdminScreen extends StatefulWidget {
  final String userId;
  const UserDetailAdminScreen({super.key, required this.userId});

  @override
  State<UserDetailAdminScreen> createState() => _UserDetailAdminScreenState();
}

class _UserDetailAdminScreenState extends State<UserDetailAdminScreen> with SingleTickerProviderStateMixin {
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
    final primaryGreen = const Color(0xFF0C831F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('User Profile Detail', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/users'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading user profile: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F))));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User profile not found.'));
          }

          final user = UserModel.fromMap(snapshot.data!.id, snapshot.data!.data() as Map<String, dynamic>);
          final joinedDateStr = DateFormat('dd MMM yyyy').format(user.createdAt.toDate());

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Summary Banner Card
              Card(
                margin: const EdgeInsets.all(24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipOval(
                          child: user.photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: user.photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const Icon(Icons.person, size: 40),
                                )
                              : const Icon(Icons.person, size: 40, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // User Info Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name.isNotEmpty ? user.name : 'No Name Set',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(user.phone, style: const TextStyle(color: Color(0xFF4B5563))),
                                const SizedBox(width: 24),
                                const Icon(Icons.email, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(user.email.isNotEmpty ? user.email : 'N/A', style: const TextStyle(color: Color(0xFF4B5563))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Joined on $joinedDateStr  •  UID: ${user.uid}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),

                      // Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: user.blocked ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          user.blocked ? 'BLOCKED' : 'ACTIVE',
                          style: TextStyle(
                            color: user.blocked ? Colors.red.shade700 : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Tab Bar Selector
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: primaryGreen,
                  unselectedLabelColor: const Color(0xFF4B5563),
                  indicatorColor: primaryGreen,
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt_long), text: 'Order History'),
                    Tab(icon: Icon(Icons.location_on), text: 'Saved Addresses'),
                  ],
                ),
              ),

              // 3. Tab Views
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderHistoryTab(user, primaryGreen),
                      _buildSavedAddressesTab(user),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderHistoryTab(UserModel user, Color primaryGreen) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading user orders: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F))));
        }

        // Filter orders matching customer phone/email or userId on the client side
        final allOrders = snapshot.data!.docs
            .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        final userOrders = allOrders.where((order) {
          final orderPhone = order.address['phone']?.toString() ?? '';
          final orderEmail = order.address['email']?.toString() ?? '';
          return orderPhone == user.phone || orderEmail == user.email || order.id.contains(user.uid);
        }).toList();

        if (userOrders.isEmpty) {
          return const Card(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No orders placed by this user yet.', style: TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 32,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                columns: const [
                  DataColumn(label: Text('Order ID')),
                  DataColumn(label: Text('Items')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Payment')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Date/Time')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: userOrders.map((order) {
                  final dateStr = DateFormat('dd MMM, h:mm a').format(order.createdAt.toDate());
                  final totalItems = order.items.fold<int>(0, (acc, item) => acc + item.quantity);

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '#${order.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0C831F)),
                        ),
                      ),
                      DataCell(Text('$totalItems items')),
                      DataCell(Text('₹${order.total.toStringAsFixed(2)}')),
                      DataCell(Text(order.paymentMethod.toUpperCase())),
                      DataCell(_buildStatusChip(order.status)),
                      DataCell(Text(dateStr)),
                      DataCell(
                        ElevatedButton(
                          onPressed: () {
                            context.go('/orders/${order.id}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen.withOpacity(0.08),
                            foregroundColor: primaryGreen,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'placed':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 'confirmed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'out for delivery':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade700;
        break;
      case 'delivered':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSavedAddressesTab(UserModel user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading addresses: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F))));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Card(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No saved addresses found for this user.', style: TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final label = data['label'] ?? 'Address';
            final flat = data['flat'] ?? '';
            final area = data['area'] ?? '';
            final city = data['city'] ?? '';
            final pincode = data['pincode'] ?? '';
            final fullAddress = '$flat, $area, $city - $pincode';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C831F).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: Color(0xFF0C831F), size: 20),
                ),
                title: Text(
                  label.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(fullAddress, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

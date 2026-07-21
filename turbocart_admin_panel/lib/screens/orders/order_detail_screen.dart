import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/order_model.dart';
import '../../utils/admin_logger.dart';

class OrderDetailAdminScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailAdminScreen({super.key, required this.orderId});

  @override
  State<OrderDetailAdminScreen> createState() => _OrderDetailAdminScreenState();
}

class _OrderDetailAdminScreenState extends State<OrderDetailAdminScreen> {
  final _notesController = TextEditingController();
  bool _isUpdatingNotes = false;
  String? _selectedPartnerId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _triggerPrint(OrderModel order) {
    try {
      final itemsHtml = order.items.map((item) => '''
        <tr>
          <td style="padding: 8px; border-bottom: 1px solid #ddd;">${item.product.name} (${item.variant})</td>
          <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: center;">${item.quantity}</td>
          <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹${item.price.toStringAsFixed(2)}</td>
          <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹${(item.price * item.quantity).toStringAsFixed(2)}</td>
        </tr>
      ''').join('');

      final subtotal = order.items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
      final gst = subtotal * 0.05;

      final htmlContent = '''
        <html>
        <head>
          <title>Invoice - ${order.id}</title>
          <style>
            body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #333; margin: 40px; }
            .header { display: flex; justify-content: space-between; border-bottom: 2px solid #0C831F; padding-bottom: 20px; }
            .logo { font-size: 24px; font-weight: bold; color: #0C831F; }
            .details { margin: 20px 0; display: flex; justify-content: space-between; }
            table { width: 100%; border-collapse: collapse; margin: 30px 0; }
            th { background-color: #f8f8f8; padding: 10px; text-align: left; border-bottom: 2px solid #ddd; }
            .totals { width: 40%; margin-left: auto; font-size: 14px; }
            .totals td { padding: 6px 0; }
            .footer { text-align: center; margin-top: 50px; font-size: 12px; color: #777; border-top: 1px solid #eee; padding-top: 20px; }
          </style>
        </head>
        <body>
          <div class="header">
            <div>
              <div class="logo">TurboCart</div>
              <div style="font-size: 12px; color: #666; margin-top: 5px;">Superfast Grocery Delivery</div>
            </div>
            <div style="text-align: right;">
              <h2 style="margin: 0; color: #333;">INVOICE</h2>
              <div style="font-size: 12px; color: #666; margin-top: 5px;">Order ID: ${order.id}</div>
            </div>
          </div>
          
          <div class="details">
            <div>
              <strong>Customer details:</strong><br>
              ${order.address['name'] ?? 'Customer'}<br>
              Phone: ${order.address['phone'] ?? ''}
            </div>
            <div style="text-align: right;">
              <strong>Delivery address:</strong><br>
              ${order.address['title'] ?? 'Address'}<br>
              ${order.address['addressLine'] ?? ''}
            </div>
          </div>

          <table>
            <thead>
              <tr>
                <th>Item Details</th>
                <th style="text-align: center;">Qty</th>
                <th style="text-align: right;">Price</th>
                <th style="text-align: right;">Total</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>

          <table class="totals">
            <tr>
              <td>Subtotal:</td>
              <td style="text-align: right;">₹${subtotal.toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td>GST (5%):</td>
              <td style="text-align: right;">₹${gst.toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td>Delivery Fee:</td>
              <td style="text-align: right;">₹${order.deliveryFee.toStringAsFixed(2)}</td>
            </tr>
            <tr style="font-weight: bold; border-top: 1px solid #333; font-size: 16px;">
              <td style="padding-top: 10px;">Grand Total:</td>
              <td style="text-align: right; padding-top: 10px; color: #0C831F;">₹${order.total.toStringAsFixed(2)}</td>
            </tr>
          </table>

          <div class="footer">
            Thank you for shopping with TurboCart! For queries, contact support@turbocart.com.
          </div>
        </body>
        </html>
      ''';

      js.context.callMethod('eval', ['''
        (function() {
          var w = window.open("", "_blank", "width=800,height=600");
          w.document.write(`${htmlContent.replaceAll('`', '\\`').replaceAll('\n', ' ')}`);
          w.document.close();
          w.onload = function() {
            w.print();
            setTimeout(function() { w.close(); }, 500);
          };
        })()
      ''']);
    } catch (e) {
      debugPrint('Printing failed: $e');
    }
  }

  Future<void> _updateOrderStatus(String newStatus, OrderModel order) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Track status timeline
      final statusHistory = Map<String, dynamic>.from(order.address['statusHistory'] ?? {});
      statusHistory[newStatus] = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'status': newStatus,
        'address.statusHistory': statusHistory,
      });

      await AdminLogger.log(
        actionType: 'UPDATE_ORDER_STATUS',
        affectedDocId: order.id,
        details: 'Order status changed to $newStatus',
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus successfully!'),
          backgroundColor: const Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _confirmCancelOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: const Text('Are you sure you want to cancel this order? This action will notify the customer and cancel the delivery process.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateOrderStatus('Cancelled', order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveNotes(String orderId) async {
    setState(() {
      _isUpdatingNotes = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'notes': _notesController.text.trim()});

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Admin notes saved successfully!'),
          backgroundColor: Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save notes: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isUpdatingNotes = false;
      });
    }
  }

  Future<void> _assignDeliveryPartner(String partnerId, String partnerName) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'deliveryPartnerId': partnerId,
        'deliveryPartnerName': partnerName,
      });

      await AdminLogger.log(
        actionType: 'ASSIGN_DELIVERY_PARTNER',
        affectedDocId: widget.orderId,
        details: 'Assigned delivery partner: $partnerName',
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Assigned delivery partner: $partnerName'),
          backgroundColor: const Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to assign partner: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading order details: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order document not found.'));
          }

          final order = OrderModel.fromMap(snapshot.data!.id, snapshot.data!.data() as Map<String, dynamic>);
          
          // Pre-populate notes once when loaded
          final docData = snapshot.data!.data() as Map<String, dynamic>;
          if (_notesController.text.isEmpty && docData.containsKey('notes')) {
            _notesController.text = docData['notes'] ?? '';
          }
          _selectedPartnerId = docData['deliveryPartnerId'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Nav row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/orders'),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order ID: #${order.id.toUpperCase()}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Placed on: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt.toDate())}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const Spacer(),
                     ElevatedButton.icon(
                      onPressed: () => _triggerPrint(order),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF374151),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Responsive Layout: 2 Columns
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 950;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildCustomerCard(order),
                                const SizedBox(height: 20),
                                _buildDeliveryAddressCard(order),
                                const SizedBox(height: 20),
                                _buildItemsListCard(order),
                                const SizedBox(height: 20),
                                _buildBillSummaryCard(order),
                                const SizedBox(height: 20),
                                _buildPaymentCard(order),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                _buildStatusManagementCard(order),
                                const SizedBox(height: 20),
                                _buildDeliveryPartnerCard(docData),
                                const SizedBox(height: 20),
                                _buildAdminNotesCard(order.id),
                                const SizedBox(height: 20),
                                _buildTimelineCard(order),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildStatusManagementCard(order),
                          const SizedBox(height: 20),
                          _buildCustomerCard(order),
                          const SizedBox(height: 20),
                          _buildDeliveryAddressCard(order),
                          const SizedBox(height: 20),
                          _buildItemsListCard(order),
                          const SizedBox(height: 20),
                          _buildBillSummaryCard(order),
                          const SizedBox(height: 20),
                          _buildPaymentCard(order),
                          const SizedBox(height: 20),
                          _buildDeliveryPartnerCard(docData),
                          const SizedBox(height: 20),
                          _buildAdminNotesCard(order.id),
                          const SizedBox(height: 20),
                          _buildTimelineCard(order),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel order) {
    final customerName = order.address['name'] ?? 'Guest';
    final customerPhone = order.address['phone'] ?? '-';
    final customerEmail = order.address['email'] ?? 'Not Provided';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Customer Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Name', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Text(customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phone', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Text(customerPhone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Text(customerEmail, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard(OrderModel order) {
    final building = order.address['building'] ?? '';
    final street = order.address['street'] ?? '';
    final city = order.address['city'] ?? '';
    final pincode = order.address['pincode'] ?? '';
    final fullAddress = '$building, $street, $city - $pincode';
    final lat = order.address['latitude'];
    final lng = order.address['longitude'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF0C831F)),
                const SizedBox(width: 8),
                const Text('Delivery Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const Spacer(),
                if (lat != null && lng != null)
                  TextButton.icon(
                    onPressed: () {
                      js.context.callMethod('open', ['https://www.google.com/maps/search/?api=1&query=$lat,$lng']);
                    },
                    icon: const Icon(Icons.map, size: 16, color: Color(0xFF0C831F)),
                    label: const Text('Open Coordinates Map', style: TextStyle(color: Color(0xFF0C831F))),
                  ),
              ],
            ),
            const Divider(height: 24),
            Text(
              fullAddress,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsListCard(OrderModel order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Ordered Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final item = order.items[index];
                final lineTotal = item.price * item.quantity;
                return Row(
                  children: [
                    // Item Image
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: item.product.images.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.product.images.first,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => const Icon(Icons.shopping_basket),
                              )
                            : const Icon(Icons.shopping_basket),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Variant: ${item.variant}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),

                    // Price * Quantity
                    Text(
                      '₹${item.price.toStringAsFixed(2)} x ${item.quantity}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(width: 32),

                    // Line total
                    Text(
                      '₹${lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummaryCard(OrderModel order) {
    // Basic calculations
    final subtotal = order.items.fold<double>(0, (totalSum, item) => totalSum + (item.price * item.quantity));
    final deliveryFee = order.deliveryFee;
    final discount = order.couponDiscount;
    final gst = subtotal * 0.05; // 5% GST assumption
    final total = order.total;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_outlined, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Bill Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            _buildSummaryRow('Items Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildSummaryRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            if (discount > 0) ...[
              _buildSummaryRow('Coupon Discount', '-₹${discount.toStringAsFixed(2)}', valueColor: Colors.green),
              const SizedBox(height: 8),
            ],
            _buildSummaryRow('GST (5%)', '₹${gst.toStringAsFixed(2)}'),
            const Divider(height: 20),
            _buildSummaryRow(
              'Grand Total',
              '₹${total.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 16,
              valueColor: const Color(0xFF0C831F),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF4B5563),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment_outlined, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Payment Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Method', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Text(order.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transaction ID', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Text(order.paymentId.isNotEmpty ? order.paymentId : 'N/A (Cash on Delivery)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Text(
                        order.paymentId.isNotEmpty ? 'COMPLETED' : 'PENDING ON DELIVERY',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: order.paymentId.isNotEmpty ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusManagementCard(OrderModel order) {
    Color chipBg;
    Color chipFg;
    final normalizedStatus = order.status.toLowerCase().replaceAll(' ', '_');
    switch (normalizedStatus) {
      case 'placed':
        chipBg = Colors.orange.shade50;
        chipFg = Colors.orange.shade700;
        break;
      case 'confirmed':
        chipBg = Colors.blue.shade50;
        chipFg = Colors.blue.shade700;
        break;
      case 'out_for_delivery':
        chipBg = Colors.teal.shade50;
        chipFg = Colors.teal.shade700;
        break;
      case 'delivered':
        chipBg = Colors.green.shade50;
        chipFg = Colors.green.shade700;
        break;
      case 'cancelled':
        chipBg = Colors.red.shade50;
        chipFg = Colors.red.shade700;
        break;
      default:
        chipBg = Colors.grey.shade100;
        chipFg = Colors.grey.shade700;
    }

    final List<String> statusKeys = [
      'placed',
      'confirmed',
      'out_for_delivery',
      'delivered',
      'cancelled'
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored Status banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'STATUS: ${order.status.replaceAll('_', ' ').toUpperCase()}',
                style: TextStyle(color: chipFg, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 20),

            // Dropdown Selector
            const Text('Change Status', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: statusKeys.contains(normalizedStatus) ? normalizedStatus : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: statusKeys
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.replaceAll('_', ' ').toUpperCase()),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val == null || val == normalizedStatus) return;
                if (val == 'cancelled') {
                  _confirmCancelOrder(order);
                } else {
                  _updateOrderStatus(val, order);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPartnerCard(Map<String, dynamic> docData) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_bike, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Delivery Partner', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('delivery_partners').snapshots(),
              builder: (context, snapshot) {
                // If stream is empty, or waiting, provide mock fallbacks so we aren't blocked!
                List<Map<String, String>> partners = [
                  {'id': 'partner_01', 'name': 'Ramesh Kumar'},
                  {'id': 'partner_02', 'name': 'Suresh Singh'},
                  {'id': 'partner_03', 'name': 'Vikram Rathore'},
                ];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  partners = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      'name': (data['name'] ?? 'Driver').toString(),
                    };
                  }).toList();
                }

                // Check if currently assigned partner is in list
                final currentId = _selectedPartnerId;
                final containsCurrent = partners.any((p) => p['id'] == currentId);

                return DropdownButtonFormField<String>(
                  value: containsCurrent ? currentId : null,
                  hint: const Text('Assign Partner...'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: partners.map((p) {
                    return DropdownMenuItem(
                      value: p['id'],
                      child: Text(p['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final partnerName = partners.firstWhere((p) => p['id'] == val)['name']!;
                    _assignDeliveryPartner(val, partnerName);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminNotesCard(String orderId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.notes, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Admin Notes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add internal warehouse notes, delay reasons, etc...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isUpdatingNotes ? null : () => _saveNotes(orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isUpdatingNotes
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('Save Notes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(OrderModel order) {
    final statusHistory = Map<String, dynamic>.from(order.address['statusHistory'] ?? {});
    final List<MapEntry<String, dynamic>> sortedHistory = statusHistory.entries.toList()
      ..sort((a, b) {
        final aTime = a.value as Timestamp;
        final bTime = b.value as Timestamp;
        return aTime.compareTo(bTime);
      });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Order Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            if (sortedHistory.isEmpty) ...[
              _buildTimelineRow('Order Placed', order.createdAt.toDate(), isFirst: true, isLast: true),
            ] else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedHistory.length,
                itemBuilder: (context, index) {
                  final entry = sortedHistory[index];
                  final timestamp = entry.value as Timestamp;
                  final statusText = entry.key;

                  return _buildTimelineRow(
                    statusText.toUpperCase(),
                    timestamp.toDate(),
                    isFirst: index == 0,
                    isLast: index == sortedHistory.length - 1,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(String title, DateTime dateTime, {bool isFirst = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dots and connector lines
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF0C831F),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Text Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(dateTime),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

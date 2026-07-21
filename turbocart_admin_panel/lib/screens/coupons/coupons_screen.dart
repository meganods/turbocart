import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/coupons_provider.dart';
import '../../models/coupon_model.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CouponsProvider>(context, listen: false).fetchCoupons();
    });
  }

  void _showDeleteConfirmation(Coupon coupon, CouponsProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Coupon', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete coupon code "${coupon.code}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await provider.deleteCoupon(coupon.code);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Coupon deleted successfully!' : 'Failed to delete coupon.'),
                    backgroundColor: success ? const Color(0xFF0C831F) : Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CouponsProvider>(context);
    final primaryGreen = const Color(0xFF0C831F);

    if (provider.isLoading && provider.coupons.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Bar
            Row(
              children: [
                const Text(
                  'Coupons & Offers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go('/coupons/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Coupon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table Card
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: provider.coupons.isEmpty
                    ? const Center(child: Text('No coupons available. Click Add Coupon to create one.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                            columns: const [
                              DataColumn(label: Text('Code')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Value')),
                              DataColumn(label: Text('Min Order')),
                              DataColumn(label: Text('Max Discount')),
                              DataColumn(label: Text('Expiry Date')),
                              DataColumn(label: Text('Usage (Used/Limit)')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: provider.coupons.map((coupon) {
                              final expiryDate = coupon.expiryDate.toDate();
                              final isExpired = coupon.isExpired;
                              final expiryText = DateFormat('dd MMM yyyy').format(expiryDate);
                              
                              String typeText = coupon.type.toUpperCase();
                              String valueText = '';
                              if (coupon.type == 'flat') {
                                valueText = '₹${coupon.value.toStringAsFixed(0)}';
                              } else if (coupon.type == 'percent') {
                                valueText = '${coupon.value.toStringAsFixed(0)}%';
                              } else {
                                valueText = 'FREE';
                                typeText = 'FREE DELIVERY';
                              }

                              return DataRow(
                                cells: [
                                  // Code
                                  DataCell(
                                    Text(
                                      coupon.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0C831F),
                                      ),
                                    ),
                                  ),
                                  // Type
                                  DataCell(Text(typeText)),
                                  // Value
                                  DataCell(Text(valueText)),
                                  // Min Order
                                  DataCell(Text('₹${coupon.minOrderAmount.toStringAsFixed(0)}')),
                                  // Max Discount
                                  DataCell(Text(coupon.maxDiscount > 0 ? '₹${coupon.maxDiscount.toStringAsFixed(0)}' : '-')),
                                  // Expiry Date (red if expired)
                                  DataCell(
                                    Text(
                                      expiryText,
                                      style: TextStyle(
                                        color: isExpired ? Colors.redAccent : Colors.black87,
                                        fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  // Usage
                                  DataCell(Text('${coupon.usedCount} / ${coupon.usageLimit}')),
                                  // Status Toggle Switch
                                  DataCell(
                                    Switch(
                                      value: coupon.active,
                                      activeColor: primaryGreen,
                                      onChanged: (val) async {
                                        await provider.toggleCouponStatus(coupon.code, val);
                                      },
                                    ),
                                  ),
                                  // Actions
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                          onPressed: () {
                                            context.go('/coupons/edit/${coupon.code}');
                                          },
                                          tooltip: 'Edit Coupon',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () => _showDeleteConfirmation(coupon, provider),
                                          tooltip: 'Delete Coupon',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

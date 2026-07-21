import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/order_model.dart';
import '../../utils/csv_exporter.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  // For tracking and animating newly arrived orders
  final Set<String> _seenOrderIds = {};
  final Set<String> _highlightedOrderIds = {};

  final List<String> _statusTabs = [
    'All',
    'Placed',
    'Confirmed',
    'Out for Delivery',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // refresh list on tab change
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0C831F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = null;
      _searchController.clear();
      _searchQuery = '';
      _tabController.index = 0;
    });
  }

  List<OrderModel> _currentFilteredOrders = [];

  void _playNotificationSound() {
    try {
      js.context.callMethod('eval', ['''
        (function() {
          var audio = new Audio('https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav');
          audio.play();
        })()
      ''']);
    } catch (e) {
      debugPrint('Failed to play sound: $e');
    }
  }

  // Row highlight tracker
  void _processNewOrders(List<OrderModel> orders) {
    if (_seenOrderIds.isEmpty) {
      // First load: mark all existing as seen, no highlighting
      for (final o in orders) {
        _seenOrderIds.add(o.id);
      }
      return;
    }

    for (final o in orders) {
      if (!_seenOrderIds.contains(o.id)) {
        _seenOrderIds.add(o.id);
        _highlightedOrderIds.add(o.id);
        _playNotificationSound();

        // Remove highlight after 4 seconds
        Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _highlightedOrderIds.remove(o.id);
            });
          }
        });
      }
    }
  }

  List<OrderModel> _filterOrders(List<OrderModel> allOrders) {
    final selectedTab = _statusTabs[_tabController.index];

    return allOrders.where((order) {
      // 1. Status Filter
      if (selectedTab != 'All') {
        if (order.status.toLowerCase() != selectedTab.toLowerCase()) {
          return false;
        }
      }

      // 2. Search query (ID or Phone)
      if (_searchQuery.isNotEmpty) {
        final idMatch = order.id.toLowerCase().contains(_searchQuery.toLowerCase());
        final phone = order.address['phone']?.toString() ?? '';
        final phoneMatch = phone.contains(_searchQuery);
        if (!idMatch && !phoneMatch) return false;
      }

      // 3. Date Range Filter
      if (_selectedDateRange != null) {
        final dt = order.createdAt.toDate();
        // Shift start of day and end of day to cover full range
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (dt.isBefore(start) || dt.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Filter and Tab Navigation Card
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tabs selection row
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: primaryGreen,
                  unselectedLabelColor: const Color(0xFF4B5563),
                  indicatorColor: primaryGreen,
                  dividerColor: Colors.grey.shade200,
                  tabs: _statusTabs.map((status) => Tab(text: status)).toList(),
                ),

                // Controls: Search & Date Pickers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      // Search field
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by Order ID or customer phone number...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Date range picker button
                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          _selectedDateRange == null
                              ? 'Filter by Date'
                              : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 16),

                      ElevatedButton.icon(
                        onPressed: () {
                          if (_currentFilteredOrders.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No orders to export.')),
                            );
                            return;
                          }
                          final header = ['Order ID', 'Customer Name', 'Phone', 'Status', 'Total', 'Payment Method', 'Created At'];
                          final List<List<dynamic>> rows = [
                            header,
                            ..._currentFilteredOrders.map((o) => [
                              o.id,
                              o.address['name'] ?? '',
                              o.address['phone'] ?? '',
                              o.status,
                              o.total,
                              o.paymentMethod,
                              DateFormat('dd MMM yyyy, hh:mm a').format(o.createdAt.toDate())
                            ])
                          ];
                          CsvExporter.exportToCsv(rows: rows, filename: 'orders_export.csv');
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryGreen,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Clear filters button
                      if (_selectedDateRange != null || _searchQuery.isNotEmpty || _tabController.index != 0)
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear, size: 16, color: Colors.redAccent),
                          label: const Text('Clear Filters', style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. StreamBuilder Orders Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading orders: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
                    ),
                  );
                }

                final allOrders = snapshot.data!.docs
                    .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();

                // Process highlight trackers
                _processNewOrders(allOrders);

                final filteredList = _filterOrders(allOrders);
                _currentFilteredOrders = filteredList;

                if (filteredList.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No orders found matching the filter parameters.', style: TextStyle(color: Color(0xFF6B7280))),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
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
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Phone')),
                            DataColumn(label: Text('Items')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Payment')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Date/Time')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filteredList.map((order) {
                            final dateStr = DateFormat('dd MMM, h:mm a').format(order.createdAt.toDate());
                            final customerName = order.address['name'] ?? 'Guest';
                            final customerPhone = order.address['phone'] ?? '-';
                            final totalItems = order.items.fold<int>(0, (itemCount, item) => itemCount + item.quantity);
                            final isNew = _highlightedOrderIds.contains(order.id);

                            return DataRow(
                              color: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (isNew) {
                                  return Colors.amber.shade50.withOpacity(0.4); // Highlight fresh orders
                                }
                                return null;
                              }),
                              cells: [
                                // ID
                                DataCell(
                                  Text(
                                    '#${order.id.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0C831F),
                                    ),
                                  ),
                                ),
                                // Customer
                                DataCell(Text(customerName)),
                                // Phone
                                DataCell(Text(customerPhone)),
                                // Items
                                DataCell(Text('$totalItems items')),
                                // Total
                                DataCell(Text('₹${order.total.toStringAsFixed(2)}')),
                                // Payment
                                DataCell(Text(order.paymentMethod.toUpperCase())),
                                // Status colored chip
                                DataCell(_buildStatusChip(order.status)),
                                // Date/Time
                                DataCell(Text(dateStr)),
                                // Actions
                                DataCell(
                                  ElevatedButton(
                                    onPressed: () {
                                      context.go('/orders/${order.id}');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0C831F).withOpacity(0.08),
                                      foregroundColor: const Color(0xFF0C831F),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
}

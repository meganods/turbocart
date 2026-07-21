import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class DashboardProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  int _ordersToday = 0;
  double _revenueToday = 0.0;
  int _pendingOrders = 0;
  int _totalProducts = 0;
  int _lowStockAlert = 0;
  int _newUsersThisWeek = 0;

  List<OrderModel> _recentOrders = [];
  List<Product> _lowStockProducts = [];
  
  Map<String, int> _dailyHourlyOrders = {};
  Map<String, int> _dailyHourlyVisitors = {};

  Map<String, int> _weeklyOrders = {};
  Map<String, int> _weeklyVisitors = {};

  Map<String, int> _monthlyOrders = {};
  Map<String, int> _monthlyVisitors = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get ordersToday => _ordersToday;
  double get revenueToday => _revenueToday;
  int get pendingOrders => _pendingOrders;
  int get totalProducts => _totalProducts;
  int get lowStockAlert => _lowStockAlert;
  int get newUsersThisWeek => _newUsersThisWeek;
  List<OrderModel> get recentOrders => _recentOrders;
  List<Product> get lowStockProducts => _lowStockProducts;

  Map<String, int> get dailyHourlyOrders => _dailyHourlyOrders;
  Map<String, int> get dailyHourlyVisitors => _dailyHourlyVisitors;

  Map<String, int> get weeklyOrders => _weeklyOrders;
  Map<String, int> get weeklyVisitors => _weeklyVisitors;

  Map<String, int> get monthlyOrders => _monthlyOrders;
  Map<String, int> get monthlyVisitors => _monthlyVisitors;

  String _selectedDateFilter = 'Today';
  DateTimeRange? _customDateRange;

  String get selectedDateFilter => _selectedDateFilter;
  DateTimeRange? get customDateRange => _customDateRange;

  void setDateFilter(String filter, [DateTimeRange? customRange]) {
    _selectedDateFilter = filter;
    _customDateRange = customRange;
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      
      // Determine date ranges based on selection
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (_selectedDateFilter == 'Yesterday') {
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = DateTime(now.year, now.month, now.day).subtract(const Duration(milliseconds: 1));
      } else if (_selectedDateFilter == 'Last 7 Days') {
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      } else if (_selectedDateFilter == 'Custom' && _customDateRange != null) {
        startDate = _customDateRange!.start;
        endDate = _customDateRange!.end;
      } else {
        // Today
        startDate = DateTime(now.year, now.month, now.day);
      }

      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);

      final weekTimestamp = Timestamp.fromDate(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)));
      final monthTimestamp = Timestamp.fromDate(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)));

      // 1. Orders Period & Revenue Period Queries
      final todayOrdersSnapshot = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      _ordersToday = todayOrdersSnapshot.docs.length;
      _revenueToday = todayOrdersSnapshot.docs.fold(0.0, (totalSum, doc) {
        final data = doc.data();
        if (data['status'] == 'delivered') {
          final totalVal = data['total'] ?? 0.0;
          return totalSum + (totalVal is num ? totalVal.toDouble() : double.tryParse(totalVal.toString()) ?? 0.0);
        }
        return totalSum;
      });

      // 2. Pending Orders Query
      final pendingSnapshot = await _db
          .collection('orders')
          .where('status', whereIn: ['placed', 'confirmed'])
          .get();
      _pendingOrders = pendingSnapshot.docs.length;

      // 3. Products Count & Low Stock Queries
      final productsSnapshot = await _db.collection('products').get();
      _totalProducts = productsSnapshot.docs.length;

      _lowStockProducts = productsSnapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .where((p) => p.stock < 10)
          .toList();
      _lowStockAlert = _lowStockProducts.length;

      // 4. New Users This Week Query
      try {
        final usersSnapshot = await _db
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: weekTimestamp)
            .get();
        _newUsersThisWeek = usersSnapshot.docs.length;
      } catch (e) {
        debugPrint('Users query failed (falling back to 0): $e');
        _newUsersThisWeek = 0;
      }

      // 5. Recent 10 Orders
      final recentOrdersSnapshot = await _db
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      _recentOrders = recentOrdersSnapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
          .toList();

      // 6. Calculate Chart Data
      _calculateDailyHourlyOrders(todayOrdersSnapshot.docs);
      await _calculateWeeklyOrders(weekTimestamp);
      await _calculateMonthlyOrders(monthTimestamp);

      // 7. Inject Premium Dummy Preview Data if real metrics are empty
      _injectDummyPreviewDataIfNeeded();

    } catch (e) {
      _error = 'Failed to load dashboard data: $e';
      debugPrint('Dashboard data load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _injectDummyPreviewDataIfNeeded() {
    // Check if daily orders are empty
    final totalDaily = _dailyHourlyOrders.values.fold(0, (sum, v) => sum + v);
    if (totalDaily == 0) {
      _dailyHourlyOrders = {
        '12 AM': 4,
        '3 AM': 2,
        '6 AM': 8,
        '9 AM': 18,
        '12 PM': 30,
        '3 PM': 25,
        '6 PM': 38,
        '9 PM': 14,
      };
      _dailyHourlyVisitors = {
        '12 AM': 20,
        '3 AM': 12,
        '6 AM': 35,
        '9 AM': 80,
        '12 PM': 140,
        '3 PM': 110,
        '6 PM': 180,
        '9 PM': 75,
      };
    } else {
      // If we have actual orders, mock a proportional visitor curve
      _dailyHourlyOrders.forEach((k, v) {
        _dailyHourlyVisitors[k] = v * 5 + 10;
      });
    }

    // Check if weekly orders are empty
    final totalWeekly = _weeklyOrders.values.fold(0, (sum, v) => sum + v);
    if (totalWeekly == 0) {
      _weeklyOrders = {
        'Mon': 15,
        'Tue': 28,
        'Wed': 20,
        'Thu': 35,
        'Fri': 45,
        'Sat': 60,
        'Sun': 50,
      };
      _weeklyVisitors = {
        'Mon': 85,
        'Tue': 130,
        'Wed': 110,
        'Thu': 160,
        'Fri': 210,
        'Sat': 290,
        'Sun': 240,
      };
    } else {
      _weeklyOrders.forEach((k, v) {
        _weeklyVisitors[k] = v * 5 + 15;
      });
    }

    // Check if monthly orders are empty
    final totalMonthly = _monthlyOrders.values.fold(0, (sum, v) => sum + v);
    if (totalMonthly == 0) {
      final now = DateTime.now();
      _monthlyOrders = {};
      _monthlyVisitors = {};
      for (int i = 5; i >= 0; i--) {
        final date = now.subtract(Duration(days: i * 5));
        final dateStr = DateFormat('dd MMM').format(date);
        
        // Mock sinusoidal curves for preview
        final int ordersMock = 80 + (i * 25) + (i % 2 == 0 ? 15 : -15);
        _monthlyOrders[dateStr] = ordersMock;
        _monthlyVisitors[dateStr] = ordersMock * 4 + 100;
      }
    } else {
      _monthlyOrders.forEach((k, v) {
        _monthlyVisitors[k] = v * 4 + 80;
      });
    }
  }

  void _calculateDailyHourlyOrders(List<QueryDocumentSnapshot> todayDocs) {
    final tempMap = <String, int>{};

    final hoursList = ['12 AM', '3 AM', '6 AM', '9 AM', '12 PM', '3 PM', '6 PM', '9 PM'];
    for (final hour in hoursList) {
      tempMap[hour] = 0;
    }

    for (final doc in todayDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? created = data['createdAt'];
      if (created != null) {
        final dt = created.toDate();
        final hour = dt.hour;
        final roundedHour = ((hour + 1) ~/ 3) * 3;
        final index = (roundedHour ~/ 3) % 8;
        final hourStr = hoursList[index];
        if (tempMap.containsKey(hourStr)) {
          tempMap[hourStr] = tempMap[hourStr]! + 1;
        }
      }
    }

    _dailyHourlyOrders = tempMap;
  }

  Future<void> _calculateWeeklyOrders(Timestamp weekTimestamp) async {
    final lastWeekOrdersSnapshot = await _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: weekTimestamp)
        .get();

    final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final tempMap = <String, int>{};

    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayName = weekdayNames[day.weekday - 1];
      tempMap[dayName] = 0;
    }

    for (final doc in lastWeekOrdersSnapshot.docs) {
      final data = doc.data();
      final Timestamp? created = data['createdAt'];
      if (created != null) {
        final dt = created.toDate();
        final dayName = weekdayNames[dt.weekday - 1];
        if (tempMap.containsKey(dayName)) {
          tempMap[dayName] = tempMap[dayName]! + 1;
        }
      }
    }

    _weeklyOrders = tempMap;
  }

  Future<void> _calculateMonthlyOrders(Timestamp monthTimestamp) async {
    final lastMonthOrdersSnapshot = await _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: monthTimestamp)
        .get();

    final tempMap = <String, int>{};
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final date = now.subtract(Duration(days: i * 5));
      final dateStr = DateFormat('dd MMM').format(date);
      tempMap[dateStr] = 0;
    }

    for (final doc in lastMonthOrdersSnapshot.docs) {
      final data = doc.data();
      final Timestamp? created = data['createdAt'];
      if (created != null) {
        final dt = created.toDate();
        
        String matchedKey = '';
        int minDiff = 999;
        
        for (final key in tempMap.keys) {
          final keyDate = DateFormat('dd MMM').parse(key);
          final targetDate = DateTime(now.year, keyDate.month, keyDate.day);
          final diff = (dt.difference(targetDate).inDays).abs();
          if (diff < minDiff) {
            minDiff = diff;
            matchedKey = key;
          }
        }

        if (matchedKey.isNotEmpty && minDiff <= 3) {
          tempMap[matchedKey] = tempMap[matchedKey]! + 1;
        }
      }
    }

    _monthlyOrders = tempMap;
  }

  Future<bool> restockProduct(String productId, int newStock) async {
    try {
      await _db.collection('products').doc(productId).update({'stock': newStock});
      
      final idx = _lowStockProducts.indexWhere((p) => p.id == productId);
      if (idx >= 0) {
        final updatedProduct = Product(
          id: _lowStockProducts[idx].id,
          name: _lowStockProducts[idx].name,
          nameHindi: _lowStockProducts[idx].nameHindi,
          brand: _lowStockProducts[idx].brand,
          category: _lowStockProducts[idx].category,
          subcategory: _lowStockProducts[idx].subcategory,
          description: _lowStockProducts[idx].description,
          images: _lowStockProducts[idx].images,
          tags: _lowStockProducts[idx].tags,
          price: _lowStockProducts[idx].price,
          mrp: _lowStockProducts[idx].mrp,
          rating: _lowStockProducts[idx].rating,
          discount: _lowStockProducts[idx].discount,
          stock: newStock,
          reviewCount: _lowStockProducts[idx].reviewCount,
          isDeal: _lowStockProducts[idx].isDeal,
          isBestSeller: _lowStockProducts[idx].isBestSeller,
          weight: _lowStockProducts[idx].weight,
          unit: _lowStockProducts[idx].unit,
          isActive: _lowStockProducts[idx].isActive,
          searchKeywords: _lowStockProducts[idx].searchKeywords,
          searchKeywordsHindi: _lowStockProducts[idx].searchKeywordsHindi,
        );

        if (newStock >= 10) {
          _lowStockProducts.removeAt(idx);
          _lowStockAlert--;
        } else {
          _lowStockProducts[idx] = updatedProduct;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Restock product failed: $e');
      return false;
    }
  }
}

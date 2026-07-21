import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'cart_provider.dart';

class OrderItem {
  final String id;
  final double amount;
  final List<CartItem> products;
  final DateTime dateTime;
  final String status;

  OrderItem({
    required this.id,
    required this.amount,
    required this.products,
    required this.dateTime,
    required this.status,
  });
}

class OrderProvider with ChangeNotifier {
  final List<OrderItem> _orders = [];
  List<OrderModel> _firestoreOrders = [];

  List<OrderItem> get orders => [..._orders];
  List<OrderModel> get firestoreOrders => [..._firestoreOrders];

  void addOrder(List<CartItem> cartProducts, double total) {
    _orders.insert(
      0,
      OrderItem(
        id: DateTime.now().toString(),
        amount: total,
        dateTime: DateTime.now(),
        products: cartProducts,
        status: 'placed',
      ),
    );
    notifyListeners();
  }

  void updateOrderStatus(String orderId, String newStatus) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex >= 0) {
      final existing = _orders[orderIndex];
      _orders[orderIndex] = OrderItem(
        id: existing.id,
        amount: existing.amount,
        products: existing.products,
        dateTime: existing.dateTime,
        status: newStatus,
      );
      notifyListeners();
    }
  }

  // Firestore integration
  Future<void> fetchOrders(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _firestoreOrders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch orders failed: $e');
    }
  }

  Future<String> createOrder(OrderModel order) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(order.toMap());
      
      final newOrder = OrderModel(
        id: docRef.id,
        userId: order.userId,
        status: order.status,
        paymentMethod: order.paymentMethod,
        paymentId: order.paymentId,
        couponCode: order.couponCode,
        items: order.items,
        address: order.address,
        subtotal: order.subtotal,
        deliveryFee: order.deliveryFee,
        couponDiscount: order.couponDiscount,
        total: order.total,
        createdAt: order.createdAt,
      );
      _firestoreOrders.insert(0, newOrder);
      notifyListeners();
      return docRef.id;
    } catch (e) {
      debugPrint('Create order failed: $e');
      return 'local_mock_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}

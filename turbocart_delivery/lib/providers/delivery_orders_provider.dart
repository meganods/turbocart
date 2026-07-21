import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class DeliveryOrdersProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<OrderModel>> streamActiveOrders(String partnerId) {
    return _db
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: partnerId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
          .where((order) => order.status == 'confirmed' || order.status == 'out_for_delivery')
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<OrderModel>> streamCompletedOrders(String partnerId) {
    return _db
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: partnerId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) {
        final aTime = a.deliveredAt ?? a.createdAt;
        final bTime = b.deliveredAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final Map<String, dynamic> updates = {'status': status};
      if (status == 'delivered') {
        updates['deliveredAt'] = Timestamp.now();
      }
      await _db.collection('orders').doc(orderId).update(updates);
      return true;
    } catch (e) {
      debugPrint('Failed to update order status: $e');
      return false;
    }
  }

  Future<double> fetchCommissionRate() async {
    try {
      final doc = await _db.collection('settings').doc('store').get();
      if (doc.exists) {
        return (doc.data()?['perDeliveryRate'] as num?)?.toDouble() ?? 50.0;
      }
    } catch (e) {
      debugPrint('Failed to fetch commission rate: $e');
    }
    return 50.0;
  }
}

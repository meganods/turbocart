import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final String status;
  final String paymentMethod;
  final String paymentId;
  final String couponCode;
  final List<CartItem> items;
  final Map<String, dynamic> address;
  final double subtotal;
  final double deliveryFee;
  final double couponDiscount;
  final double total;
  final Timestamp createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.paymentMethod,
    required this.paymentId,
    required this.couponCode,
    required this.items,
    required this.address,
    required this.subtotal,
    required this.deliveryFee,
    required this.couponDiscount,
    required this.total,
    required this.createdAt,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final itemsList = (map['items'] as List<dynamic>?)
            ?.map((item) => CartItem.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];

    return OrderModel(
      id: id,
      userId: map['userId'] ?? '',
      status: map['status'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      paymentId: map['paymentId'] ?? '',
      couponCode: map['couponCode'] ?? '',
      items: itemsList,
      address: Map<String, dynamic>.from(map['address'] ?? {}),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      couponDiscount: (map['couponDiscount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'couponCode': couponCode,
      'items': items.map((item) => item.toMap()).toList(),
      'address': address,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'couponDiscount': couponDiscount,
      'total': total,
      'createdAt': createdAt,
    };
  }
}

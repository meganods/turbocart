import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final String status;
  final String paymentMethod;
  final List<CartItem> items;
  final Map<String, dynamic> address;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final Timestamp createdAt;
  final String? deliveryPartnerId;
  final Timestamp? deliveredAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.paymentMethod,
    required this.items,
    required this.address,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.createdAt,
    this.deliveryPartnerId,
    this.deliveredAt,
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
      items: itemsList,
      address: Map<String, dynamic>.from(map['address'] ?? {}),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      deliveryPartnerId: map['deliveryPartnerId'],
      deliveredAt: map['deliveredAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'paymentMethod': paymentMethod,
      'items': items.map((item) => {
        'productId': item.productId,
        'productName': item.productName,
        'variant': item.variant,
        'quantity': item.quantity,
        'price': item.price,
        'imageUrl': item.imageUrl,
      }).toList(),
      'address': address,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'createdAt': createdAt,
      'deliveryPartnerId': deliveryPartnerId,
      'deliveredAt': deliveredAt,
    };
  }
}

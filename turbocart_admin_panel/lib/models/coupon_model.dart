import 'package:cloud_firestore/cloud_firestore.dart';

class Coupon {
  final String code;
  final String type; // 'flat', 'percent', 'freeDelivery'
  final double value;
  final double minOrderAmount;
  final double maxDiscount;
  final Timestamp expiryDate;
  final int usageLimit;
  final int usedCount;
  final String description;
  final bool active;

  Coupon({
    required this.code,
    required this.type,
    required this.value,
    required this.minOrderAmount,
    required this.maxDiscount,
    required this.expiryDate,
    required this.usageLimit,
    required this.usedCount,
    required this.description,
    required this.active,
  });

  factory Coupon.fromMap(String id, Map<String, dynamic> map) {
    return Coupon(
      code: id,
      type: map['type'] ?? 'flat',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (map['maxDiscount'] as num?)?.toDouble() ?? 0.0,
      expiryDate: map['expiryDate'] ?? Timestamp.now(),
      usageLimit: (map['usageLimit'] as num?)?.toInt() ?? 0,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      description: map['description'] ?? '',
      active: map['active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'type': type,
      'value': value,
      'minOrderAmount': minOrderAmount,
      'maxDiscount': maxDiscount,
      'expiryDate': expiryDate,
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'description': description,
      'active': active,
    };
  }

  bool get isExpired {
    return expiryDate.toDate().isBefore(DateTime.now());
  }
}

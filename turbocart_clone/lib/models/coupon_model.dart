import 'package:cloud_firestore/cloud_firestore.dart';

class Coupon {
  final String code;
  final String type;
  final double value;
  final double minOrder;
  final double maxDiscount;
  final Timestamp expiryDate;
  final int usageLimit;
  final int usedCount;
  final bool active;

  Coupon({
    required this.code,
    required this.type,
    required this.value,
    required this.minOrder,
    required this.maxDiscount,
    required this.expiryDate,
    required this.usageLimit,
    required this.usedCount,
    required this.active,
  });

  factory Coupon.fromMap(String code, Map<String, dynamic> map) {
    return Coupon(
      code: code,
      type: map['type'] ?? 'flat',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      minOrder: (map['minOrder'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (map['maxDiscount'] as num?)?.toDouble() ?? 0.0,
      expiryDate: map['expiryDate'] ?? Timestamp.now(),
      usageLimit: (map['usageLimit'] as num?)?.toInt() ?? 9999,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      active: map['active'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'minOrder': minOrder,
      'maxDiscount': maxDiscount,
      'expiryDate': expiryDate,
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'active': active,
    };
  }
}

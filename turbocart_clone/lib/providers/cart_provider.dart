import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class CartItem {
  final String id;
  final String title;
  final int quantity;
  final double price;
  final String imageUrl;
  final String unit;

  CartItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.price,
    required this.imageUrl,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
      'unit': unit,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      unit: map['unit'] ?? '',
    );
  }
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  double _couponDiscount = 0.0;
  String _appliedCoupon = '';
  String _couponType = ''; // 'flat', 'percent', 'freeDelivery'

  double _deliveryFeeThreshold = 199.0;
  double _gstPercent = 5.0;
  double _flatDeliveryFee = 40.0;

  CartProvider() {
    _loadFromPrefs();
    _listenToStoreSettings();
  }

  void _listenToStoreSettings() {
    FirebaseFirestore.instance.collection('settings').doc('store').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          _deliveryFeeThreshold = (data['deliveryFeeThreshold'] as num?)?.toDouble() ?? 199.0;
          _gstPercent = (data['gstPercent'] as num?)?.toDouble() ?? 5.0;
          notifyListeners();
        }
      }
    });
  }

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length; // Number of unique items

  int get totalItems {
    var total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.quantity;
    });
    return total;
  }

  int get totalQuantity => totalItems;

  double get subtotal {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  double get totalAmount => subtotal;

  double get deliveryFee {
    if (subtotal == 0) return 0.0;
    if (_couponType == 'freeDelivery') return 0.0;
    return subtotal >= _deliveryFeeThreshold ? 0.0 : _flatDeliveryFee;
  }

  double get taxes {
    return double.parse((subtotal * (_gstPercent / 100)).toStringAsFixed(2));
  }

  double get couponDiscount => _couponDiscount;
  String get appliedCoupon => _appliedCoupon;
  String get couponType => _couponType;

  double get grandTotal {
    final double rawTotal = subtotal + deliveryFee + taxes - _couponDiscount;
    return rawTotal < 0 ? 0.0 : double.parse(rawTotal.toStringAsFixed(2));
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _items.map((key, item) => MapEntry(key, item.toMap()));
      await prefs.setString('user_cart', json.encode(data));
      await prefs.setString('cart_coupon_code', _appliedCoupon);
      await prefs.setDouble('cart_coupon_discount', _couponDiscount);
      await prefs.setString('cart_coupon_type', _couponType);
    } catch (e) {
      debugPrint('Failed to save cart to SharedPreferences: $e');
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('user_cart');
      if (cartStr != null) {
        final Map<String, dynamic> decoded = json.decode(cartStr);
        _items.clear();
        decoded.forEach((key, map) {
          _items[key] = CartItem.fromMap(Map<String, dynamic>.from(map));
        });
      }
      _appliedCoupon = prefs.getString('cart_coupon_code') ?? '';
      _couponDiscount = prefs.getDouble('cart_coupon_discount') ?? 0.0;
      _couponType = prefs.getString('cart_coupon_type') ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load cart from SharedPreferences: $e');
    }
  }

  // Supporting both old and new signatures
  void addItem(
    dynamic product, [
    dynamic variant,
    double? price,
    String? imageUrl,
    String? unit,
  ]) {
    String productId;
    String title;
    double itemPrice;
    String itemImageUrl;
    String itemVariant;

    if (product is Map) {
      productId = product['id']?.toString() ?? '';
      title = product['title']?.toString() ?? '';
      itemPrice = price ?? ((product['price'] as num?)?.toDouble() ?? 0.0);
      itemImageUrl = imageUrl ?? product['image']?.toString() ?? '';
      itemVariant = variant as String? ?? product['unit']?.toString() ?? 'each';
    } else if (product is String) {
      productId = product;
      if (imageUrl != null) {
        // Old signature: addItem(productId, title, price, imageUrl, unit)
        title = variant as String;
        itemPrice = price!;
        itemImageUrl = imageUrl;
        itemVariant = unit ?? 'each';
      } else {
        // New signature: addItem(productId, variant, price)
        title = productId; // fallback
        itemVariant = variant as String? ?? 'each';
        itemPrice = price ?? 0.0;
        itemImageUrl = '';
      }
    } else {
      productId = '';
      title = '';
      itemPrice = 0.0;
      itemImageUrl = '';
      itemVariant = 'each';
    }

    final key = '${productId}_$itemVariant';
    if (_items.containsKey(key)) {
      _items.update(
        key,
        (existing) => CartItem(
          id: existing.id,
          title: existing.title,
          quantity: existing.quantity + 1,
          price: existing.price,
          imageUrl: existing.imageUrl,
          unit: existing.unit,
        ),
      );
    } else {
      _items.putIfAbsent(
        key,
        () => CartItem(
          id: productId,
          title: title,
          quantity: 1,
          price: itemPrice,
          imageUrl: itemImageUrl,
          unit: itemVariant,
        ),
      );
    }

    _reEvaluateCoupon();
    _saveToPrefs();
    notifyListeners();
  }

  void removeItem(String productId, [String? variant]) {
    String key;
    if (variant != null) {
      key = '${productId}_$variant';
    } else {
      final matchingKey = _items.keys.firstWhere(
        (k) => k.startsWith('${productId}_') || k == productId,
        orElse: () => '',
      );
      if (matchingKey.isEmpty) return;
      key = matchingKey;
    }

    if (!_items.containsKey(key)) return;

    if (_items[key]!.quantity > 1) {
      _items.update(
        key,
        (existing) => CartItem(
          id: existing.id,
          title: existing.title,
          quantity: existing.quantity - 1,
          price: existing.price,
          imageUrl: existing.imageUrl,
          unit: existing.unit,
        ),
      );
    } else {
      _items.remove(key);
    }

    _reEvaluateCoupon();
    _saveToPrefs();
    notifyListeners();
  }

  void deleteItem(String productId, [String? variant]) {
    String key;
    if (variant != null) {
      key = '${productId}_$variant';
    } else {
      final matchingKey = _items.keys.firstWhere(
        (k) => k.startsWith('${productId}_') || k == productId,
        orElse: () => '',
      );
      if (matchingKey.isEmpty) return;
      key = matchingKey;
    }

    _items.remove(key);
    _reEvaluateCoupon();
    _saveToPrefs();
    notifyListeners();
  }

  void updateQuantity(String productId, String variant, int quantity) {
    final key = '${productId}_$variant';
    if (!_items.containsKey(key)) return;
    if (quantity <= 0) {
      _items.remove(key);
    } else {
      _items.update(
        key,
        (existing) => CartItem(
          id: existing.id,
          title: existing.title,
          quantity: quantity,
          price: existing.price,
          imageUrl: existing.imageUrl,
          unit: existing.unit,
        ),
      );
    }
    _reEvaluateCoupon();
    _saveToPrefs();
    notifyListeners();
  }

  void applyCoupon(String code, double discount, [String type = 'flat']) {
    _appliedCoupon = code;
    _couponType = type;
    if (type == 'freeDelivery') {
      _couponDiscount = 0.0;
    } else {
      _couponDiscount = discount;
    }
    _saveToPrefs();
    notifyListeners();
  }

  void removeCoupon() {
    _appliedCoupon = '';
    _couponDiscount = 0.0;
    _couponType = '';
    _saveToPrefs();
    notifyListeners();
  }

  void _reEvaluateCoupon() {
    if (_appliedCoupon.isEmpty) return;
    if (subtotal == 0) {
      removeCoupon();
      return;
    }
  }

  void clearCart() {
    _items.clear();
    removeCoupon();
    _saveToPrefs();
    notifyListeners();
  }
}

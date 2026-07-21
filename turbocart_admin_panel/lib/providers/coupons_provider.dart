import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coupon_model.dart';

class CouponsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Coupon> _coupons = [];
  bool _isLoading = false;
  String? _error;

  List<Coupon> get coupons => _coupons;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCoupons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db.collection('coupons').get();
      _coupons = snapshot.docs
          .map((doc) => Coupon.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      _error = 'Failed to load coupons: $e';
      debugPrint('Error loading coupons: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCoupon(Coupon coupon) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docData = coupon.toMap();
      await _db.collection('coupons').doc(coupon.code).set(docData);
      
      final idx = _coupons.indexWhere((c) => c.code == coupon.code);
      if (idx >= 0) {
        _coupons[idx] = coupon;
      } else {
        _coupons.add(coupon);
      }
      return true;
    } catch (e) {
      debugPrint('Save coupon failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleCouponStatus(String code, bool activeState) async {
    try {
      await _db.collection('coupons').doc(code).update({'active': activeState});
      final idx = _coupons.indexWhere((c) => c.code == code);
      if (idx >= 0) {
        final old = _coupons[idx];
        _coupons[idx] = Coupon(
          code: old.code,
          type: old.type,
          value: old.value,
          minOrderAmount: old.minOrderAmount,
          maxDiscount: old.maxDiscount,
          expiryDate: old.expiryDate,
          usageLimit: old.usageLimit,
          usedCount: old.usedCount,
          description: old.description,
          active: activeState,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Failed to toggle coupon status: $e');
      return false;
    }
  }

  Future<bool> deleteCoupon(String code) async {
    try {
      await _db.collection('coupons').doc(code).delete();
      _coupons.removeWhere((c) => c.code == code);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete coupon failed: $e');
      return false;
    }
  }
}

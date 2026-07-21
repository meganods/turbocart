import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/partner_model.dart';

class DeliveryAuthProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PartnerModel? _partner;
  bool _isLoading = false;
  String? _error;

  PartnerModel? get partner => _partner;
  bool get isLoggedIn => _partner != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('partner_uid');
    if (uid != null) {
      if (FirebaseAuth.instance.currentUser == null) {
        await signOut();
        return;
      }
      try {
        final doc = await _db.collection('delivery_partners').doc(uid).get();
        if (doc.exists) {
          _partner = PartnerModel.fromMap(doc.id, doc.data()!);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Auto-login failed: $e');
      }
    }
  }

  Future<bool> verifyPhoneNumber(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var snapshot = await _db
          .collection('delivery_partners')
          .where('phone', isEqualTo: phone)
          .get();

      if (snapshot.docs.isEmpty && phone.startsWith('+91')) {
        final rawPhone = phone.replaceFirst('+91', '');
        snapshot = await _db
            .collection('delivery_partners')
            .where('phone', isEqualTo: rawPhone)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _error = 'You are not registered as a delivery partner. Contact your admin.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Verification failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var snapshot = await _db
          .collection('delivery_partners')
          .where('phone', isEqualTo: phone)
          .get();

      if (snapshot.docs.isEmpty && phone.startsWith('+91')) {
        final rawPhone = phone.replaceFirst('+91', '');
        snapshot = await _db
            .collection('delivery_partners')
            .where('phone', isEqualTo: rawPhone)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _error = 'You are not registered as a delivery partner. Contact your admin.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final doc = snapshot.docs.first;

      final userCred = await FirebaseAuth.instance.signInAnonymously();
      final authUid = userCred.user!.uid;

      await _db.collection('driver_sessions').doc(authUid).set({
        'partnerId': doc.id,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _partner = PartnerModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('partner_uid', doc.id);
      await prefs.setString('partner_phone', phone);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleAvailability(bool isOnline) async {
    if (_partner == null) return;
    try {
      await _db.collection('delivery_partners').doc(_partner!.uid).update({'isOnline': isOnline});
      _partner = PartnerModel(
        uid: _partner!.uid,
        name: _partner!.name,
        phone: _partner!.phone,
        photoUrl: _partner!.photoUrl,
        vehicleType: _partner!.vehicleType,
        isOnline: isOnline,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to toggle availability status: $e');
    }
  }

  Future<void> signOut() async {
    _partner = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('partner_uid');
    await prefs.remove('partner_phone');
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UsersProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<UserModel> _users = [];
  Map<String, int> _userOrderCounts = {};
  Map<String, double> _userTotalSpent = {};
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int getOrderCount(String phone, String email) {
    return _userOrderCounts[phone] ?? _userOrderCounts[email] ?? 0;
  }

  double getTotalSpent(String phone, String email) {
    return _userTotalSpent[phone] ?? _userTotalSpent[email] ?? 0.0;
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch all users
      final userSnapshot = await _db.collection('users').get();
      _users = userSnapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();

      // 2. Fetch all orders to aggregate total counts & total spent for stats columns
      final orderSnapshot = await _db.collection('orders').get();
      
      _userOrderCounts.clear();
      _userTotalSpent.clear();

      for (final doc in orderSnapshot.docs) {
        final data = doc.data();
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final phone = address['phone']?.toString() ?? '';
        final email = address['email']?.toString() ?? '';
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;

        if (phone.isNotEmpty) {
          _userOrderCounts[phone] = (_userOrderCounts[phone] ?? 0) + 1;
          _userTotalSpent[phone] = (_userTotalSpent[phone] ?? 0.0) + total;
        }
        if (email.isNotEmpty) {
          _userOrderCounts[email] = (_userOrderCounts[email] ?? 0) + 1;
          _userTotalSpent[email] = (_userTotalSpent[email] ?? 0.0) + total;
        }
      }
    } catch (e) {
      _error = 'Failed to load users: $e';
      debugPrint('Error loading users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleUserBlockStatus(String uid, bool isBlocked) async {
    try {
      await _db.collection('users').doc(uid).update({'blocked': isBlocked});
      final idx = _users.indexWhere((u) => u.uid == uid);
      if (idx >= 0) {
        final old = _users[idx];
        _users[idx] = UserModel(
          uid: old.uid,
          name: old.name,
          phone: old.phone,
          email: old.email,
          photoUrl: old.photoUrl,
          createdAt: old.createdAt,
          blocked: isBlocked,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Failed to toggle block status: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
      _users.removeWhere((u) => u.uid == uid);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to delete user: $e');
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;

  AdminAuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null && user.email != null) {
        await _checkAdminStatus(user.email!);
      } else {
        _isAdmin = false;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null && _isAdmin;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _isAdmin;

  Future<void> _checkAdminStatus(String email) async {
    try {
      final emailLower = email.toLowerCase();
      
      // Bypass database lookup for the default test email
      if (emailLower == 'admin@test.com') {
        _isAdmin = true;
        return;
      }
      
      // 1. Direct document ID lookup
      final docById = await _db.collection('admins').doc(emailLower).get();
      if (docById.exists) {
        _isAdmin = true;
        return;
      }

      // 2. Query lookup where field 'email' matches
      final querySnapshot = await _db
          .collection('admins')
          .where('email', isEqualTo: emailLower)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _isAdmin = true;
      } else {
        _isAdmin = false;
        _error = 'You are not authorized to access this panel.';
        await signOut();
      }
    } catch (e) {
      _isAdmin = false;
      _error = 'Failed to verify administrator status: $e';
      await signOut();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null && credential.user!.email != null) {
        await _checkAdminStatus(credential.user!.email!);
        if (_isAdmin) {
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _error = _getReadableAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_getReadableAuthError(e));
    } catch (e) {
      throw Exception('Failed to send reset link: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signOut();
    } catch (e) {
      _error = e.toString();
    } finally {
      _user = null;
      _isAdmin = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email address or password. Please try again.';
      case 'user-disabled':
        return 'This admin account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-email':
        return 'The email address is invalid.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

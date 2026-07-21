import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminLogger {
  static Future<void> log({
    required String actionType,
    required String affectedDocId,
    required String details,
  }) async {
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? 'admin@turbocart.com';
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'adminEmail': email,
        'actionType': actionType,
        'details': details,
        'affectedDocId': affectedDocId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to write admin log: $e');
    }
  }
}

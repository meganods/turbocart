import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/banner_model.dart';

class BannersProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<BannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;

  List<BannerModel> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchBanners() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db.collection('banners').orderBy('order').get();
      _banners = snapshot.docs
          .map((doc) => BannerModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      _error = 'Failed to load banners: $e';
      debugPrint('Error loading banners: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> uploadBannerImage(Uint8List bytes, String filename) async {
    final ref = _storage.ref().child('banners/$filename');
    final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await uploadTask.ref.getDownloadURL();
  }

  Future<bool> saveBanner(BannerModel banner) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docData = banner.toMap();
      if (banner.id.isNotEmpty) {
        await _db.collection('banners').doc(banner.id).set(docData);
        final idx = _banners.indexWhere((b) => b.id == banner.id);
        if (idx >= 0) {
          _banners[idx] = banner;
        } else {
          _banners.add(banner);
        }
      } else {
        final docRef = await _db.collection('banners').add(docData);
        _banners.add(BannerModel.fromMap(docRef.id, docData));
      }
      _banners.sort((a, b) => a.order.compareTo(b.order));
      return true;
    } catch (e) {
      debugPrint('Save banner failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleBannerStatus(String id, bool activeState) async {
    try {
      await _db.collection('banners').doc(id).update({'active': activeState});
      final idx = _banners.indexWhere((b) => b.id == id);
      if (idx >= 0) {
        final old = _banners[idx];
        _banners[idx] = BannerModel(
          id: old.id,
          imageUrl: old.imageUrl,
          order: old.order,
          active: activeState,
          categoryId: old.categoryId,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Toggle banner failed: $e');
      return false;
    }
  }

  Future<bool> deleteBanner(String id) async {
    try {
      final idx = _banners.indexWhere((b) => b.id == id);
      if (idx >= 0) {
        final banner = _banners[idx];
        if (banner.imageUrl.contains('firebasestorage')) {
          try {
            await _storage.refFromURL(banner.imageUrl).delete();
          } catch (_) {}
        }
        await _db.collection('banners').doc(id).delete();
        _banners.removeAt(idx);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete banner failed: $e');
      return false;
    }
  }

  Future<void> updateBannersOrder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _banners.removeAt(oldIndex);
    _banners.insert(newIndex, item);
    notifyListeners();

    try {
      final batch = _db.batch();
      for (int i = 0; i < _banners.length; i++) {
        final banner = _banners[i];
        final docRef = _db.collection('banners').doc(banner.id);
        batch.update(docRef, {'order': i});
        
        _banners[i] = BannerModel(
          id: banner.id,
          imageUrl: banner.imageUrl,
          order: i,
          active: banner.active,
          categoryId: banner.categoryId,
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save reordered banners: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/category_model.dart';

class CategoriesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('categories')
          .get();

      _categories = snapshot.docs
          .map((doc) => Category.fromMap(doc.id, doc.data()))
          .toList();
          
      // Sort in memory to ensure documents missing the 'order' field are not excluded by Firestore query
      _categories.sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      _error = 'Failed to load categories: $e';
      debugPrint('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> uploadCategoryImage({
    required Uint8List bytes,
    required String pathPrefix,
    required String filename,
  }) async {
    final ref = _storage.ref().child('categories/$pathPrefix/$filename');
    final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await uploadTask.ref.getDownloadURL();
  }

  Future<bool> saveCategory({
    required Category category,
    bool isEditing = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docData = category.toMap();
      
      if (isEditing) {
        await _db.collection('categories').doc(category.id).update(docData);
        final idx = _categories.indexWhere((c) => c.id == category.id);
        if (idx >= 0) {
          _categories[idx] = Category.fromMap(category.id, docData);
        }
      } else {
        await _db.collection('categories').doc(category.id).set(docData);
        _categories.add(Category.fromMap(category.id, docData));
        _categories.sort((a, b) => a.order.compareTo(b.order));
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Save category failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        final category = _categories[idx];

        // Delete main icon
        if (category.icon.contains('firebasestorage')) {
          try {
            await _storage.refFromURL(category.icon).delete();
          } catch (_) {}
        }
        
        // Delete banner
        if (category.bannerImageUrl.contains('firebasestorage')) {
          try {
            await _storage.refFromURL(category.bannerImageUrl).delete();
          } catch (_) {}
        }

        // Delete subcategory icons
        for (final sub in category.subcategories) {
          if (sub.icon.contains('firebasestorage')) {
            try {
              await _storage.refFromURL(sub.icon).delete();
            } catch (_) {}
          }
        }

        await _db.collection('categories').doc(id).delete();
        _categories.removeAt(idx);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete category failed: $e');
      return false;
    }
  }

  Future<void> updateCategoryOrder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();

    // Trigger batch update to Firestore
    try {
      final batch = _db.batch();
      for (int i = 0; i < _categories.length; i++) {
        final category = _categories[i];
        final docRef = _db.collection('categories').doc(category.id);
        batch.update(docRef, {'order': i});
        
        // Update local memory representation
        _categories[i] = Category(
          id: category.id,
          name: category.name,
          icon: category.icon,
          order: i,
          color: category.color,
          headerBgColor: category.headerBgColor,
          bannerBgColor: category.bannerBgColor,
          bannerImageUrl: category.bannerImageUrl,
          searchHint: category.searchHint,
          sectionTitle: category.sectionTitle,
          sectionSubtitle: category.sectionSubtitle,
          subcategories: category.subcategories,
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save reordered categories: $e');
    }
  }
}

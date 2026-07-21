import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/product_model.dart';
import '../utils/admin_logger.dart';

class ProductsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Categories mapping: Category name -> List of subcategories
  Map<String, List<String>> _categoriesMap = {};

  final Map<String, List<String>> _defaultCategoriesMap = {
    'Vegetables & Fruits': ['Fresh Vegetables', 'Fresh Fruits', 'Herbs & Seasonings'],
    'Dairy & Breakfast': ['Milk', 'Butter & Ghee', 'Cheese', 'Eggs', 'Paneer & Curd'],
    'Munchies': ['Chips & Crisps', 'Nachos', 'Puffs', 'Popcorn'],
    'Cold Drinks & Juices': ['Soft Drinks', 'Fruit Juices', 'Energy Drinks', 'Soda & Water'],
    'Instant & Frozen Food': ['Noodles & Pasta', 'Frozen Snacks', 'Ready to Eat'],
    'Bakery & Biscuits': ['Bread & Pav', 'Cookies', 'Cake & Rusk'],
  };

  // Getters
  List<Product> get products => _products;
  List<String> get categories => ['All', ..._categoriesMap.keys];
  List<String> get formCategories => _categoriesMap.keys.toList();
  Map<String, List<String>> get categoriesMap => _categoriesMap;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> fetchCategoriesAndSubcategories() async {
    try {
      final snapshot = await _db.collection('categories').get();
      if (snapshot.docs.isNotEmpty) {
        final tempMap = <String, List<String>>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = data['name'] as String? ?? doc.id;
          final subs = List<String>.from(data['subcategories'] ?? []);
          tempMap[name] = subs;
        }
        _categoriesMap = tempMap;
      } else {
        _categoriesMap = Map<String, List<String>>.from(_defaultCategoriesMap);
      }
    } catch (e) {
      debugPrint('Failed to load categories collection, using defaults: $e');
      _categoriesMap = Map<String, List<String>>.from(_defaultCategoriesMap);
    }
    notifyListeners();
  }

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch categories map first
      await fetchCategoriesAndSubcategories();

      final snapshot = await _db.collection('products').get();
      _products = snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      _error = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UploadTask> uploadProductImageTask({
    required Uint8List bytes,
    required String category,
    required String subcategory,
    required String filename,
  }) async {
    final cleanCategory = category.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final cleanSubcategory = subcategory.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final ref = _storage.ref().child('products/$cleanCategory/$cleanSubcategory/$filename');
    return ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
  }

  Future<bool> saveProduct({
    required Product product,
    required List<String> imageUrls,
    bool isEditing = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docData = product.toMap();
      // Inject updated image list
      docData['images'] = imageUrls;
      docData['image'] = imageUrls.isNotEmpty ? imageUrls.first : '';

      // Build categoryTags array automatically (combining category with 'all')
      final List<String> categoryTags = ['all', product.category.toLowerCase()];
      docData['categoryTags'] = categoryTags;

      if (isEditing) {
        await _db.collection('products').doc(product.id).update(docData);
        final idx = _products.indexWhere((p) => p.id == product.id);
        if (idx >= 0) {
          _products[idx] = Product.fromMap(product.id, docData);
        }
        await AdminLogger.log(
          actionType: 'EDIT_PRODUCT',
          affectedDocId: product.id,
          details: 'Product details updated for: ${product.name}',
        );
      } else {
        final docRef = await _db.collection('products').add(docData);
        final newProduct = Product.fromMap(docRef.id, docData);
        _products.insert(0, newProduct);
        await AdminLogger.log(
          actionType: 'ADD_PRODUCT',
          affectedDocId: docRef.id,
          details: 'New product created: ${product.name}',
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Save product failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleProductStatus(String id, bool currentStatus) async {
    try {
      final newStatus = !currentStatus;
      await _db.collection('products').doc(id).update({'isActive': newStatus});

      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        final p = _products[idx];
        _products[idx] = Product(
          id: p.id,
          name: p.name,
          nameHindi: p.nameHindi,
          brand: p.brand,
          category: p.category,
          subcategory: p.subcategory,
          description: p.description,
          images: p.images,
          tags: p.tags,
          price: p.price,
          mrp: p.mrp,
          rating: p.rating,
          discount: p.discount,
          stock: p.stock,
          reviewCount: p.reviewCount,
          isDeal: p.isDeal,
          isBestSeller: p.isBestSeller,
          weight: p.weight,
          unit: p.unit,
          isActive: newStatus,
          searchKeywords: p.searchKeywords,
          searchKeywordsHindi: p.searchKeywordsHindi,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Failed to toggle status: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        final product = _products[idx];

        // Delete images from Firebase Storage
        for (final imageUrl in product.images) {
          if (imageUrl.contains('firebasestorage')) {
            try {
              final ref = _storage.refFromURL(imageUrl);
              await ref.delete();
            } catch (storageError) {
              debugPrint('Failed to delete image from storage: $storageError');
            }
          }
        }

        // Delete Firestore document
        await _db.collection('products').doc(id).delete();
        _products.removeAt(idx);
        await AdminLogger.log(
          actionType: 'DELETE_PRODUCT',
          affectedDocId: id,
          details: 'Product deleted: ${product.name}',
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete product failed: $e');
      return false;
    }
  }

  Future<bool> bulkDelete(List<String> ids) async {
    try {
      final batch = _db.batch();

      for (final id in ids) {
        final docRef = _db.collection('products').doc(id);
        batch.delete(docRef);

        final idx = _products.indexWhere((p) => p.id == id);
        if (idx >= 0) {
          final product = _products[idx];
          for (final imageUrl in product.images) {
            if (imageUrl.contains('firebasestorage')) {
              try {
                final ref = _storage.refFromURL(imageUrl);
                await ref.delete();
              } catch (_) {}
            }
          }
        }
      }

      await batch.commit();

      _products.removeWhere((p) => ids.contains(p.id));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Bulk delete failed: $e');
      return false;
    }
  }

  Future<bool> bulkSetStatus(List<String> ids, bool isActive) async {
    try {
      final batch = _db.batch();

      for (final id in ids) {
        final docRef = _db.collection('products').doc(id);
        batch.update(docRef, {'isActive': isActive});
      }

      await batch.commit();

      for (final id in ids) {
        final idx = _products.indexWhere((p) => p.id == id);
        if (idx >= 0) {
          final p = _products[idx];
          _products[idx] = Product(
            id: p.id,
            name: p.name,
            nameHindi: p.nameHindi,
            brand: p.brand,
            category: p.category,
            subcategory: p.subcategory,
            description: p.description,
            images: p.images,
            tags: p.tags,
            price: p.price,
            mrp: p.mrp,
            rating: p.rating,
            discount: p.discount,
            stock: p.stock,
            reviewCount: p.reviewCount,
            isDeal: p.isDeal,
            isBestSeller: p.isBestSeller,
            weight: p.weight,
            unit: p.unit,
            isActive: isActive,
            searchKeywords: p.searchKeywords,
            searchKeywordsHindi: p.searchKeywordsHindi,
          );
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Bulk set status failed: $e');
      return false;
    }
  }
}

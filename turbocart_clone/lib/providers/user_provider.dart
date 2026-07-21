import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserAddress {
  final String id;
  final String title; // Home, Office, Other
  final String addressLine;
  final double latitude;
  final double longitude;

  UserAddress({
    required this.id,
    required this.title,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
  });
}

class UserProvider with ChangeNotifier {
  UserModel? _user;
  List<UserAddress> _addresses = [];
  UserAddress? _selectedAddress;

  UserModel? get user => _user;
  String? get phoneNumber => _user?.phone;
  String? get name => _user?.name;
  String? get email => _user?.email;
  String? get photoUrl => _user?.photoUrl;
  List<UserAddress> get addresses => [..._addresses];
  UserAddress? get selectedAddress => _selectedAddress;

  String _currentAddressLabel = 'HOME';
  String _currentAddressText = '';
  double _currentLat = 0.0;
  double _currentLng = 0.0;
  String _deliveryTime = '10 minutes';

  UserProvider() {
    _listenToSettings();
  }

  void _listenToSettings() {
    FirebaseFirestore.instance.collection('settings').doc('store').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          _deliveryTime = data['deliveryTime']?.toString() ?? '10 minutes';
          notifyListeners();
        }
      }
    });
  }

  String get addressLabel => _currentAddressLabel;
  String get addressText => _currentAddressText;
  String get deliveryTime => _deliveryTime;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;

  Future<void> setCurrentAddress({
    required String label,
    required String addressText,
    required double lat,
    required double lng,
  }) async {
    _currentAddressLabel = label;
    _currentAddressText = addressText;
    _currentLat = lat;
    _currentLng = lng;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('addressLabel', label);
    await prefs.setString('addressText', addressText);
    notifyListeners();
  }

  Future<void> loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    _currentAddressLabel = prefs.getString('addressLabel') ?? 'HOME';
    _currentAddressText = prefs.getString('addressText') ?? 'Set your delivery location';
    notifyListeners();
  }

  bool get isLoggedIn => _user != null;

  Future<void> fetchUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromMap(uid, doc.data()!);
        
        // Fetch addresses
        final addressesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .get();
            
        _addresses = addressesSnapshot.docs.map((doc) {
          final data = doc.data();
          return UserAddress(
            id: doc.id,
            title: data['label'] ?? 'Home',
            addressLine: '${data['flat']}, ${data['area']}',
            latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        if (_addresses.isNotEmpty) {
          _selectedAddress = _addresses.first;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch user failed: $e');
    }
  }

  Future<void> updateUser({required String name, required String email, String? photoUrl}) async {
    if (_user == null) return;
    try {
      final Map<String, dynamic> updatedData = {
        'name': name,
        'email': email,
      };
      if (photoUrl != null) {
        updatedData['photoUrl'] = photoUrl;
      }

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update(updatedData);
      
      _user = UserModel(
        uid: _user!.uid,
        name: name,
        phone: _user!.phone,
        email: email,
        photoUrl: photoUrl ?? _user!.photoUrl,
        createdAt: _user!.createdAt,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Update user failed: $e');
    }
  }

  void setUser(String phone, {String? uid, String? name, String? email, String? photoUrl}) {
    _user = UserModel(
      uid: uid ?? 'temp_uid_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Guest User',
      phone: phone,
      email: email ?? '',
      photoUrl: photoUrl ?? '',
      createdAt: Timestamp.now(),
    );
    notifyListeners();
  }

  void updateProfile({required String name, required String email, String? photoUrl}) {
    if (_user != null) {
      _user = UserModel(
        uid: _user!.uid,
        name: name,
        phone: _user!.phone,
        email: email,
        photoUrl: photoUrl ?? _user!.photoUrl,
        createdAt: _user!.createdAt,
      );
      notifyListeners();
    }
  }

  void setPhotoUrl(String url) {
    if (_user != null) {
      _user = UserModel(
        uid: _user!.uid,
        name: _user!.name,
        phone: _user!.phone,
        email: _user!.email,
        photoUrl: url,
        createdAt: _user!.createdAt,
      );
      notifyListeners();
    }
  }

  void addAddress(UserAddress address) {
    _addresses.add(address);
    _selectedAddress ??= address;
    notifyListeners();
  }

  void selectAddress(UserAddress address) {
    _selectedAddress = address;
    _currentAddressLabel = address.title.toUpperCase();
    _currentAddressText = address.addressLine;
    _currentLat = address.latitude;
    _currentLng = address.longitude;
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('addressLabel', _currentAddressLabel);
      prefs.setString('addressText', _currentAddressText);
      prefs.setDouble('lat', _currentLat);
      prefs.setDouble('lng', _currentLng);
    });
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _addresses = [];
    _selectedAddress = null;
    notifyListeners();
  }

  void logout() {
    clearUser();
  }
}

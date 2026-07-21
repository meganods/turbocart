// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/user_provider.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class AddressScreen extends StatefulWidget {
  final bool isFromCheckout;
  const AddressScreen({super.key, this.isFromCheckout = false});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  bool _showAddNew = false;
  String? _selectedAddressId;

  // Map & Location fields
  final MapController _mapController = MapController();
  latlng.LatLng _mapCenter = const latlng.LatLng(28.6139, 77.2090); // Default: New Delhi
  String _currentAddressText = 'Fetching address...';
  bool _isFetchingLocation = false;

  // Form fields
  final _formKey = GlobalKey<FormState>();
  final _flatController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  String _addressLabel = 'Home'; // Home, Work, Other

  // Edit fields
  String? _editingAddressId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _flatController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _getUid() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'mock_uid_123';
  }

  // Get current location & geocode
  Future<void> _useCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final latLng = latlng.LatLng(position.latitude, position.longitude);
        _mapCenter = latLng;
        _mapController.move(latLng, 15.0);
        await _performReverseGeocode(latLng);
      } else {
        if (!mounted) return;
        SnackBarUtils.showTopSnackBar(context, 'Location permissions are denied.', backgroundColor: Colors.redAccent);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!mounted) return;
      SnackBarUtils.showTopSnackBar(context, 'Could not fetch location: $e', backgroundColor: Colors.redAccent);
    } finally {
      setState(() {
        _isFetchingLocation = false;
      });
    }
  }

  // Reverse geocode latlng to address string
  Future<void> _performReverseGeocode(latlng.LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final street = pm.name ?? pm.street ?? '';
        final subLoc = pm.subLocality ?? pm.locality ?? '';
        final city = pm.locality ?? pm.subAdministrativeArea ?? '';
        final fullAddress = [street, subLoc, city].where((e) => e.isNotEmpty).join(', ');
        
        setState(() {
          _currentAddressText = fullAddress;
          _areaController.text = fullAddress;
        });
      } else {
        setState(() {
          _currentAddressText = 'Lat: ${latLng.latitude}, Lng: ${latLng.longitude}';
          _areaController.text = _currentAddressText;
        });
      }
    } catch (e) {
      setState(() {
        _currentAddressText = 'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
        _areaController.text = _currentAddressText;
      });
    }
  }

  // Save to Firestore users/{uid}/addresses
  Future<void> _saveAddressToFirestore(UserProvider userProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _getUid();
    final addressData = {
      'flat': _flatController.text.trim(),
      'area': _areaController.text.trim(),
      'landmark': _landmarkController.text.trim(),
      'label': _addressLabel,
      'latitude': _mapCenter.latitude,
      'longitude': _mapCenter.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_editingAddressId != null) {
        // Edit existing address
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .doc(_editingAddressId)
            .update(addressData);
            
        if (!mounted) return;
        SnackBarUtils.showTopSnackBar(context, 'Address Updated Successfully!', backgroundColor: TurbocartColors.primary);
      } else {
        // Create new address
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .add(addressData);

        if (!mounted) return;
        // Also update selection
        _selectedAddressId = docRef.id;
        
        SnackBarUtils.showTopSnackBar(context, 'Address Saved Successfully!', backgroundColor: TurbocartColors.primary);
      }

      // Sync UserAddress to provider
      final savedAddress = UserAddress(
        id: _editingAddressId ?? _selectedAddressId ?? 'temp_id',
        title: _addressLabel,
        addressLine: '${_flatController.text.trim()}, ${_areaController.text.trim()}',
        latitude: _mapCenter.latitude,
        longitude: _mapCenter.longitude,
      );
      userProvider.addAddress(savedAddress);
      userProvider.selectAddress(savedAddress);

      // Reset & switch back
      _resetForm();
      setState(() {
        _showAddNew = false;
      });
    } catch (e) {
      debugPrint('Firestore save failed, saving locally: $e');
      
      if (!mounted) return;
      // Local Sync when offline/no firebase
      final localId = _editingAddressId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final localAddress = UserAddress(
        id: localId,
        title: _addressLabel,
        addressLine: '${_flatController.text.trim()}, ${_areaController.text.trim()}',
        latitude: _mapCenter.latitude,
        longitude: _mapCenter.longitude,
      );
      userProvider.addAddress(localAddress);
      userProvider.selectAddress(localAddress);
      _selectedAddressId = localId;

      _resetForm();
      setState(() {
        _showAddNew = false;
      });
      
      SnackBarUtils.showTopSnackBar(context, 'Saved locally (Offline mode)', backgroundColor: TurbocartColors.primary);
    }
  }

  void _resetForm() {
    _flatController.clear();
    _areaController.clear();
    _landmarkController.clear();
    _addressLabel = 'Home';
    _editingAddressId = null;
  }

  void _startEditing(Map<String, dynamic> data, String docId) {
    setState(() {
      _editingAddressId = docId;
      _flatController.text = data['flat'] ?? '';
      _areaController.text = data['area'] ?? '';
      _landmarkController.text = data['landmark'] ?? '';
      _addressLabel = data['label'] ?? 'Home';
      _mapCenter = latlng.LatLng(data['latitude'] ?? 28.6139, data['longitude'] ?? 77.2090);
      _currentAddressText = _areaController.text;
      _showAddNew = true;
    });
  }

  Future<void> _deleteAddress(String docId, UserProvider userProvider) async {
    final uid = _getUid();
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .doc(docId)
          .delete();
      
      if (!mounted) return;
      SnackBarUtils.showTopSnackBar(
        context,
        'Address deleted',
        backgroundColor: Colors.redAccent,
      );
    } catch (e) {
      debugPrint('Firestore delete failed: $e');
    }
  }

  IconData _getIconForLabel(String label) {
    if (label == 'Home') return Icons.home_rounded;
    if (label == 'Work') return Icons.work_rounded;
    return Icons.location_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TurbocartColors.textDark),
          onPressed: () {
            if (_showAddNew) {
              setState(() {
                _showAddNew = false;
                _resetForm();
              });
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _showAddNew ? (_editingAddressId != null ? 'Edit Address' : 'Add New Address') : 'Select Delivery Address',
          style: const TextStyle(color: TurbocartColors.textDark, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showAddNew ? _buildAddNewAddressView(userProvider) : _buildAddressListView(userProvider),
      ),
    );
  }

  // 1. Address List View
  Widget _buildAddressListView(UserProvider userProvider) {
    final uid = _getUid();

    return Column(
      key: const ValueKey('AddressListView'),
      children: [
        // Add new address button at top
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showAddNew = true;
                  _useCurrentLocation(); // pre-fill location
                });
              },
              icon: const Icon(Icons.add, color: TurbocartColors.primary),
              label: const Text(
                'Add New Address',
                style: TextStyle(color: TurbocartColors.primary, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: TurbocartColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('addresses')
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildMockAddressList(userProvider);
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TurbocartColors.primary));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                // If firestore stream returns empty or offline, check provider addresses
                if (userProvider.addresses.isNotEmpty) {
                  return _buildMockAddressList(userProvider);
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 64, color: TurbocartColors.lightGrey),
                      const SizedBox(height: 12),
                      const Text(
                        'No saved addresses',
                        style: TextStyle(fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add address to continue checkout',
                        style: TextStyle(color: TurbocartColors.textGrey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final docId = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  final label = data['label'] ?? 'Home';
                  final flat = data['flat'] ?? '';
                  final area = data['area'] ?? '';
                  final landmark = data['landmark'] ?? '';

                  final isSelected = _selectedAddressId == docId;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? TurbocartColors.primary : TurbocartColors.lightGrey,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: docId,
                      groupValue: _selectedAddressId,
                      activeColor: TurbocartColors.primary,
                      title: Row(
                        children: [
                          Icon(_getIconForLabel(label), color: TurbocartColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          '$flat, $area${landmark.isNotEmpty ? "\nLandmark: $landmark" : ""}',
                          style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 12, height: 1.4),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _selectedAddressId = val;
                        });
                        // update provider selectAddress
                        final selectedAdd = UserAddress(
                          id: docId,
                          title: label,
                          addressLine: '$flat, $area',
                          latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
                          longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
                        );
                        userProvider.selectAddress(selectedAdd);
                      },
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: TurbocartColors.primary, size: 20),
                            onPressed: () => _startEditing(data, docId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteAddress(docId, userProvider),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Delivery pulse chip + button
        _buildBottomPanel(userProvider),
      ],
    );
  }

  // Fallback offline mock address list
  Widget _buildMockAddressList(UserProvider userProvider) {
    final list = userProvider.addresses;
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isSelected = _selectedAddressId == item.id;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? TurbocartColors.primary : TurbocartColors.lightGrey,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: RadioListTile<String>(
            value: item.id,
            groupValue: _selectedAddressId,
            activeColor: TurbocartColors.primary,
            title: Row(
              children: [
                Icon(_getIconForLabel(item.title), color: TurbocartColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                item.addressLine,
                style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 12),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedAddressId = val;
              });
              userProvider.selectAddress(item);
            },
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: TurbocartColors.primary, size: 20),
                  onPressed: () {
                    // edit fallback
                    final parts = item.addressLine.split(', ');
                    final flat = parts.first;
                    final area = parts.sublist(1).join(', ');
                    _startEditing({
                      'flat': flat,
                      'area': area,
                      'label': item.title,
                      'latitude': item.latitude,
                      'longitude': item.longitude,
                    }, item.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    // mock delete
                    userProvider.logout(); // simple mock reset
                    SnackBarUtils.showTopSnackBar(
                      context,
                      'Address deleted locally',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(UserProvider userProvider) {
    final bool hasSelection = _selectedAddressId != null || userProvider.selectedAddress != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Deliver Here button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: hasSelection
                    ? () {
                        if (widget.isFromCheckout) {
                          context.push('/payment');
                        } else {
                          context.pop();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TurbocartColors.primary,
                  disabledBackgroundColor: TurbocartColors.lightGrey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm Address',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Add / Edit Address View
  Widget _buildAddNewAddressView(UserProvider userProvider) {
    return SingleChildScrollView(
      key: const ValueKey('AddNewAddressView'),
      padding: const EdgeInsets.only(bottom: 50.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Google Map widget area
          Stack(
            children: [
              SizedBox(
                height: 220,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 15.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _mapCenter = latlng.LatLng(camera.center.latitude, camera.center.longitude);
                        _performReverseGeocode(_mapCenter);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.turbocart_clone',
                      maxZoom: 19,
                    ),
                  ],
                ),
              ),
              // Center Marker pin indicator
              const Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 35.0),
                    child: Icon(Icons.location_pin, color: Colors.redAccent, size: 40),
                  ),
                ),
              ),
              // Current Address Overlay
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_searching_rounded, color: TurbocartColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentAddressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use current location button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton.icon(
                      onPressed: _isFetchingLocation ? null : _useCurrentLocation,
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: TurbocartColors.primary, strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, color: TurbocartColors.primary, size: 18),
                      label: const Text(
                        'Use current location',
                        style: TextStyle(color: TurbocartColors.primary, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Flat No field
                  TextFormField(
                    controller: _flatController,
                    decoration: InputDecoration(
                      labelText: 'Flat / House / Office No.',
                      labelStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'House no is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Area / Street (pre-filled)
                  TextFormField(
                    controller: _areaController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Area / Street / Locality',
                      labelStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Area details are required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Landmark
                  TextFormField(
                    controller: _landmarkController,
                    decoration: InputDecoration(
                      labelText: 'Landmark (Optional)',
                      labelStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Label Selector (Home / Work / Other)
                  const Text(
                    'Save Address As:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TurbocartColors.textDark),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((label) {
                      final isSelected = _addressLabel == label;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          avatar: Icon(
                            _getIconForLabel(label),
                            color: isSelected ? Colors.white : TurbocartColors.primary,
                            size: 16,
                          ),
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: TurbocartColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : TurbocartColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _addressLabel = label;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Save Address Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _saveAddressToFirestore(userProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TurbocartColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        _editingAddressId != null ? 'Update Address' : 'Save Address',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

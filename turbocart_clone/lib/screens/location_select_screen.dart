import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../providers/user_provider.dart';

class LocationSelectScreen extends StatefulWidget {
  const LocationSelectScreen({super.key});

  @override
  State<LocationSelectScreen> createState() => _LocationSelectScreenState();
}


class _LocationSelectScreenState extends State<LocationSelectScreen> {
  final MapController _mapController = MapController();
  latlng.LatLng _selectedLatLng = const latlng.LatLng(28.6139, 77.2090); // Default: New Delhi
  String _addressLine = 'Loading address...';
  bool _isLoadingLocation = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLatLng = latlng.LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController.move(_selectedLatLng, 16.0);

      _reverseGeocode();
    } catch (e) {
      debugPrint('Geolocator failed: $e. Falling back to default New Delhi location.');
      setState(() {
        _isLoadingLocation = false;
      });
      _reverseGeocode();
    }
  }

  Future<void> _reverseGeocode() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        _selectedLatLng.latitude,
        _selectedLatLng.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        setState(() {
          _addressLine = '${pm.name ?? pm.street ?? ""}, ${pm.subLocality ?? pm.locality ?? ""}, ${pm.postalCode ?? ""}';
        });
      } else {
        setState(() {
          _addressLine = 'Lat: ${_selectedLatLng.latitude.toStringAsFixed(4)}, Lng: ${_selectedLatLng.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      debugPrint('Geocoding failed: $e. Using coordinates fallback.');
      setState(() {
        _addressLine = 'Lat: ${_selectedLatLng.latitude.toStringAsFixed(4)}, Lng: ${_selectedLatLng.longitude.toStringAsFixed(4)}';
      });
    }
  }

  void _saveLocation() async {
    setState(() {
      _isSaving = true;
    });

    final address = UserAddress(
      id: DateTime.now().toString(),
      title: 'Current Location',
      addressLine: _addressLine,
      latitude: _selectedLatLng.latitude,
      longitude: _selectedLatLng.longitude,
    );

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.addAddress(address);

    setState(() {
      _isSaving = false;
    });

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: TurbocartColors.textDark,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map Widget
          _isLoadingLocation
              ? const Center(child: CircularProgressIndicator(color: TurbocartColors.primary))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLatLng,
                    initialZoom: 16.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _selectedLatLng = latlng.LatLng(camera.center.latitude, camera.center.longitude);
                        _reverseGeocode();
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

          // Custom Marker in center (pin overlay)
          if (!_isLoadingLocation)
            const Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(bottom: 35.0), // align pin tip to center
                child: Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 48,
                ),
              ),
            ),

          // Address Display & Save Button Bottom Card
          if (!_isLoadingLocation)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_pin, color: TurbocartColors.primary, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: TurbocartColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _addressLine,
                      style: const TextStyle(
                        fontSize: 13,
                        color: TurbocartColors.textGrey,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TurbocartColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Confirm Location',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
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

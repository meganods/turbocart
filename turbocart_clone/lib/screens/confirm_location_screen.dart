import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../utils/snackbar_utils.dart';

class ConfirmLocationScreen extends StatefulWidget {
  final Map<String, dynamic> extra;
  const ConfirmLocationScreen({super.key, required this.extra});

  @override
  State<ConfirmLocationScreen> createState() => _ConfirmLocationScreenState();
}

class _ConfirmLocationScreenState extends State<ConfirmLocationScreen> {
  late double _lat;
  late double _lng;
  late String _addressText;

  final MapController _mapController = MapController();
  String _selectedLabel = 'HOME';
  bool _isSaving = false;
  bool _isReverseGeocoding = false;
  bool _isLocatingLive = false;

  Timer? _geocodeDebounce;
  StreamSubscription<Position>? _locationStream;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _lat = (widget.extra['lat'] as num).toDouble();
    _lng = (widget.extra['lng'] as num).toDouble();
    _addressText = widget.extra['addressText'] as String? ?? '';
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _locationStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Map moved (camera idle equivalent) ────────────────────────────────────

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    final newLat = camera.center.latitude;
    final newLng = camera.center.longitude;
    setState(() {
      _lat = newLat;
      _lng = newLng;
    });
    // Debounce reverse geocode — only fires after user stops dragging
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(newLat, newLng);
    });
  }

  // ── Live GPS tracking ──────────────────────────────────────────────────────

  Future<void> _startLiveLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted && permission == LocationPermission.deniedForever) {
        _showPermDeniedDialog();
      }
      return;
    }

    setState(() => _isLocatingLive = true);

    // Move map to current position once
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
        _mapController.move(
            latlng.LatLng(_lat, _lng), _mapController.camera.zoom);
        _reverseGeocode(_lat, _lng);
      }
    } catch (_) {}

    // Then subscribe to stream for continuous live updates
    _locationStream?.cancel();
    _locationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10m
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _mapController.move(
          latlng.LatLng(_lat, _lng), _mapController.camera.zoom);
    });

    if (mounted) setState(() => _isLocatingLive = false);
  }

  void _stopLiveLocation() {
    _locationStream?.cancel();
    _locationStream = null;
    setState(() => _isLocatingLive = false);
  }

  // ── Reverse geocoding ──────────────────────────────────────────────────────

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isReverseGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.name,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        setState(() => _addressText = parts);
      }
    } catch (_) {
      // keep existing text on error
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  void _showPermDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Permission Denied'),
        content: const Text(
            'Please enable location access from Settings to use GPS.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F)),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Save & Confirm ─────────────────────────────────────────────────────────

  Future<void> _confirmLocation() async {
    _stopLiveLocation();
    setState(() => _isSaving = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final uid = userProvider.user?.uid;

    try {
      // 1. Save to Firestore
      if (uid != null && !uid.startsWith('temp_uid_')) {
        final addressesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses');

        final existing = await addressesRef.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in existing.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }
        await batch.commit();

        await addressesRef.add({
          'label': _selectedLabel,
          'area': _addressText,
          'flat': '',
          'landmark': '',
          'lat': _lat,
          'lng': _lng,
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Update UserProvider
      await userProvider.setCurrentAddress(
        label: _selectedLabel,
        addressText: _addressText,
        lat: _lat,
        lng: _lng,
      );

      // 3. Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('addressLabel', _selectedLabel);
      await prefs.setString('addressText', _addressText);
      await prefs.setDouble('lat', _lat);
      await prefs.setDouble('lng', _lng);

      // 4. Add to recent searches
      final recent = prefs.getStringList('recent_location_searches') ?? [];
      recent.remove(_addressText);
      recent.insert(0, _addressText);
      if (recent.length > 5) recent.removeLast();
      await prefs.setStringList('recent_location_searches', recent);

      // 5. Show success and navigate to the return destination
      if (mounted) {
        final returnTo = widget.extra['returnTo'] as String? ?? '/home';
        SnackBarUtils.showTopSnackBar(
          context,
          'Address saved successfully!',
          backgroundColor: const Color(0xFF0C831F),
        );
        // Small delay so the snackbar is visible before navigating
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go(returnTo);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showTopSnackBar(
          context,
          'Failed to save location: $e',
          backgroundColor: Colors.red,
        );
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen Flutter Map (OpenStreetMap, no API key) ────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latlng.LatLng(_lat, _lng),
              initialZoom: 16,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              // OpenStreetMap tile layer — free, no API key
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.turbocart_clone',
                maxZoom: 19,
              ),

              // Accuracy circle around pin
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: latlng.LatLng(_lat, _lng),
                    radius: 60,
                    color: const Color(0xFF0C831F).withValues(alpha: 0.08),
                    borderColor: const Color(0xFF0C831F).withValues(alpha: 0.3),
                    borderStrokeWidth: 1.5,
                    useRadiusInMeter: true,
                  ),
                ],
              ),

              // Attribution (required by OSM)
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Center pin (draggable via map) ─────────────────────────────────
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shadow ellipse
                  Container(
                    width: 24,
                    height: 8,
                    margin: const EdgeInsets.only(top: 52),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  color: const Color(0xFF0C831F),
                  size: 52,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Top buttons ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Back button
                  _mapIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.maybePop(context),
                  ),

                  const Spacer(),

                  // Live location toggle
                  _mapIconButton(
                    icon: _locationStream != null
                        ? Icons.gps_fixed
                        : Icons.my_location,
                    color: _locationStream != null
                        ? const Color(0xFF0C831F)
                        : Colors.black,
                    onTap: _isLocatingLive
                        ? null
                        : () {
                            if (_locationStream != null) {
                              _stopLiveLocation();
                            } else {
                              _startLiveLocation();
                            }
                          },
                    child: _isLocatingLive
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Color(0xFF0C831F), strokeWidth: 2),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom sheet ───────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _mapIconButton({
    required IconData icon,
    VoidCallback? onTap,
    Color color = Colors.black,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child ??
            Icon(icon, color: onTap == null ? Colors.grey : color, size: 22),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Drag hint
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_with, size: 14, color: Color(0xFF0C831F)),
                  SizedBox(width: 4),
                  Text('Drag the map to adjust pin',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0C831F),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Address row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on,
                  color: Color(0xFF0C831F), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery location',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    _isReverseGeocoding
                        ? Row(
                            children: [
                              const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0C831F)),
                              ),
                              const SizedBox(width: 8),
                              Text('Getting address...',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500)),
                            ],
                          )
                        : Text(
                            _addressText.isNotEmpty
                                ? _addressText
                                : 'Move map to set location',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                          ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Change',
                    style: TextStyle(color: Color(0xFF0C831F))),
              ),
            ],
          ),

          const Divider(height: 24),

          // Save as label
          const Text('Save as',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _labelChip('HOME', Icons.home_outlined),
              _labelChip('WORK', Icons.work_outline),
              _labelChip('OTHER', Icons.location_on_outlined),
            ],
          ),

          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isSaving ? null : _confirmLocation,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Confirm location',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelChip(String label, IconData icon) {
    final isSelected = _selectedLabel == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedLabel = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0C831F)
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected
                    ? const Color(0xFF0C831F)
                    : Colors.grey),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? const Color(0xFF0C831F)
                        : Colors.grey,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

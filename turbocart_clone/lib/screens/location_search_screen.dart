import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTANT: Replace with your own Google Maps / Places API key.
// Enable "Places API" and "Maps SDK for Android/iOS/Web" in the Cloud Console.
// ─────────────────────────────────────────────────────────────────────────────
const String _kGoogleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

class LocationSearchScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;
  const LocationSearchScreen({super.key, this.extra});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLocating = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _predictions = [];
  List<String> _recentSearches = [];
  Timer? _debounce;

  // GPS mode: pre-filled address when coming from GPS
  bool get _fromGPS => widget.extra?['fromGPS'] == true;
  double? get _gpsLat => (widget.extra?['lat'] as num?)?.toDouble();
  double? get _gpsLng => (widget.extra?['lng'] as num?)?.toDouble();

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    if (_fromGPS && _gpsLat != null && _gpsLng != null) {
      _reverseGeocodeAndFill(_gpsLat!, _gpsLng!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Recent searches ────────────────────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches =
          prefs.getStringList('recent_location_searches') ?? [];
    });
  }

  Future<void> _saveToRecentSearches(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_location_searches') ?? [];
    list.remove(address);
    list.insert(0, address);
    if (list.length > 5) list.removeLast();
    await prefs.setStringList('recent_location_searches', list);
    setState(() => _recentSearches = list);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_location_searches');
    setState(() => _recentSearches = []);
  }

  // ── GPS / Geocoding ────────────────────────────────────────────────────────

  Future<void> _reverseGeocodeAndFill(double lat, double lng) async {
    setState(() => _isLocating = true);
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        _searchCtrl.text = parts;
        _goToConfirm(
          lat: lat,
          lng: lng,
          addressText: parts,
        );
      }
    } catch (_) {
      // silently fall back to manual entry
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _triggerGPS() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _reverseGeocodeAndFill(pos.latitude, pos.longitude);
        return;
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermDeniedDialog();
        }
      }
    } catch (e) {
      debugPrint("Error triggering GPS: $e");
    }

    if (mounted) setState(() => _isLocating = false);
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

  // ── Places Autocomplete ────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.length < 3) {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPredictions(value);
    });
  }

  Future<void> _fetchPredictions(String input) async {
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(input)}'
          '&key=$_kGoogleApiKey'
          '&components=country:in'
          '&types=geocode');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions =
                List<Map<String, dynamic>>.from(data['predictions'] ?? []);
          });
        } else {
          // API key not configured or quota exceeded — show empty list gracefully
          setState(() => _predictions = []);
        }
      }
    } catch (_) {
      setState(() => _predictions = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _onPredictionTapped(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'] as String? ?? '';
    final mainText = (prediction['structured_formatting']
                ?['main_text'] as String?) ??
        (prediction['description'] as String? ?? '');

    // Use place details to get lat/lng
    try {
      final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry'
          '&key=$_kGoogleApiKey');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loc =
            data['result']?['geometry']?['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          await _saveToRecentSearches(mainText);
          _goToConfirm(lat: lat, lng: lng, addressText: mainText, placeId: placeId);
          return;
        }
      }
    } catch (_) {}

    // Fallback: geocode from text
    try {
      final locations = await locationFromAddress(mainText);
      if (locations.isNotEmpty) {
        await _saveToRecentSearches(mainText);
        _goToConfirm(
          lat: locations.first.latitude,
          lng: locations.first.longitude,
          addressText: mainText,
        );
      }
    } catch (_) {}
  }

  void _goToConfirm({
    required double lat,
    required double lng,
    required String addressText,
    String? placeId,
  }) {
    if (!mounted) return;
    context.push('/confirm-location', extra: {
      'lat': lat,
      'lng': lng,
      'addressText': addressText,
      'placeId': placeId ?? '',
      // Forward the returnTo so confirm screen knows where to go after save
      'returnTo': widget.extra?['returnTo'] ?? '/home',
    });
  }

  // ── Saved addresses from Firestore ─────────────────────────────────────────

  Stream<QuerySnapshot>? _savedAddressStream() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .orderBy('isDefault', descending: true)
        .snapshots();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showResults = _searchCtrl.text.length > 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Set delivery location',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Use current location card ──────────────────────────────────
          _buildCurrentLocationCard(),

          // ── OR divider ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),

          // ── Search field ───────────────────────────────────────────────
          _buildSearchField(),
          const SizedBox(height: 8),

          // ── Results / Recent / Saved ───────────────────────────────────
          Expanded(
            child: showResults
                ? _buildSearchResults()
                : _buildEmptyStateList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    return GestureDetector(
      onTap: _isLocating ? null : _triggerGPS,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
              child: const Icon(Icons.my_location,
                  color: Color(0xFF0C831F), size: 20),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use current location',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0C831F))),
                SizedBox(height: 2),
                Text('Using GPS',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Color(0xFF0C831F), strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _focusNode,
        autofocus: !_fromGPS,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search for area, street name...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _predictions = []);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0C831F)));
    }
    if (_predictions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No results found',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _predictions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = _predictions[i];
        final mainText =
            p['structured_formatting']?['main_text'] as String? ??
                p['description'] as String? ??
                '';
        final secondaryText =
            p['structured_formatting']?['secondary_text'] as String? ?? '';
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFF5F5F5)),
            child: const Icon(Icons.location_on_outlined,
                color: Colors.grey, size: 18),
          ),
          title: Text(mainText,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: secondaryText.isNotEmpty
              ? Text(secondaryText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: const Icon(Icons.north_west, size: 14, color: Colors.grey),
          onTap: () => _onPredictionTapped(p),
        );
      },
    );
  }

  Widget _buildEmptyStateList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('Recent Searches',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                const Spacer(),
                TextButton(
                  onPressed: _clearRecentSearches,
                  child: const Text('Clear all',
                      style: TextStyle(
                          color: Color(0xFF0C831F), fontSize: 12)),
                ),
              ],
            ),
          ),
          ..._recentSearches.map((addr) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading:
                    const Icon(Icons.history, color: Colors.grey, size: 20),
                title: Text(addr,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () async {
                  try {
                    final locs = await locationFromAddress(addr);
                    if (locs.isNotEmpty && mounted) {
                      _goToConfirm(
                        lat: locs.first.latitude,
                        lng: locs.first.longitude,
                        addressText: addr,
                      );
                    }
                  } catch (_) {}
                },
              )),
          const Divider(),
        ],

        // Saved Addresses from Firestore
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Saved Addresses',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600)),
        ),
        _buildSavedAddressSection(),

        // Add new address button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            onPressed: () => context.push('/address'),
            icon: const Icon(Icons.add, color: Color(0xFF0C831F)),
            label: const Text('Add new address',
                style: TextStyle(
                    color: Color(0xFF0C831F), fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedAddressSection() {
    final stream = _savedAddressStream();
    if (stream == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sign in to see saved addresses',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No saved addresses yet.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }
        return Column(
          children: snap.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final label = (d['label'] as String? ?? 'Other').toUpperCase();
            final full = d['area'] as String? ?? d['fullAddress'] as String? ?? '';
            final isDefault = d['isDefault'] == true;
            final lat = (d['lat'] as num?)?.toDouble() ?? 0.0;
            final lng = (d['lng'] as num?)?.toDouble() ?? 0.0;

            Color circleColor;
            Color iconColor;
            IconData icon;
            if (label == 'HOME') {
              circleColor = const Color(0xFFE8F5E9);
              iconColor = const Color(0xFF0C831F);
              icon = Icons.home_outlined;
            } else if (label == 'WORK') {
              circleColor = const Color(0xFFE3F2FD);
              iconColor = Colors.blue;
              icon = Icons.work_outline;
            } else {
              circleColor = const Color(0xFFFFF3E0);
              iconColor = Colors.orange;
              icon = Icons.location_on_outlined;
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: circleColor),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              title: Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (isDefault)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF0C831F)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Default',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF0C831F))),
                    ),
                ],
              ),
              subtitle: Text(full,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
              onTap: () {
                _saveToRecentSearches(full);
                _goToConfirm(lat: lat, lng: lng, addressText: full);
              },
            );
          }).toList(),
        );
      },
    );
  }
}

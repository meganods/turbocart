import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/user_provider.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class AddressRow extends StatelessWidget {
  const AddressRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return GestureDetector(
          onTap: () => _showLocationBottomSheet(context),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: TurbocartColors.primary, size: 16),
              const SizedBox(width: 4),
              Text(
                '${userProvider.addressLabel} - ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
              ),
              Expanded(
                child: Text(
                  userProvider.addressText.isNotEmpty ? userProvider.addressText : 'Set your delivery location',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
            ],
          ),
        );
      },
    );
  }

  void _showLocationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const LocationBottomSheetContent();
      },
    );
  }
}

class LocationBottomSheetContent extends StatefulWidget {
  const LocationBottomSheetContent({super.key});

  @override
  State<LocationBottomSheetContent> createState() => _LocationBottomSheetContentState();
}

class _LocationBottomSheetContentState extends State<LocationBottomSheetContent> {
  bool _isLoadingLocation = false;

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressString = [
            place.name,
            place.subLocality,
            place.locality,
            place.administrativeArea
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          if (mounted) {
            Provider.of<UserProvider>(context, listen: false).setCurrentAddress(
              label: 'CURRENT',
              addressText: addressString,
              lat: position.latitude,
              lng: position.longitude,
            );
            Navigator.pop(context);
          }
        }
      } else {
        if (mounted) {
          SnackBarUtils.showTopSnackBar(context, 'Location permission denied');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showTopSnackBar(context, 'Failed to get location: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Select delivery location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search for area, street name...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1, height: 1),
          
          // Current Location Option
          ListTile(
            leading: CircleAvatar(
              backgroundColor: TurbocartColors.primary.withValues(alpha: 0.1),
              child: _isLoadingLocation 
                ? const SizedBox(
                    width: 16, height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: TurbocartColors.primary)
                  )
                : const Icon(Icons.my_location, color: TurbocartColors.primary, size: 20),
            ),
            title: const Text('Use current location', style: TextStyle(color: TurbocartColors.primary, fontWeight: FontWeight.bold)),
            subtitle: const Text('Using GPS', style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _isLoadingLocation ? null : _fetchCurrentLocation,
          ),
          
          const Divider(thickness: 1, height: 1),
          
          // Saved Addresses Section
          if (userProvider.addresses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'SAVED ADDRESSES',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: userProvider.addresses.length,
                itemBuilder: (context, index) {
                  final address = userProvider.addresses[index];
                  IconData iconData = Icons.location_on;
                  if (address.title.toUpperCase() == 'HOME') iconData = Icons.home;
                  if (address.title.toUpperCase() == 'WORK') iconData = Icons.work;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(iconData, color: Colors.grey[700], size: 20),
                    ),
                    title: Text(address.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      address.addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      userProvider.setCurrentAddress(
                        label: address.title.toUpperCase(),
                        addressText: address.addressLine,
                        lat: address.latitude,
                        lng: address.longitude,
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ] else ...[
            const Spacer(),
          ]
        ],
      ),
    );
  }
}

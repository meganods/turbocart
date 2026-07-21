import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/delivery_auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<DeliveryAuthProvider>(context);
    final partner = authProvider.partner;
    const primaryGreen = Color(0xFF0C831F);

    if (partner == null) {
      return const Scaffold(
        body: Center(child: Text('Loading profile...')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: const Text(
          'My Profile',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar profile card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade100,
                      child: ClipOval(
                        child: partner.photoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: partner.photoUrl,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorWidget: (c, u, e) => const Icon(Icons.person, size: 48, color: Colors.grey),
                              )
                            : const Icon(Icons.person, size: 48, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      partner.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partner.phone,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_bike, size: 16, color: Color(0xFF4B5563)),
                          const SizedBox(width: 6),
                          Text(
                            partner.vehicleType,
                            style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Availability card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: partner.isOnline ? const Color(0xFFDCFCE7) : Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            partner.isOnline ? Icons.wifi : Icons.wifi_off,
                            color: partner.isOnline ? primaryGreen : Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Availability Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              partner.isOnline ? 'Online (Receiving Orders)' : 'Offline (Not Dispatching)',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: partner.isOnline,
                      activeColor: primaryGreen,
                      onChanged: (val) {
                        authProvider.toggleAvailability(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () => _handleLogout(context, authProvider),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, DeliveryAuthProvider provider) async {
    await provider.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

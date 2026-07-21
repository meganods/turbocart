import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../providers/order_provider.dart';
import 'home_storefront.dart';
import 'order_again/order_again_screen.dart';
import 'categories/categories_screen.dart';
import 'profile_screen.dart';
import '../utils/snackbar_utils.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  static bool _hasPromptedLocation = false;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Show popup immediately after first frame if not prompted yet and location is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      if (!HomeScreen._hasPromptedLocation && (user.addressText.trim().isEmpty)) {
        HomeScreen._hasPromptedLocation = true;
        _showLocationPermissionDialog();
      }
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _completeCheckoutOrder();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    SnackBarUtils.showTopSnackBar(
      context,
      'Payment Failed: ${response.message ?? "Unknown error"}',
      backgroundColor: Colors.red,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startRazorpayCheckout() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);
    
    final options = {
      'key': 'rzp_test_YourKeyHere',
      'amount': (cart.totalAmount * 100).toInt(),
      'name': 'Turbocart Clone',
      'description': 'Superfast delivery payment',
      'prefill': {
        'contact': user.phoneNumber ?? '9876543210',
        'email': user.email ?? 'customer@turbocart.com'
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _runPaymentSimulation();
    }
  }

  void _runPaymentSimulation() {
    SnackBarUtils.showTopSnackBar(
      context,
      'Simulation: Initiating Payment Gateway...',
      duration: const Duration(seconds: 1),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _completeCheckoutOrder();
    });
  }

  void _completeCheckoutOrder() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    Provider.of<OrderProvider>(context, listen: false).addOrder(cart.items.values.toList(), cart.totalAmount);
    cart.clearCart();
    SnackBarUtils.showTopSnackBar(
      context,
      'Order Placed Successfully! Delivered in 9 minutes.',
      backgroundColor: TurbocartColors.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeStorefront(onCheckout: _startRazorpayCheckout),
      const OrderAgainScreen(),
      const CategoriesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: TurbocartColors.primary.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: TurbocartColors.primary);
            }
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.grey);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            switch (index) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/order-again');
                break;
              case 2:
                context.go('/categories');
                break;
              case 3:
                context.go('/profile');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: TurbocartColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.replay_outlined),
              selectedIcon: Icon(Icons.replay, color: TurbocartColors.primary),
              label: 'Order Again',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view, color: TurbocartColors.primary),
              label: 'Categories',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: TurbocartColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog & Bottom Sheet methods ──────────────────────────────────────────

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom location off icon with red slash
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_outlined, color: Colors.grey[800], size: 40),
                    ),
                    Positioned(
                      child: Transform.rotate(
                        angle: -0.7,
                        child: Container(
                          width: 82,
                          height: 4,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Location permission not enabled',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please enable location permission for a better delivery experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _enableDeviceLocation();
                    },
                    child: const Text(
                      'Enable device location',
                      style: TextStyle(
                        color: TurbocartColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualLocationBottomSheet();
                    },
                    child: Text(
                      'Select location manually',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _enableDeviceLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        String addressText = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          addressText = [p.name, p.subLocality, p.locality].where((s) => s != null && s.isNotEmpty).join(', ');
        }
        
        if (!mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.setCurrentAddress(
          label: 'Current Location',
          addressText: addressText,
          lat: position.latitude,
          lng: position.longitude,
        );

        if (!mounted) return;
        SnackBarUtils.showTopSnackBar(
          context,
          'Location updated successfully!',
          backgroundColor: TurbocartColors.primary,
        );
      } else {
        if (!mounted) return;
        SnackBarUtils.showTopSnackBar(
          context,
          'Location permission denied.',
        );
      }
    } catch (e) {
      debugPrint("Error enabling location: $e");
    }
  }

  void _showManualLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating Close Button positioned on the upper side
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            // Bottom Sheet Content Container
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.only(bottom: 24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pink Warning Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_outlined, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device location not enabled',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                ),
                                Text(
                                  'Enable for a better delivery experience',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TurbocartColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _enableDeviceLocation();
                            },
                            child: const Text('Enable', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Select delivery location',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          readOnly: true,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/location-search', extra: {'returnTo': '/home'});
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search for area, street name...',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons list
                    _buildBottomSheetItem(
                      icon: Icons.my_location,
                      color: TurbocartColors.primary,
                      title: 'Use current location',
                      onTap: () {
                        Navigator.pop(context);
                        _enableDeviceLocation();
                      },
                    ),
                    _buildBottomSheetItem(
                      icon: Icons.add,
                      color: TurbocartColors.primary,
                      title: 'Add new address',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/address');
                      },
                    ),
                    _buildBottomSheetItem(
                      icon: Icons.share_location,
                      color: Colors.green,
                      title: 'Request address from someone else',
                      onTap: () {
                        SnackBarUtils.showTopSnackBar(
                          context,
                          'Sharing address request link via WhatsApp...',
                        );
                      },
                    ),
                    // _buildBottomSheetItem(
                    //   icon: Icons.restaurant,
                    //   color: Colors.redAccent,
                    //   title: 'Import your addresses from Zomato',
                    //   onTap: () {
                    //     SnackBarUtils.showTopSnackBar(
                    //       context,
                    //       'Importing saved Zomato addresses...',
                    //     );
                    //   },
                    // ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Your saved addresses',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Consumer list of saved addresses
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        final list = userProvider.addresses;
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No saved addresses yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          );
                        }
                        return Column(
                          children: list.map((addr) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFF5F5F5),
                                child: Icon(Icons.home_outlined, color: TurbocartColors.primary, size: 20),
                              ),
                              title: Text(
                                addr.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                addr.addressLine,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              onTap: () {
                                userProvider.selectAddress(addr);
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomSheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

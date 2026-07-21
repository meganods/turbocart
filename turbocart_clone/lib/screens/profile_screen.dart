import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isUploading = false;

  // ── Entrance Animations ──
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  late List<AnimationController> _statCtrl;
  late List<Animation<double>> _statScale;
  late List<Animation<double>> _statFade;

  late List<AnimationController> _menuCtrl;
  late List<Animation<Offset>> _menuSlide;
  late List<Animation<double>> _menuFade;

  late AnimationController _logoutCtrl;
  late Animation<double> _logoutFade;

  static const int _menuCount = 6;

  // ── Stats Future ──
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'mock_uid_123';
    _statsFuture = _fetchStats(uid);

    // Screen fade-in
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Stats cards — staggered scale + fade
    _statCtrl = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 350)));
    _statScale = _statCtrl.map((c) => Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: c, curve: Curves.easeOutBack))).toList();
    _statFade = _statCtrl.map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();

    // Menu items — staggered slide from right + fade
    _menuCtrl = List.generate(_menuCount, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 300)));
    _menuSlide = _menuCtrl.map((c) => Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic))).toList();
    _menuFade = _menuCtrl.map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();

    // Logout fade-in
    _logoutCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _logoutFade = CurvedAnimation(parent: _logoutCtrl, curve: Curves.easeIn);

    _startAnimations();
  }

  void _startAnimations() {
    _fadeCtrl.forward();

    // Stats stagger: 100ms, 200ms, 300ms
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 100 + i * 100), () {
        if (mounted) _statCtrl[i].forward();
      });
    }

    // Menu stagger: each 60ms, starting at 200ms
    for (var i = 0; i < _menuCount; i++) {
      Future.delayed(Duration(milliseconds: 200 + i * 60), () {
        if (mounted) _menuCtrl[i].forward();
      });
    }

    // Logout last
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _logoutCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in _statCtrl) { c.dispose(); }
    for (final c in _menuCtrl) { c.dispose(); }
    _logoutCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, int>> _fetchStats(String uid) async {
    try {
      final orders = await FirebaseFirestore.instance
          .collection('orders').where('userId', isEqualTo: uid).get();
      final addresses = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('addresses').get();
      final coupons = await FirebaseFirestore.instance
          .collection('coupons').where('active', isEqualTo: true).get();
      return {'orders': orders.docs.length, 'addresses': addresses.docs.length, 'coupons': coupons.docs.length};
    } catch (e) {
      return {'orders': 0, 'addresses': 0, 'coupons': 0};
    }
  }

  Future<void> _pickAndUploadImage(UserProvider userProvider) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      setState(() => _isUploading = true);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'mock_uid_123';
      final ref = FirebaseStorage.instance.ref().child('users/$uid/avatar.jpg');
      String url = '';
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(picked.path));
      }
      url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoUrl': url});
      userProvider.setPhotoUrl(url);
      if (mounted) {
        SnackBarUtils.showTopSnackBar(context, 'Profile photo updated!', backgroundColor: TurbocartColors.primary);
      }
    } catch (e) {
      debugPrint('Photo upload error: $e');
      const fallback = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
      userProvider.setPhotoUrl(fallback);
      if (mounted) {
        SnackBarUtils.showTopSnackBar(context, 'Photo updated locally', backgroundColor: TurbocartColors.primary);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: TurbocartColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final user = Provider.of<UserProvider>(context, listen: false);
      try { await FirebaseAuth.instance.signOut(); } catch (e) { debugPrint('signOut: $e'); }
      cart.clearCart();
      user.logout();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _rateApp() async {
    final Uri url = Uri.parse('https://play.google.com/store');
    try {
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (e) { debugPrint('Rate app: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          foregroundColor: TurbocartColors.textDark,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ── Section 1: Green Header ──────────────────────────────────
              _buildHeader(user),

              // ── Section 2: Stats Row ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: FutureBuilder<Map<String, int>>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? {'orders': 0, 'addresses': 0, 'coupons': 0};
                    final stats = [
                      (Icons.receipt_long_outlined, data['orders']!, 'Orders'),
                      (Icons.location_on_outlined, data['addresses']!, 'Addresses'),
                      (Icons.local_offer_outlined, data['coupons']!, 'Coupons'),
                    ];
                    return Row(
                      children: List.generate(3, (i) {
                        final s = stats[i];
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == 2 ? 0 : 6),
                            child: ScaleTransition(
                              scale: _statScale[i],
                              child: FadeTransition(
                                opacity: _statFade[i],
                                child: _StatCard(icon: s.$1, value: s.$2, label: s.$3),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),

              // ── Section 3: Menu Items ────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    _menuItem(0, Icons.receipt_long_outlined, 'My Orders', () => context.push('/orders')),
                    _divider(),
                    _menuItem(1, Icons.location_on_outlined, 'Saved Addresses', () => context.push('/address')),
                    _divider(),
                    _menuItem(2, Icons.local_offer_outlined, 'Coupons & Offers', () => context.push('/coupons')),
                    _divider(),
                    _menuItem(3, Icons.headset_mic_outlined, 'Help & Support', () => context.push('/help')),
                    _divider(),
                    _menuItem(4, Icons.star_border_outlined, 'Rate the App', _rateApp),
                    _divider(),
                    _menuItem(5, Icons.info_outlined, 'About', () => context.push('/about')),
                  ],
                ),
              ),

              // ── Section 4: Logout ────────────────────────────────────────
              FadeTransition(
                opacity: _logoutFade,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFEBEE)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _LogoutTile(onTap: _logout),
                ),
              ),

              // ── Section 5: Footer ────────────────────────────────────────
              const SizedBox(height: 20),
              Text('Version 1.0.0', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const SizedBox(height: 6),
              Text('Made with ❤️ in India', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProvider user) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // ── Avatar with camera button ──
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: TurbocartColors.primary,
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white,
                  backgroundImage: user.photoUrl != null
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? const Icon(Icons.person, size: 40, color: TurbocartColors.textGrey)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickAndUploadImage(user),
                  child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(
                      color: TurbocartColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator(color: TurbocartColors.primary, strokeWidth: 2)),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // ── User info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? 'Guest User',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.phoneNumber ?? '',
                  style: const TextStyle(fontSize: 13, color: TurbocartColors.textGrey),
                ),
                const SizedBox(height: 8),
                // Edit Profile chip
                GestureDetector(
                  onTap: () => context.push('/profile-setup', extra: {
                    'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
                    'phone': user.phoneNumber ?? '',
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: TurbocartColors.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(fontSize: 11, color: TurbocartColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 0.5, thickness: 0.5, color: const Color(0xFFF0F0F0));

  Widget _menuItem(int index, IconData icon, String label, VoidCallback onTap) {
    return SlideTransition(
      position: _menuSlide[index],
      child: FadeTransition(
        opacity: _menuFade[index],
        child: _PressableTile(icon: icon, label: label, iconColor: const Color(0xFF0C831F), onTap: onTap),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Stat Card with counter animation
// ──────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatefulWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _countAnim = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8F5E9), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: const Color(0xFF0C831F), size: 26),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _countAnim,
            builder: (context, child) => Text(
              '${_countAnim.value.floor()}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.label, style: const TextStyle(fontSize: 12, color: TurbocartColors.textGrey)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Pressable Menu Tile — iOS-style press feedback (scale 0.97)
// ──────────────────────────────────────────────────────────────────────────────
class _PressableTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _PressableTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_PressableTile> createState() => _PressableTileState();
}

class _PressableTileState extends State<_PressableTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 20, color: widget.iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Logout Tile
// ──────────────────────────────────────────────────────────────────────────────
class _LogoutTile extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});

  @override
  State<_LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<_LogoutTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout, size: 20, color: Colors.red.shade400),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Logout', style: TextStyle(fontSize: 14, color: Colors.red.shade400)),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

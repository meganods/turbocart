import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_auth_provider.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String _lastUpdated = 'Just now';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _refreshData() {
    setState(() {
      final now = DateTime.now();
      _lastUpdated = 'Updated at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing panel data...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AdminAuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Confirm Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('Are you sure you want to sign out of the TurboCart Admin Panel?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await authProvider.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String _getPageTitle(String path) {
    if (path == '/') return 'Dashboard';
    if (path.startsWith('/products')) return 'Products Management';
    if (path.startsWith('/categories')) return 'Categories Management';
    if (path.startsWith('/orders')) return 'Orders Management';
    if (path.startsWith('/coupons')) return 'Coupons Management';
    if (path.startsWith('/banners')) return 'Banners Management';
    if (path.startsWith('/users')) return 'Users Management';
    if (path.startsWith('/settings')) return 'Settings';
    if (path.startsWith('/delivery-partners')) return 'Delivery Partners';
    return 'Admin Panel';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AdminAuthProvider>(context);
    final currentRoute = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth <= 1024;

    // Sidebar navigation items
    final sidebarItems = [
      _SidebarItem(icon: Icons.grid_view, label: 'Dashboard', route: '/'),
      _SidebarItem(icon: Icons.inventory_2_outlined, label: 'Products', route: '/products'),
      _SidebarItem(icon: Icons.category_outlined, label: 'Categories', route: '/categories'),
      _SidebarItem(icon: Icons.receipt_long_outlined, label: 'Orders', route: '/orders'),
      _SidebarItem(icon: Icons.local_offer_outlined, label: 'Coupons', route: '/coupons'),
      _SidebarItem(icon: Icons.image_outlined, label: 'Banners', route: '/banners'),
      _SidebarItem(icon: Icons.people_outline, label: 'Users', route: '/users'),
      _SidebarItem(icon: Icons.directions_bike_outlined, label: 'Delivery Partners', route: '/delivery-partners'),
      _SidebarItem(icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
    ];

    Widget buildSidebarContent({required bool collapsed}) {
      final primaryGreen = const Color(0xFF0C831F);

      return Column(
        children: [
          // Admin Profile Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: collapsed ? 12 : 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: primaryGreen,
                    size: 24,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Store Admin',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        Text(
                          authProvider.user?.email ?? 'admin@turbocart.com',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              itemCount: sidebarItems.length,
              itemBuilder: (context, index) {
                final item = sidebarItems[index];
                final isSelected = item.route == '/'
                    ? currentRoute == '/'
                    : currentRoute.startsWith(item.route);

                final navWidget = Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryGreen.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border(left: BorderSide(color: primaryGreen, width: 3)) : null,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
                  alignment: collapsed ? Alignment.center : Alignment.centerLeft,
                  child: collapsed
                      ? Icon(item.icon, color: isSelected ? primaryGreen : const Color(0xFF6B7280), size: 20)
                      : Row(
                          children: [
                            Icon(item.icon, color: isSelected ? primaryGreen : const Color(0xFF6B7280), size: 20),
                            const SizedBox(width: 14),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? primaryGreen : const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: InkWell(
                    onTap: () {
                      if (isMobile) {
                        Navigator.pop(context); // Close drawer
                      }
                      context.go(item.route);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: collapsed
                        ? Tooltip(
                            message: item.label,
                            preferBelow: false,
                            child: navWidget,
                          )
                        : navWidget,
                  ),
                );
              },
            ),
          ),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
            ),
            child: InkWell(
              onTap: () => _showLogoutConfirmation(context, authProvider),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: collapsed
                    ? const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20)
                    : Row(
                        children: [
                          const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 14),
                          Text(
                            'Logout',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      );
    }

    final sidebarGradient = const LinearGradient(
      colors: [Color(0xFFE0F2FE), Color(0xFFDCFCE7)], // Light sky-blue to light mint-green
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: isMobile
          ? Drawer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: sidebarGradient,
                ),
                child: SafeArea(
                  child: buildSidebarContent(collapsed: false),
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          // Sidebar for Desktop and Tablet
          if (!isMobile)
            Container(
              width: isTablet ? 72 : 240,
              decoration: BoxDecoration(
                gradient: sidebarGradient,
                border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: buildSidebarContent(collapsed: isTablet),
            ),

          // Main page panel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action Bar Header
                Container(
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Hamburger button for mobile
                      if (isMobile) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Color(0xFF374151), size: 20),
                            onPressed: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _getPageTitle(currentRoute),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _lastUpdated,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, size: 20),
                        color: const Color(0xFF4B5563),
                        tooltip: 'Refresh data',
                      ),
                    ],
                  ),
                ),

                // Loaded route child
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final String route;

  _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

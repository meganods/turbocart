import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'providers/admin_auth_provider.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/coupons/coupons_screen.dart';
import 'screens/banners/banners_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/main_shell.dart';

import 'providers/dashboard_provider.dart';
import 'providers/products_provider.dart';
import 'screens/products/product_form_screen.dart';
import 'providers/categories_provider.dart';
import 'screens/categories/category_form_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'providers/coupons_provider.dart';
import 'screens/coupons/coupon_form_screen.dart';
import 'providers/banners_provider.dart';
import 'providers/users_provider.dart';
import 'screens/banners/banner_form_screen.dart';
import 'screens/users/user_detail_screen.dart';
import 'screens/delivery_partners/delivery_partners_screen.dart';
import 'screens/delivery_partners/delivery_partner_form_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try initializing Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminAuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => CategoriesProvider()),
        ChangeNotifierProvider(create: (_) => CouponsProvider()),
        ChangeNotifierProvider(create: (_) => BannersProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
      ],
      child: const TurbocartAdminApp(),
    ),
  );
}

class TurbocartAdminApp extends StatefulWidget {
  const TurbocartAdminApp({super.key});

  @override
  State<TurbocartAdminApp> createState() => _TurbocartAdminAppState();
}

class _TurbocartAdminAppState extends State<TurbocartAdminApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AdminAuthProvider>(context, listen: false);

    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoggingIn = state.uri.path == '/login';

        if (!isAuthenticated) {
          if (!isLoggingIn) {
            final errorQuery = authProvider.error != null ? '?error=unauthorized' : '';
            return '/login$errorQuery';
          }
          return null;
        }

        if (isLoggingIn) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/products',
              builder: (context, state) => const ProductsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const ProductFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'];
                    return ProductFormScreen(productId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const CategoryFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'];
                    return CategoryFormScreen(categoryId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/orders',
              builder: (context, state) => const OrdersScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return OrderDetailAdminScreen(orderId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/coupons',
              builder: (context, state) => const CouponsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const CouponFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:code',
                  builder: (context, state) {
                    final code = state.pathParameters['code'];
                    return CouponFormScreen(couponCode: code);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/banners',
              builder: (context, state) => const BannersScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const BannerFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'];
                    return BannerFormScreen(bannerId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/users',
              builder: (context, state) => const UsersScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return UserDetailAdminScreen(userId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/delivery-partners',
              builder: (context, state) => const DeliveryPartnersScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const DeliveryPartnerFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'];
                    return DeliveryPartnerFormScreen(partnerId: id);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TurboCart Admin Panel',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0C831F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C831F),
          primary: const Color(0xFF0C831F),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
    );
  }
}

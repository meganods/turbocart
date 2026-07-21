import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/category_products_screen.dart';
import '../screens/search_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/address_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/order_confirmation_screen.dart';
import '../screens/order_tracking_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/location_permission_screen.dart';
import '../screens/location_search_screen.dart';
import '../screens/confirm_location_screen.dart';
import '../screens/categories/subcategory_screen.dart';
import '../screens/order_detail/order_detail_screen.dart';
import '../screens/store/store_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../models/order_model.dart';
import '../screens/coupons_screen.dart';
import '../screens/about_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final isLoggedIn = firebaseUser != null || userProvider.isLoggedIn;

      final path = state.uri.path;

      // Paths accessible without being logged in
      final isPublicPath = path == '/login' ||
          path == '/otp' ||
          path == '/onboarding' ||
          path == '/' ||
          path == '/profile-setup' ||
          path == '/location-permission' ||
          path == '/location-search' ||
          path == '/confirm-location';

      if (!isLoggedIn && !isPublicPath) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            verificationId: extra['verificationId'] as String? ?? 'mock-ver-id-12345',
            phoneNumber: extra['phoneNumber'] as String? ?? '+919876543210',
          );
        },
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ProfileSetupScreen(
            uid: extra['uid'] as String? ?? 'mock-uid-123456',
            phone: extra['phone'] as String? ?? '+919876543210',
          );
        },
      ),

      // ── Location Flow ─────────────────────────────────────────────────────
      GoRoute(
        path: '/location-permission',
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      GoRoute(
        path: '/location-search',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LocationSearchScreen(extra: extra);
        },
      ),
      GoRoute(
        path: '/confirm-location',
        builder: (context, state) {
          final extra =
              state.extra as Map<String, dynamic>? ?? {};
          return ConfirmLocationScreen(extra: extra);
        },
      ),

      // ── Main App ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(initialIndex: 0),
      ),
      GoRoute(
        path: '/category',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CategoryProductsScreen(
            categoryId: extra['categoryId'] as String,
          );
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SearchScreen(extra: extra);
        },
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ProductDetailScreen(
            product: extra,
          );
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/address',
        builder: (context, state) {
          final isFromCheckout = (state.extra as Map<String, dynamic>?)?['isFromCheckout'] as bool? ?? false;
          return AddressScreen(isFromCheckout: isFromCheckout);
        },
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/order-confirmation',
        builder: (context, state) {
          final orderId = state.extra as String? ?? 'mock_order_id';
          return OrderConfirmationScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/order-tracking',
        builder: (context, state) {
          final orderId = state.extra as String? ?? 'mock_order_id';
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const HomeScreen(initialIndex: 3),
      ),
      GoRoute(
        path: '/order-again',
        name: 'order-again',
        builder: (context, state) => const HomeScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        builder: (context, state) => const HomeScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/subcategory/:id',
        builder: (context, state) => SubcategoryScreen(
          subcategoryName: Uri.decodeComponent(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/order-detail',
        builder: (context, state) {
          final order = state.extra as OrderModel;
          return OrderDetailScreen(order: order);
        },
      ),
      GoRoute(
        path: '/store/:id',
        builder: (context, state) => StoreScreen(
          storeId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: '/coupons',
        builder: (context, state) => const CouponsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
    ],
  );
}

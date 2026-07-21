import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'constants/colors.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'providers/order_provider.dart';
import 'utils/app_router.dart';

import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'utils/search_keywords_data.dart';
import 'utils/image_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _seedDatabaseIfNeeded();
  } catch (e) {
    debugPrint('Firebase initialization failed (likely missing configuration files): $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: const TurboCartApp(),
    ),
  );
}

Future<void> _seedDatabaseIfNeeded() async {
  try {
    final productsCollection = FirebaseFirestore.instance.collection('products');
    final snapshot = await productsCollection.get();
    if (snapshot.docs.isEmpty) {
      debugPrint('Firestore products collection is empty. Seeding local products...');
      for (final product in kLocalProducts) {
        final docId = product['id'] as String;
        final cleanProduct = Map<String, dynamic>.from(product);
        cleanProduct['image'] = ImageUtils.getCleanImageUrl(
          cleanProduct['image'] as String?,
          category: cleanProduct['category'] as String?,
          title: cleanProduct['title'] as String? ?? cleanProduct['name'] as String?,
        );
        await productsCollection.doc(docId).set(cleanProduct);
      }
      debugPrint('Database seeded successfully with ${kLocalProducts.length} products!');
    } else {
      debugPrint('Database already has products. Running image sanitization migration...');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawImg = data['image'] as String?;
        final cleanImg = ImageUtils.getCleanImageUrl(
          rawImg,
          category: data['category'] as String?,
          title: (data['title'] ?? data['name']) as String?,
        );

        final rawImages = data['images'] as List<dynamic>? ?? [];
        final cleanImages = rawImages.map((img) {
          return ImageUtils.getCleanImageUrl(
            img as String?,
            category: data['category'] as String?,
            title: (data['title'] ?? data['name']) as String?,
          );
        }).toList();

        bool needsUpdate = false;
        final updates = <String, dynamic>{};
        if (rawImg != cleanImg) {
          updates['image'] = cleanImg;
          needsUpdate = true;
        }
        if (rawImages.toString() != cleanImages.toString()) {
          updates['images'] = cleanImages;
          needsUpdate = true;
        }

        if (needsUpdate) {
          await productsCollection.doc(doc.id).update(updates);
        }
      }
      debugPrint('Database image migration complete!');
    }
  } catch (e) {
    debugPrint('Database seeding failed: $e');
  }
}

class ConnectivityBannerWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityBannerWrapper({super.key, required this.child});

  @override
  State<ConnectivityBannerWrapper> createState() => _ConnectivityBannerWrapperState();
}

class _ConnectivityBannerWrapperState extends State<ConnectivityBannerWrapper> {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results);
    });

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.isLoggedIn) {
          userProvider.clearUser();
          AppRouter.router.go('/login');
        }
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isNone = results.contains(ConnectivityResult.none) || results.isEmpty;
    if (_isOffline != isNone) {
      setState(() {
        _isOffline = isNone;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isOffline)
          Material(
            color: Colors.redAccent,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class TurboCartApp extends StatelessWidget {
  const TurboCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TurboCart',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return ConnectivityBannerWrapper(child: child ?? const SizedBox.shrink());
      },
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: TurbocartColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TurbocartColors.primary,
          primary: TurbocartColors.primary,
          secondary: TurbocartColors.accent,
          surface: TurbocartColors.surface,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
    );
  }
}

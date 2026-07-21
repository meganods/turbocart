import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/delivery_auth_provider.dart';
import 'providers/delivery_orders_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0C831F);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeliveryAuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => DeliveryOrdersProvider()),
      ],
      child: MaterialApp(
        title: 'TurboCart Delivery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryGreen,
            primary: primaryGreen,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<DeliveryAuthProvider>(context);

    if (authProvider.isLoggedIn) {
      return const HomeDashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}

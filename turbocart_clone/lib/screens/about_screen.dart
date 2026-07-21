import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('URL launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: TurbocartColors.textDark,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── App icon ──
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF0C831F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Turbocart Clone',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TurbocartColors.textDark)),
            const SizedBox(height: 4),
            Text('v1.0.0', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // ── Links ──
            _AboutTile(
              title: 'Privacy Policy',
              icon: Icons.privacy_tip_outlined,
              onTap: () => _launch('https://policies.google.com/privacy'),
            ),
            const Divider(height: 0, indent: 16, endIndent: 16),
            _AboutTile(
              title: 'Terms of Service',
              icon: Icons.description_outlined,
              onTap: () => _launch('https://policies.google.com/terms'),
            ),
            const Divider(height: 0, indent: 16, endIndent: 16),
            _AboutTile(
              title: 'Open Source Licenses',
              icon: Icons.source_outlined,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Turbocart Clone',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 All rights reserved.',
              ),
            ),

            const SizedBox(height: 40),
            Text('Built with Flutter & Firebase',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text('© 2024 All rights reserved.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AboutTile({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: const Color(0xFF0C831F)),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
      onTap: onTap,
      tileColor: Colors.white,
    );
  }
}

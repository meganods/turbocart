import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {
      'question': 'How quickly will my order be delivered?',
      'answer': 'We deliver most orders within 10-15 minutes depending on your location and store availability. You can track your order live after checkout.'
    },
    {
      'question': 'Can I cancel my order?',
      'answer': 'Yes, you can cancel your order within 60 seconds of placing it. Once the store starts preparing your order, cancellation is not possible.'
    },
    {
      'question': 'What are the delivery charges?',
      'answer': 'Delivery is free for orders above ₹199. For orders below ₹199, a nominal delivery fee of ₹40 is charged.'
    },
    {
      'question': 'How do I request a refund?',
      'answer': 'If you received damaged or incorrect items, you can raise a refund request from the "My Orders" detail page within 24 hours of delivery.'
    },
    {
      'question': 'Which payment methods are accepted?',
      'answer': 'We accept Credit/Debit Cards, UPI (GPay, PhonePe, Paytm), Netbanking, Wallets, and Cash on Delivery (COD).'
    },
  ];

  Future<void> _launchUrlHelper(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Find quick answers to common questions', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              color: Colors.white,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: faqs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ExpansionTile(
                    title: Text(
                      faqs[index]['question']!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          faqs[index]['answer']!,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSupportCard(
                    context,
                    'Call Customer Care',
                    'Available 24x7 for active order issues',
                    Icons.phone_outlined,
                    () => _launchUrlHelper('tel:+919876543210'),
                  ),
                  const SizedBox(height: 12),
                  _buildSupportCard(
                    context,
                    'Email Support',
                    'Write to us for refund or billing queries',
                    Icons.mail_outline,
                    () => _launchUrlHelper('mailto:support@turbocartclone.com'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Starting Live Support Chat...'), backgroundColor: Color(0xFF0C831F)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C831F),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Chat Live with Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE8F5E9),
              child: Icon(icon, color: const Color(0xFF0C831F)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

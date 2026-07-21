import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  final List<Map<String, String>> _faqs = const [
    {
      'question': 'How does the 10-minute delivery work?',
      'answer': 'We have dark stores strategically located in your city. Once you place an order, our staff picks and packs items within 2 minutes, and our delivery partners deliver it within the next 8 minutes using optimized routes.'
    },
    {
      'question': 'What is the refund policy for bad items?',
      'answer': 'If you receive damaged, stale, or incorrect items, you can request a refund immediately from the My Orders details section. The amount is refunded instantly to your original payment source or wallet.'
    },
    {
      'question': 'Can I edit or cancel my order after booking?',
      'answer': 'You can cancel your order within 60 seconds of placing it, as long as it has not been confirmed by the store. Once the store confirms it, the picking process begins and cancellations are not permitted.'
    },
    {
      'question': 'Is there a minimum order amount for free delivery?',
      'answer': 'Yes, all orders of ₹199 or above receive FREE delivery. For orders below ₹199, a nominal delivery charge of ₹40 applies.'
    },
    {
      'question': 'How do I contact customer support?',
      'answer': 'You can call us directly at 1800-TURBOCART or write to us at support@turbocartclone.com. Our support team is available 24/7 to resolve your queries.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: TurbocartColors.textDark,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner/Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TurbocartColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TurbocartColors.primary.withValues(alpha: 0.15)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, how can we help?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: TurbocartColors.primary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Find quick answers below or get in touch with our support team.',
                    style: TextStyle(fontSize: 12, color: TurbocartColors.textDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
            ),
            const SizedBox(height: 12),

            // FAQs expansion tiles list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _faqs.length,
              itemBuilder: (context, index) {
                final faq = _faqs[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: TurbocartColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TurbocartColors.lightGrey.withValues(alpha: 0.5)),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TurbocartColors.textDark),
                    ),
                    childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    expandedAlignment: Alignment.topLeft,
                    textColor: TurbocartColors.primary,
                    iconColor: TurbocartColors.primary,
                    collapsedIconColor: TurbocartColors.textGrey,
                    shape: const Border(), // remove separator borders
                    children: [
                      Text(
                        faq['answer']!,
                        style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Customer Care Cards
            const Text(
              'Still need help?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chat with Us',
                    subtitle: 'Average reply: 2m',
                    onTap: () {
                      SnackBarUtils.showTopSnackBar(
                        context,
                        'Chat support simulator starting...',
                        backgroundColor: TurbocartColors.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildContactCard(
                    context,
                    icon: Icons.phone_outlined,
                    title: 'Call Support',
                    subtitle: '24/7 Helpline',
                    onTap: () {
                      SnackBarUtils.showTopSnackBar(
                        context,
                        'Helpline: 1800-TURBOCART',
                        backgroundColor: TurbocartColors.primary,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TurbocartColors.lightGrey),
        ),
        child: Column(
          children: [
            Icon(icon, color: TurbocartColors.primary, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TurbocartColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

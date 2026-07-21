import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': 'noti_1',
      'title': 'Order Delivered 🎉',
      'body': 'Your order has been successfully delivered. Rate your experience now!',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
      'read': true,
    },
    {
      'id': 'noti_2',
      'title': 'Flat 50% OFF on Fruits 🍉',
      'body': 'Get fresh organic fruits at half price today only. Coupon: FRUITS50',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
      'read': false,
    },
    {
      'id': 'noti_3',
      'title': 'Welcome to Turbocart! 👋',
      'body': 'Enjoy your shopping with super fast delivery at your doorstep.',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
      'read': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      body: uid == null
          ? _buildNotificationList(_mockNotifications)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(uid)
                  .collection('items')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmer();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNotificationList(_mockNotifications);
                }

                final notifications = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'title': data['title'] ?? '',
                    'body': data['body'] ?? '',
                    'timestamp': data['timestamp'] ?? Timestamp.now(),
                    'read': data['read'] ?? true,
                  };
                }).toList();

                return _buildNotificationList(notifications);
              },
            ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: notifications.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final noti = notifications[index];
        final isRead = noti['read'] == true;
        final timestamp = noti['timestamp'] as Timestamp;
        final timeString = DateFormat('dd MMM, hh:mm a').format(timestamp.toDate());

        return Container(
          color: isRead ? Colors.transparent : const Color(0xFFE8F5E9).withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isRead ? Colors.grey[200] : const Color(0xFFE8F5E9),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: isRead ? Colors.grey : const Color(0xFF0C831F),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            noti['title'],
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 14,
                              color: isRead ? Colors.black87 : Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          timeString,
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noti['body'],
                      style: TextStyle(
                        color: isRead ? Colors.grey[600] : Colors.black87,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        itemCount: 4,
        padding: const EdgeInsets.symmetric(vertical: 12),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Container(
          height: 80,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No new notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We will notify you when something important happens.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

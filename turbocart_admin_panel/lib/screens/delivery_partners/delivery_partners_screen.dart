import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../utils/admin_logger.dart';

class DeliveryPartnersScreen extends StatefulWidget {
  const DeliveryPartnersScreen({super.key});

  @override
  State<DeliveryPartnersScreen> createState() => _DeliveryPartnersScreenState();
}

class _DeliveryPartnersScreenState extends State<DeliveryPartnersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _toggleStatus(String partnerId, bool currentStatus) async {
    try {
      await _db.collection('delivery_partners').doc(partnerId).update({
        'isActive': !currentStatus,
      });

      await AdminLogger.log(
        actionType: 'TOGGLE_PARTNER_STATUS',
        affectedDocId: partnerId,
        details: 'Delivery partner status updated to ${!currentStatus ? 'Active' : 'Inactive'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deletePartner(String partnerId, String name) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Partner', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete delivery partner "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _db.collection('delivery_partners').doc(partnerId).delete();
                  await AdminLogger.log(
                    actionType: 'DELETE_PARTNER',
                    affectedDocId: partnerId,
                    details: 'Deleted partner: $name',
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Delivery partner deleted successfully!'),
                      backgroundColor: Color(0xFF0C831F),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Row
            Row(
              children: [
                const Text(
                  'Manage Delivery Partners',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go('/delivery-partners/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Delivery Partner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table of Partners
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('delivery_partners').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading partners: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No delivery partners registered yet. Click "Add Delivery Partner" to register one.'),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columnSpacing: 32,
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Vehicle Type')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: docs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final name = data['name'] ?? 'N/A';
                                  final phone = data['phone'] ?? 'N/A';
                                  final vehicle = data['vehicleType'] ?? 'N/A';
                                  final isActive = data['isActive'] == true;

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(phone)),
                                      DataCell(Text(vehicle)),
                                      DataCell(
                                        Switch(
                                          value: isActive,
                                          activeThumbColor: primaryGreen,
                                          onChanged: (val) => _toggleStatus(doc.id, isActive),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                              onPressed: () => context.go('/delivery-partners/edit/${doc.id}'),
                                              tooltip: 'Edit Partner',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                              onPressed: () => _deletePartner(doc.id, name),
                                              tooltip: 'Delete Partner',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

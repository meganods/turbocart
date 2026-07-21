import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _adminEmailFormKey = GlobalKey<FormState>();
  final _newAdminController = TextEditingController();
  bool _isAddingAdmin = false;

  final _storeSettingsFormKey = GlobalKey<FormState>();
  final _deliveryTimeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _deliveryFeeThresholdController = TextEditingController();
  final _gstController = TextEditingController();
  final _perDeliveryRateController = TextEditingController();
  bool _isSavingStoreSettings = false;
  bool _isLoadingStoreSettings = true;

  @override
  void initState() {
    super.initState();
    _loadStoreSettings();
  }

  @override
  void dispose() {
    _newAdminController.dispose();
    _deliveryTimeController.dispose();
    _minOrderController.dispose();
    _deliveryFeeThresholdController.dispose();
    _gstController.dispose();
    _perDeliveryRateController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('store').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _deliveryTimeController.text = data['deliveryTime']?.toString() ?? '10 minutes';
          _minOrderController.text = data['minOrderAmount']?.toString() ?? '0';
          _deliveryFeeThresholdController.text = data['deliveryFeeThreshold']?.toString() ?? '199';
          _gstController.text = data['gstPercent']?.toString() ?? '5';
          _perDeliveryRateController.text = data['perDeliveryRate']?.toString() ?? '50';
        });
      } else {
        // Defaults
        setState(() {
          _deliveryTimeController.text = '10 minutes';
          _minOrderController.text = '0';
          _deliveryFeeThresholdController.text = '199';
          _gstController.text = '5';
          _perDeliveryRateController.text = '50';
        });
      }
    } catch (e) {
      debugPrint('Failed to load store settings: $e');
    } finally {
      setState(() {
        _isLoadingStoreSettings = false;
      });
    }
  }

  Future<void> _saveStoreSettings() async {
    if (!_storeSettingsFormKey.currentState!.validate()) return;

    setState(() {
      _isSavingStoreSettings = true;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.collection('settings').doc('store').set({
        'deliveryTime': _deliveryTimeController.text.trim(),
        'minOrderAmount': double.parse(_minOrderController.text.trim()),
        'deliveryFeeThreshold': double.parse(_deliveryFeeThresholdController.text.trim()),
        'gstPercent': double.parse(_gstController.text.trim()),
        'perDeliveryRate': double.parse(_perDeliveryRateController.text.trim()),
        'updatedAt': Timestamp.now(),
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Store settings updated successfully!'),
          backgroundColor: Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isSavingStoreSettings = false;
      });
    }
  }

  Future<void> _addNewAdmin() async {
    if (!_adminEmailFormKey.currentState!.validate()) return;

    setState(() {
      _isAddingAdmin = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final email = _newAdminController.text.trim().toLowerCase();

    try {
      await FirebaseFirestore.instance.collection('admins').doc(email).set({
        'email': email,
        'createdAt': Timestamp.now(),
      });

      _newAdminController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Admin whitelist added successfully for: $email'),
          backgroundColor: const Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to whitelist admin: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isAddingAdmin = false;
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Password reset email dispatched to ${user.email}'),
            backgroundColor: const Color(0xFF0C831F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to send reset email: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            const Row(
              children: [
                Text(
                  'Settings & Configuration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Two-column responsive card layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 950;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildAdminAccountCard(currentUser),
                            const SizedBox(height: 24),
                            _buildAddAdminCard(primaryGreen),
                            const SizedBox(height: 24),
                            _buildAppVersionCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: _buildStoreSettingsCard(primaryGreen),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildAdminAccountCard(currentUser),
                      const SizedBox(height: 20),
                      _buildAddAdminCard(primaryGreen),
                      const SizedBox(height: 20),
                      _buildStoreSettingsCard(primaryGreen),
                      const SizedBox(height: 20),
                      _buildAppVersionCard(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAccountCard(User? user) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF0C831F)),
                SizedBox(width: 8),
                Text('Admin Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Email Address:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? 'Not Logged In',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: user != null ? _sendPasswordReset : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F).withOpacity(0.08),
                foregroundColor: const Color(0xFF0C831F),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Change Password (Reset Email)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAdminCard(Color primaryGreen) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _adminEmailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF0C831F)),
                  SizedBox(width: 8),
                  Text('Add New Admin Whitelist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _newAdminController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New Admin Email *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. manager@store.com',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required field';
                  if (!v.contains('@') || !v.contains('.')) return 'Invalid email format';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isAddingAdmin ? null : _addNewAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isAddingAdmin
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Add Whitelist Admin', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreSettingsCard(Color primaryGreen) {
    if (_isLoadingStoreSettings) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)))),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _storeSettingsFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_outlined, color: Color(0xFF0C831F)),
                  SizedBox(width: 8),
                  Text('Store Variables Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                ],
              ),
              const Divider(height: 24),

              // Delivery Time Text
              TextFormField(
                controller: _deliveryTimeController,
                decoration: const InputDecoration(
                  labelText: 'Default Delivery Time text (e.g. 8 minutes) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 20),

              // Min Order Amount
              TextFormField(
                controller: _minOrderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Order Value (₹) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required field';
                  if (double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Free Delivery Threshold
              TextFormField(
                controller: _deliveryFeeThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Free Delivery Fee Threshold (₹) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required field';
                  if (double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // GST Percent
              TextFormField(
                controller: _gstController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'GST Rate Percentage (%) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required field';
                  if (double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Per Delivery Commission Rate
              TextFormField(
                controller: _perDeliveryRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Per Delivery Partner Commission (₹) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required field';
                  if (double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isSavingStoreSettings ? null : _saveStoreSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSavingStoreSettings
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Update Store Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersionCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Version Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
            SizedBox(height: 8),
            Text(
              'TurboCart Admin Console v1.0.2',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            ),
            SizedBox(height: 4),
            Text('Released: June 2026', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

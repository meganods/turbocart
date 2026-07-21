import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../utils/admin_logger.dart';

class DeliveryPartnerFormScreen extends StatefulWidget {
  final String? partnerId;
  const DeliveryPartnerFormScreen({super.key, this.partnerId});

  @override
  State<DeliveryPartnerFormScreen> createState() => _DeliveryPartnerFormScreenState();
}

class _DeliveryPartnerFormScreenState extends State<DeliveryPartnerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedVehicle = 'Motorcycle';
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.partnerId != null) {
      _loadPartnerData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPartnerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await _db.collection('delivery_partners').doc(widget.partnerId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        final rawPhone = data['phone'] ?? '';
        _phoneController.text = rawPhone.startsWith('+91') ? rawPhone.substring(3) : rawPhone;
        _selectedVehicle = data['vehicleType'] ?? 'Motorcycle';
        _isActive = data['isActive'] ?? true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load partner details: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePartner() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final phoneInput = _phoneController.text.trim();
      final fullPhone = phoneInput.startsWith('+91') ? phoneInput : '+91$phoneInput';

      final data = {
        'name': _nameController.text.trim(),
        'phone': fullPhone,
        'vehicleType': _selectedVehicle,
        'isActive': _isActive,
      };

      if (widget.partnerId == null) {
        // Create new
        final docRef = _db.collection('delivery_partners').doc();
        data['id'] = docRef.id;
        await docRef.set(data);

        await AdminLogger.log(
          actionType: 'CREATE_PARTNER',
          affectedDocId: docRef.id,
          details: 'Created delivery partner: ${data['name']}',
        );
      } else {
        // Update existing
        await _db.collection('delivery_partners').doc(widget.partnerId).update(data);

        await AdminLogger.log(
          actionType: 'UPDATE_PARTNER',
          affectedDocId: widget.partnerId!,
          details: 'Updated delivery partner details for: ${data['name']}',
        );
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.partnerId == null ? 'Partner added successfully!' : 'Partner details updated successfully!'),
          backgroundColor: const Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      router.go('/delivery-partners');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save details: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/delivery-partners'),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.partnerId == null ? 'Add Delivery Partner' : 'Edit Delivery Partner',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form card
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name Field
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone Field
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixText: '+91 ',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter phone number';
                              }
                              if (value.trim().length != 10 || int.tryParse(value.trim()) == null) {
                                return 'Please enter a valid 10-digit number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Vehicle Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedVehicle,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Type',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Bicycle', 'Motorcycle', 'Electric Scooter'].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedVehicle = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // Active Status switch
                          SwitchListTile(
                            title: const Text('Active Delivery Status'),
                            subtitle: const Text('Enable/disable delivery login and assignment permissions.'),
                            value: _isActive,
                            activeColor: primaryGreen,
                            onChanged: (val) {
                              setState(() {
                                _isActive = val;
                              });
                            },
                          ),
                          const Divider(height: 32),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isSaving ? null : () => context.go('/delivery-partners'),
                                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isSaving ? null : _savePartner,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text('Save Details'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

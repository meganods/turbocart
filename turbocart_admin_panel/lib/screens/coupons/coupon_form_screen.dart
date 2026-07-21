import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/coupons_provider.dart';
import '../../models/coupon_model.dart';

class CouponFormScreen extends StatefulWidget {
  final String? couponCode;
  const CouponFormScreen({super.key, this.couponCode});

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _usageLimitController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'flat'; // 'flat', 'percent', 'freeDelivery'
  DateTime? _selectedExpiryDate;
  bool _isActive = true;
  int _existingUsedCount = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<CouponsProvider>(context, listen: false);
      await provider.fetchCoupons();

      if (widget.couponCode != null) {
        _loadCouponDetails(provider);
      }
    });
  }

  void _loadCouponDetails(CouponsProvider provider) {
    final coupon = provider.coupons.firstWhere((c) => c.code == widget.couponCode);
    setState(() {
      _codeController.text = coupon.code;
      _selectedType = coupon.type;
      _valueController.text = coupon.value.toStringAsFixed(0);
      _minOrderController.text = coupon.minOrderAmount.toStringAsFixed(0);
      _maxDiscountController.text = coupon.maxDiscount.toStringAsFixed(0);
      _selectedExpiryDate = coupon.expiryDate.toDate();
      _expiryDateController.text = DateFormat('dd MMM yyyy').format(_selectedExpiryDate!);
      _usageLimitController.text = coupon.usageLimit.toString();
      _descriptionController.text = coupon.description;
      _isActive = coupon.active;
      _existingUsedCount = coupon.usedCount;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _expiryDateController.dispose();
    _usageLimitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0C831F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
        _expiryDateController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<CouponsProvider>(context, listen: false);
    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final coupon = Coupon(
        code: _codeController.text.trim().toUpperCase(),
        type: _selectedType,
        value: _selectedType == 'freeDelivery' ? 0.0 : double.parse(_valueController.text.trim()),
        minOrderAmount: double.tryParse(_minOrderController.text.trim()) ?? 0.0,
        maxDiscount: _selectedType == 'percent' ? (double.tryParse(_maxDiscountController.text.trim()) ?? 0.0) : 0.0,
        expiryDate: Timestamp.fromDate(_selectedExpiryDate!),
        usageLimit: int.tryParse(_usageLimitController.text.trim()) ?? 1,
        usedCount: _existingUsedCount,
        description: _descriptionController.text.trim(),
        active: _isActive,
      );

      final success = await provider.saveCoupon(coupon);

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Coupon saved successfully!'),
            backgroundColor: Color(0xFF0C831F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        router.go('/coupons');
      } else {
        setState(() {
          _isSaving = false;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save coupon.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving coupon: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);
    final isNewCoupon = widget.couponCode == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navigation Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/coupons'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isNewCoupon ? 'Create New Coupon' : 'Edit Coupon Settings',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Two-column layout on Desktop
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildFormCard(isNewCoupon),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: _buildSideSettingsCard(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildFormCard(isNewCoupon),
                        const SizedBox(height: 20),
                        _buildSideSettingsCard(),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => context.go('/coupons'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF9CA3AF)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF4B5563))),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Coupon', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(bool isNewCoupon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Coupon Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 24),

            // Row 1: Code and Type
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    enabled: isNewCoupon,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldVal, newVal) {
                        return newVal.copyWith(text: newVal.text.toUpperCase());
                      })
                    ],
                    decoration: InputDecoration(
                      labelText: 'Coupon Code (e.g. BINGO50) *',
                      border: const OutlineInputBorder(),
                      filled: !isNewCoupon,
                      fillColor: !isNewCoupon ? Colors.grey.shade100 : null,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Discount Type *', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'flat', child: Text('Flat Cash Discount')),
                      DropdownMenuItem(value: 'percent', child: Text('Percentage Discount')),
                      DropdownMenuItem(value: 'freeDelivery', child: Text('Free Delivery')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 2: Value and Min Order Amount
            Row(
              children: [
                if (_selectedType != 'freeDelivery') ...[
                  Expanded(
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _selectedType == 'flat' ? 'Flat Amount (₹) *' : 'Percentage (%) *',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required field';
                        if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Must be positive number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _minOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Order Amount (₹) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required field';
                      if (double.tryParse(v) == null) return 'Must be a valid number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 3: Max Discount (percentage cap) & Expiry Picker
            Row(
              children: [
                if (_selectedType == 'percent') ...[
                  Expanded(
                    child: TextFormField(
                      controller: _maxDiscountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Discount Cap (₹) (0 for no cap)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required field';
                        if (double.tryParse(v) == null) return 'Must be a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _expiryDateController,
                    readOnly: true,
                    onTap: _selectExpiryDate,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (v) => _selectedExpiryDate == null ? 'Please pick a date' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 4: Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (e.g. Use code BINGO50 to get ₹50 off on orders above ₹199) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideSettingsCard() {
    final primaryGreen = const Color(0xFF0C831F);

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
            const Text(
              'Limits & Status',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const Divider(height: 24),

            // Usage Limit
            TextFormField(
              controller: _usageLimitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Usage Limit (Total Uses) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required field';
                if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Must be positive integer';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Active Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Active coupons can be applied', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
                Switch(
                  value: _isActive,
                  activeColor: primaryGreen,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

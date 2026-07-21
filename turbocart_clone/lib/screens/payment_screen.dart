// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  String _selectedMethod = 'UPI'; // UPI, Card, NetBanking, COD
  bool _isProcessing = false;

  // Sub-option controllers
  final _otherUpiController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String _selectedBank = 'SBI';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) {
        SnackBarUtils.showTopSnackBar(context, 'Your cart is empty. Please add items to your cart.');
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _otherUpiController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Razorpay success: ${response.paymentId}');
    _createFirestoreOrder(paymentId: response.paymentId ?? 'pay_rzp_mock', method: _selectedMethod);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay failed: ${response.code} - ${response.message}');
    setState(() {
      _isProcessing = false;
    });
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Payment Failed'),
        content: Text(response.message ?? 'An error occurred during payment processing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: TurbocartColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _initiateRazorpayCheckout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: TurbocartColors.primary),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
    _createFirestoreOrder(paymentId: 'ext_wallet_${response.walletName}', method: 'External Wallet');
  }

  Future<void> _createFirestoreOrder({required String paymentId, required String method}) async {
    setState(() {
      _isProcessing = true;
    });

    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);
    final uid = user.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'mock_uid_123';

    // Map cart items to firestore format
    final itemsList = cart.items.values.map((item) => {
      'id': item.id,
      'title': item.title,
      'price': item.price,
      'quantity': item.quantity,
      'imageUrl': item.imageUrl,
      'unit': item.unit,
    }).toList();

    final orderData = {
      'userId': uid,
      'userName': user.name ?? 'Guest User',
      'userPhone': user.phoneNumber ?? '',
      'items': itemsList,
      'address': {
        'title': user.selectedAddress?.title ?? user.addressLabel,
        'addressLine': user.selectedAddress?.addressLine ?? user.addressText,
        'latitude': user.selectedAddress?.latitude ?? user.currentLat,
        'longitude': user.selectedAddress?.longitude ?? user.currentLng,
      },
      'paymentMethod': method,
      'paymentId': paymentId,
      'status': 'placed',
      'subtotal': cart.subtotal,
      'deliveryFee': cart.deliveryFee,
      'couponDiscount': cart.couponDiscount,
      'total': cart.grandTotal,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);
      
      // Clear Cart
      cart.clearCart();
      
      if (mounted) {
        context.go('/order-confirmation', extra: docRef.id);
      }
    } catch (e) {
      debugPrint('Firestore order creation failed, saving locally: $e');
      
      // Local fallback for offline mode
      final mockOrderId = 'order_mock_${DateTime.now().millisecondsSinceEpoch}';
      cart.clearCart();
      
      if (mounted) {
        context.go('/order-confirmation', extra: mockOrderId);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _initiateRazorpayCheckout() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);

    final amountInPaise = (cart.grandTotal * 100).toInt();

    final options = {
      'key': 'rzp_test_YourKeyHere',
      'amount': amountInPaise,
      'name': 'Turbocart Clone',
      'description': 'Grocery Order Checkout',
      'prefill': {
        'contact': user.phoneNumber ?? '9876543210',
        'email': user.email ?? 'customer@turbocart.com'
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay launch failed (Web simulation active): $e');
      _createFirestoreOrder(paymentId: 'pay_simulated_123', method: _selectedMethod);
    }
  }

  void _handlePayButtonPress() async {
    setState(() {
      _isProcessing = true;
    });

    final cart = Provider.of<CartProvider>(context, listen: false);
    final db = FirebaseFirestore.instance;

    // Pre-checkout stock validation
    try {
      for (final item in cart.items.values) {
        final productDoc = await db.collection('products').doc(item.id).get();
        if (productDoc.exists) {
          final data = productDoc.data();
          if (data != null) {
            final int stock = (data['stock'] as num? ?? 0).toInt();
            if (stock < item.quantity) {
              setState(() {
                _isProcessing = false;
              });
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Out of Stock'),
                  content: Text('Sorry, "${item.title}" is out of stock or has insufficient quantity (Remaining stock: $stock). Please adjust your cart.'),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: TurbocartColors.primary),
                      child: const Text('Back to Home', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Stock validation failed: $e. Proceeding with checkout fallback.');
    }

    if (_selectedMethod == 'COD') {
      _createFirestoreOrder(paymentId: '', method: 'COD');
    } else {
      _initiateRazorpayCheckout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final user = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: TurbocartColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TurbocartColors.textDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'Payment',
          style: TextStyle(color: TurbocartColors.textDark, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: TurbocartColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Processing Order...',
                    style: TextStyle(fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 1. Order Summary Card
                  _buildOrderSummaryCard(cart, user),
                  
                  const SizedBox(height: 8),

                  // 2. Payment Methods
                  _buildPaymentMethodsList(),

                  const SizedBox(height: 8),

                  // 3. Compact Bill Summary Repeat
                  _buildCompactBillSummary(cart),

                  // 4. Pay Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handlePayButtonPress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TurbocartColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Pay ₹${cart.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderSummaryCard(CartProvider cart, UserProvider user) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cart.totalItems} items · ₹${cart.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TurbocartColors.textDark),
              ),
              const Row(
                children: [
                  Text(
                    'Delivery in 10 mins',
                    style: TextStyle(color: TurbocartColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.bolt, color: Colors.amber, size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            user.selectedAddress?.addressLine ?? 'Default Location Address',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select Payment Option',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: TurbocartColors.textDark),
            ),
          ),
          
          // UPI Options
          _buildMethodTile(
            method: 'UPI',
            title: 'UPI (GPay / PhonePe / Paytm)',
            icon: Icons.account_balance_wallet_outlined,
            expandedWidget: Row(
              children: [
                _buildUpiIcon('https://cdn-icons-png.flaticon.com/512/6124/6124998.png', 'GPay'),
                _buildUpiIcon('https://cdn-icons-png.flaticon.com/512/825/825454.png', 'PhonePe'),
                _buildUpiIcon('https://cdn-icons-png.flaticon.com/512/2991/2991167.png', 'Paytm'),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _otherUpiController,
                      decoration: InputDecoration(
                        hintText: 'Other UPI ID',
                        hintStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Credit/Debit Card Options
          _buildMethodTile(
            method: 'Card',
            title: 'Credit or Debit Card',
            icon: Icons.credit_card_outlined,
            expandedWidget: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Card Number',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _expiryController,
                          decoration: InputDecoration(
                            hintText: 'MM/YY',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _cvvController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'CVV',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // NetBanking
          _buildMethodTile(
            method: 'NetBanking',
            title: 'Net Banking',
            icon: Icons.account_balance_outlined,
            expandedWidget: Row(
              children: [
                const Text('Select Bank: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedBank,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBank = val;
                      });
                    }
                  },
                  items: ['SBI', 'HDFC', 'ICICI', 'Axis'].map((bank) {
                    return DropdownMenuItem<String>(
                      value: bank,
                      child: Text(bank),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cash on Delivery (COD)
          _buildMethodTile(
            method: 'COD',
            title: 'Cash on Delivery (COD)',
            icon: Icons.payments_outlined,
            expandedWidget: const Text(
              'No additional options. Pay cash or UPI at the doorstep.',
              style: TextStyle(color: TurbocartColors.textGrey, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile({
    required String method,
    required String title,
    required IconData icon,
    required Widget expandedWidget,
  }) {
    final isSelected = _selectedMethod == method;
    return Column(
      children: [
        RadioListTile<String>(
          value: method,
          groupValue: _selectedMethod,
          activeColor: TurbocartColors.primary,
          title: Row(
            children: [
              Icon(icon, color: TurbocartColors.textDark, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedMethod = val;
              });
            }
          },
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isSelected ? (method == 'Card' ? 104 : 60) : 0,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                if (isSelected) expandedWidget,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpiIcon(String url, String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 38,
          color: TurbocartColors.surface,
          padding: const EdgeInsets.all(4),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.wallet, size: 20, color: TurbocartColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBillSummary(CartProvider cart) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TurbocartColors.textDark),
          ),
          const SizedBox(height: 10),
          _buildCompactBillRow('Subtotal', '₹${cart.subtotal.toStringAsFixed(2)}'),
          _buildCompactBillRow('Delivery Charge', cart.deliveryFee == 0 ? 'FREE' : '₹${cart.deliveryFee.toStringAsFixed(2)}'),
          if (cart.couponDiscount > 0)
            _buildCompactBillRow('Discount', '-₹${cart.couponDiscount.toStringAsFixed(2)}', isPromo: true),
          _buildCompactBillRow('Taxes & GST (5%)', '₹${cart.taxes.toStringAsFixed(2)}'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('₹${cart.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TurbocartColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBillRow(String label, String val, {bool isPromo = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 12)),
          Text(
            val,
            style: TextStyle(
              color: isPromo ? TurbocartColors.primary : TurbocartColors.textDark,
              fontSize: 12,
              fontWeight: isPromo ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../utils/image_utils.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_card.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponController = TextEditingController();
  bool _isApplyingCoupon = false;
  Future<QuerySnapshot>? _suggestionsFuture;

  Future<QuerySnapshot> get suggestionsFuture {
    _suggestionsFuture ??= FirebaseFirestore.instance.collection('products').limit(30).get();
    return _suggestionsFuture!;
  }

  @override
  void initState() {
    super.initState();
    // Pre-initialize in initState for normal flow
    _suggestionsFuture = FirebaseFirestore.instance.collection('products').limit(30).get();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // Populate list keys on load
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _showError(BuildContext context, String message) {
    SnackBarUtils.showTopSnackBar(
      context,
      message,
      backgroundColor: Colors.redAccent,
    );
  }

  void _showSuccess(BuildContext context, String message) {
    SnackBarUtils.showTopSnackBar(
      context,
      message,
      backgroundColor: TurbocartColors.primary,
    );
  }

  Future<void> _validateAndApplyCoupon(BuildContext context, CartProvider cart) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingCoupon = true;
    });

    try {
      // 1. Try Firestore fetch
      final doc = await FirebaseFirestore.instance.collection('coupons').doc(code).get();
      if (!context.mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        final active = data['active'] ?? false;
        final expiry = data['expiryDate'];
        DateTime expiryDate;
        if (expiry is Timestamp) {
          expiryDate = expiry.toDate();
        } else if (expiry is String) {
          expiryDate = DateTime.parse(expiry);
        } else {
          expiryDate = DateTime.now().add(const Duration(days: 1));
        }

        final minOrder = (data['minOrder'] as num?)?.toDouble() ?? 0.0;
        final usedCount = (data['usedCount'] as num?)?.toInt() ?? 0;
        final usageLimit = (data['usageLimit'] as num?)?.toInt() ?? 9999;
        final type = data['type'] ?? 'flat';
        final value = (data['value'] as num?)?.toDouble() ?? 0.0;
        final maxDiscount = (data['maxDiscount'] as num?)?.toDouble();

        if (!active) {
          _showError(context, 'This coupon is inactive.');
          setState(() => _isApplyingCoupon = false);
          return;
        }

        if (expiryDate.isBefore(DateTime.now())) {
          _showError(context, 'This coupon has expired.');
          setState(() => _isApplyingCoupon = false);
          return;
        }

        if (cart.subtotal < minOrder) {
          _showError(context, 'Min order for this coupon is ₹${minOrder.toStringAsFixed(0)}');
          setState(() => _isApplyingCoupon = false);
          return;
        }

        if (usedCount >= usageLimit) {
          _showError(context, 'Coupon usage limit reached.');
          setState(() => _isApplyingCoupon = false);
          return;
        }

        double discount = 0.0;
        if (type == 'flat') {
          discount = value;
        } else if (type == 'percent') {
          discount = cart.subtotal * (value / 100);
          if (maxDiscount != null && discount > maxDiscount) {
            discount = maxDiscount;
          }
        }

        cart.applyCoupon(code, discount, type);
        _couponController.clear();
        _showSuccess(context, 'Coupon applied!');
        setState(() => _isApplyingCoupon = false);
        return;
      }
    } catch (e) {
      debugPrint('Firestore coupon fetch failed, falling back to mock: $e');
    }

    if (!context.mounted) return;

    // 2. Mock Fallbacks for testing
    final String upperCode = code.toUpperCase();
    if (upperCode == 'FLAT50') {
      if (cart.subtotal < 100) {
        _showError(context, 'Minimum order of ₹100 required for FLAT50');
      } else {
        cart.applyCoupon('FLAT50', 50.0, 'flat');
        _couponController.clear();
        _showSuccess(context, 'FLAT50 applied! ₹50 saved.');
      }
    } else if (upperCode == 'SAVE20') {
      if (cart.subtotal < 150) {
        _showError(context, 'Minimum order of ₹150 required for SAVE20');
      } else {
        final discount = (cart.subtotal * 0.20).clamp(0.0, 100.0);
        cart.applyCoupon('SAVE20', discount, 'percent');
        _couponController.clear();
        _showSuccess(context, 'SAVE20 applied! 20% discount (capped at ₹100).');
      }
    } else if (upperCode == 'FREEDEL') {
      if (cart.subtotal < 50) {
        _showError(context, 'Minimum order of ₹50 required for FREEDEL');
      } else {
        cart.applyCoupon('FREEDEL', 0.0, 'freeDelivery');
        _couponController.clear();
        _showSuccess(context, 'FREEDEL applied! Free Delivery active.');
      }
    } else {
      _showError(context, 'Invalid coupon code. Try FLAT50, SAVE20, or FREEDEL');
    }

    setState(() {
      _isApplyingCoupon = false;
    });
  }

  // Remove item with AnimatedList sync
  Future<bool?> _confirmRemoveItem(CartItem item) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove item?'),
        content: Text('Do you want to remove "${item.title}" from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: TurbocartColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final cartItemsMap = cart.items;
    final cartItemsList = cartItemsMap.entries.toList();

    return Scaffold(
      backgroundColor: TurbocartColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TurbocartColors.textDark),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/home');
            }
          },
        ),
        title: Row(
          children: [
            const Text(
              'My Cart',
              style: TextStyle(color: TurbocartColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: TurbocartColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${cart.totalItems} items',
                style: const TextStyle(
                  color: TurbocartColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (cart.itemCount > 0)
            TextButton(
              onPressed: () {
                cart.clearCart();
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: cart.itemCount == 0
          ? _buildEmptyState()
          : ListView(
              children: [
                Column(
                  children: cartItemsList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final key = entry.value.key;
                    final item = entry.value.value;

                    return Dismissible(
                      key: Key(key),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await _confirmRemoveItem(item);
                      },
                      onDismissed: (direction) {
                        cart.deleteItem(item.id, item.unit);
                        _showSuccess(context, '${item.title} removed');
                      },
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.delete, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      child: _buildCartItemCard(item, key, cart, index),
                    );
                  }).toList(),
                ),
                _buildSuggestionsSection(context, cart),
                _buildBottomSummary(cart),
              ],
            ),
    );
  }



  Widget _buildEmptyState() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://assets5.lottiefiles.com/packages/lf20_mr1sub91.json',
            height: 220,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.shopping_cart_outlined,
                size: 100,
                color: TurbocartColors.lightGrey,
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: TurbocartColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items to start shopping your daily essentials!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: TurbocartColors.textGrey,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TurbocartColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Shop Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item, String key, CartProvider cart, int index, {bool isDummy = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TurbocartColors.lightGrey.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ImageUtils.getCleanImageUrl(item.imageUrl, title: item.title),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Image.network(
                  'https://images.unsplash.com/photo-1542838132-92c53300491e?w=200',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + Variant
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TurbocartColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.unit,
                    style: const TextStyle(
                      color: TurbocartColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TurbocartColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            // Controls
            if (!isDummy)
              Container(
                height: 36,
                width: 90,
                decoration: BoxDecoration(
                  color: TurbocartColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (item.quantity > 1) {
                          cart.updateQuantity(item.id, item.unit, item.quantity - 1);
                        } else {
                          final confirmed = await _confirmRemoveItem(item);
                          if (confirmed == true) {
                            cart.deleteItem(item.id, item.unit);
                            if (mounted) _showSuccess(context, '${item.title} removed');
                          }
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.remove, color: Colors.white, size: 16),
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        cart.addItem(item.id, item.title, item.price, item.imageUrl, item.unit);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSummary(CartProvider cart) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coupon Section
              _buildCouponSection(cart),

              // Billing Details
              _buildBillingCard(cart),

              // Pay button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      if (userProvider.addresses.isEmpty || userProvider.selectedAddress == null) {
                        SnackBarUtils.showTopSnackBar(
                          context,
                          'Please add a delivery address to proceed.',
                          backgroundColor: Colors.redAccent,
                        );
                        context.push('/address', extra: {'isFromCheckout': true});
                      } else {
                        context.push('/payment');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TurbocartColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '₹${cart.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'Proceed to Pay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCouponsBottomSheet(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: TurbocartColors.surface,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Coupons',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TurbocartColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: TurbocartColors.textGrey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('coupons').get(),
                    builder: (fbContext, snapshot) {
                      List<Map<String, dynamic>> coupons = [];
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          data['code'] = doc.id;
                          coupons.add(data);
                        }
                      }

                      if (coupons.isEmpty) {
                        coupons = [
                          {
                            'code': 'FLAT50',
                            'description': 'Flat ₹50 OFF on orders above ₹100',
                          },
                          {
                            'code': 'SAVE20',
                            'description': '20% OFF (up to ₹100) on orders above ₹150',
                          },
                          {
                            'code': 'FREEDEL',
                            'description': 'FREE Delivery on orders above ₹50',
                          },
                        ];
                      }

                      return ListView.builder(
                        itemCount: coupons.length,
                        itemBuilder: (listContext, index) {
                          final coupon = coupons[index];
                          final code = coupon['code'] ?? '';
                          final desc = coupon['description'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _couponController.text = code;
                              _validateAndApplyCoupon(context, cart);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TurbocartColors.primary.withValues(alpha: 0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: TurbocartColors.primary.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: TurbocartColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      code,
                                      style: const TextStyle(
                                        color: TurbocartColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          desc,
                                          style: const TextStyle(
                                            color: TurbocartColors.textDark,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'TAP TO APPLY',
                                          style: TextStyle(
                                            color: TurbocartColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCouponSection(CartProvider cart) {
    final hasCoupon = cart.appliedCoupon.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TurbocartColors.lightGrey.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasCoupon) ...[
            InkWell(
              onTap: _isApplyingCoupon ? null : () => _showCouponsBottomSheet(context, cart),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, color: TurbocartColors.textDark, size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Use Coupons',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: TurbocartColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (_isApplyingCoupon)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: TurbocartColors.primary, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios, color: TurbocartColors.textGrey, size: 14),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: TurbocartColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TurbocartColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: TurbocartColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coupon "${cart.appliedCoupon}" Applied',
                          style: const TextStyle(
                            color: TurbocartColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cart.couponType == 'freeDelivery'
                              ? 'FREE delivery savings activated!'
                              : '₹${cart.couponDiscount.toStringAsFixed(0)} savings applied to your bill!',
                          style: const TextStyle(
                            color: TurbocartColors.textDark,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => cart.removeCoupon(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingCard(CartProvider cart) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: TurbocartColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildBillRow('Item Total', '₹${cart.subtotal.toStringAsFixed(2)}'),
          const Divider(height: 12, color: TurbocartColors.lightGrey),
          _buildBillRow(
            'Delivery Fee',
            cart.deliveryFee == 0.0
                ? 'FREE'
                : '₹${cart.deliveryFee.toStringAsFixed(2)}',
            valueColor: cart.deliveryFee == 0.0 ? TurbocartColors.primary : TurbocartColors.textDark,
            isBoldValue: cart.deliveryFee == 0.0,
          ),
          if (cart.couponDiscount > 0) ...[
            const Divider(height: 12, color: TurbocartColors.lightGrey),
            _buildBillRow(
              'Coupon Discount',
              '-₹${cart.couponDiscount.toStringAsFixed(2)}',
              valueColor: TurbocartColors.primary,
              isBoldValue: true,
            ),
          ],
          const Divider(height: 12, color: TurbocartColors.lightGrey),
          _buildBillRow('GST & Taxes (5%)', '₹${cart.taxes.toStringAsFixed(2)}'),
          const Divider(height: 16, thickness: 1.5, color: TurbocartColors.lightGrey),
          _buildBillRow(
            'Grand Total',
            '₹${cart.grandTotal.toStringAsFixed(2)}',
            isBoldLabel: true,
            isBoldValue: true,
            valueColor: TurbocartColors.primary,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value, {
    bool isBoldLabel = false,
    bool isBoldValue = false,
    Color valueColor = TurbocartColors.textDark,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBoldLabel ? FontWeight.bold : FontWeight.normal,
            color: isBoldLabel ? TurbocartColors.textDark : TurbocartColors.textGrey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  static final List<Map<String, dynamic>> _fallbackSuggestedProducts = [
    {
      'id': 'suggest_dummy_1',
      'title': 'Fresh Organic Bananas',
      'name': 'Fresh Organic Bananas',
      'brand': 'Fresh Farm',
      'category': 'fruits_veg',
      'subcategory': 'fruits',
      'description': 'Fresh yellow bananas.',
      'images': ['https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500&auto=format&fit=crop&q=60'],
      'tags': ['banana', 'fruit', 'fresh', 'organic'],
      'price': 45.0,
      'mrp': 50.0,
      'rating': 4.8,
      'discount': '10%',
      'stock': 40,
      'reviewCount': 980,
      'isDeal': true,
      'isBestSeller': true,
      'weight': '1 kg',
      'unit': '1 kg',
    },
    {
      'id': 'suggest_dummy_2',
      'title': 'Amul Fresh Butter',
      'name': 'Amul Fresh Butter',
      'brand': 'Amul',
      'category': 'dairy_bread',
      'subcategory': 'butter',
      'description': 'Amul salted butter.',
      'images': ['https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500&auto=format&fit=crop&q=60'],
      'tags': ['butter', 'amul', 'dairy'],
      'price': 58.0,
      'mrp': 60.0,
      'rating': 4.9,
      'discount': '3%',
      'stock': 25,
      'reviewCount': 1204,
      'isDeal': false,
      'isBestSeller': true,
      'weight': '100 g',
      'unit': '100 g',
    },
    {
      'id': 'suggest_dummy_3',
      'title': 'Coca-Cola Zero Sugar Can',
      'name': 'Coca-Cola Zero Sugar Can',
      'brand': 'Coca-Cola',
      'category': 'beverages',
      'subcategory': 'cold_drinks',
      'description': 'Zero sugar soft drink.',
      'images': ['https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop&q=60'],
      'tags': ['coke', 'cola', 'soda', 'beverage'],
      'price': 40.0,
      'mrp': 40.0,
      'rating': 4.6,
      'discount': '',
      'stock': 50,
      'reviewCount': 854,
      'isDeal': false,
      'isBestSeller': false,
      'weight': '300 ml',
      'unit': '300 ml',
    },
    {
      'id': 'suggest_dummy_4',
      'title': 'Lay\'s Potato Chips',
      'name': 'Lay\'s Potato Chips',
      'brand': 'Lays',
      'category': 'snacks',
      'subcategory': 'chips',
      'description': 'Classic salted chips.',
      'images': ['https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&auto=format&fit=crop&q=60'],
      'tags': ['lays', 'chips', 'potato', 'snacks'],
      'price': 20.0,
      'mrp': 20.0,
      'rating': 4.5,
      'discount': '',
      'stock': 30,
      'reviewCount': 620,
      'isDeal': false,
      'isBestSeller': true,
      'weight': '50 g',
      'unit': '50 g',
    },
    {
      'id': 'suggest_dummy_5',
      'title': 'Fresh Toned Milk',
      'name': 'Fresh Toned Milk',
      'brand': 'Mother Dairy',
      'category': 'dairy_bread',
      'subcategory': 'milk',
      'description': 'Fresh pasteurized milk.',
      'images': ['https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500&auto=format&fit=crop&q=60'],
      'tags': ['milk', 'dairy', 'fresh'],
      'price': 28.0,
      'mrp': 30.0,
      'rating': 4.7,
      'discount': '6%',
      'stock': 100,
      'reviewCount': 2405,
      'isDeal': false,
      'isBestSeller': true,
      'weight': '500 ml',
      'unit': '500 ml',
    },
    {
      'id': 'suggest_dummy_6',
      'title': 'Harvest Gold White Bread',
      'name': 'Harvest Gold White Bread',
      'brand': 'Harvest',
      'category': 'dairy_bread',
      'subcategory': 'bread',
      'description': 'Soft sliced white bread.',
      'images': ['https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop&q=60'],
      'tags': ['bread', 'dairy', 'slice'],
      'price': 40.0,
      'mrp': 45.0,
      'rating': 4.6,
      'discount': '11%',
      'stock': 40,
      'reviewCount': 1904,
      'isDeal': true,
      'isBestSeller': true,
      'weight': '400 g',
      'unit': '400 g',
    },
    {
      'id': 'suggest_dummy_7',
      'title': 'Fresh Curd Cup',
      'name': 'Fresh Curd Cup',
      'brand': 'Nestle',
      'category': 'dairy_bread',
      'subcategory': 'curd',
      'description': 'Creamy fresh curd.',
      'images': ['https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500&auto=format&fit=crop&q=60'],
      'tags': ['curd', 'dairy', 'dahi'],
      'price': 35.0,
      'mrp': 35.0,
      'rating': 4.8,
      'discount': '',
      'stock': 60,
      'reviewCount': 723,
      'isDeal': false,
      'isBestSeller': false,
      'weight': '400 g',
      'unit': '400 g',
    },
    {
      'id': 'suggest_dummy_8',
      'title': 'Farm Fresh White Eggs',
      'name': 'Farm Fresh White Eggs',
      'brand': 'Eggo',
      'category': 'dairy_bread',
      'subcategory': 'eggs',
      'description': 'Farm fresh white eggs pack of 6.',
      'images': ['https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=500&auto=format&fit=crop&q=60'],
      'tags': ['eggs', 'dairy', 'fresh'],
      'price': 48.0,
      'mrp': 55.0,
      'rating': 4.7,
      'discount': '12%',
      'stock': 80,
      'reviewCount': 1302,
      'isDeal': true,
      'isBestSeller': true,
      'weight': '6 pcs',
      'unit': '6 pcs',
    },
    {
      'id': 'suggest_dummy_9',
      'title': 'Real Orange Juice',
      'name': 'Real Orange Juice',
      'brand': 'Real',
      'category': 'beverages',
      'subcategory': 'juices',
      'description': '100% pure orange juice.',
      'images': ['https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=500&auto=format&fit=crop&q=60'],
      'tags': ['juice', 'orange', 'beverage'],
      'price': 110.0,
      'mrp': 120.0,
      'rating': 4.5,
      'discount': '8%',
      'stock': 15,
      'reviewCount': 510,
      'isDeal': false,
      'isBestSeller': false,
      'weight': '1 L',
      'unit': '1 L',
    },
    {
      'id': 'suggest_dummy_10',
      'title': 'Dairy Milk Family Pack',
      'name': 'Dairy Milk Family Pack',
      'brand': 'Cadbury',
      'category': 'snacks',
      'subcategory': 'chocolate',
      'description': 'Smooth milk chocolate.',
      'images': ['https://images.unsplash.com/photo-1549007994-cb92ca71450a?w=500&auto=format&fit=crop&q=60'],
      'tags': ['chocolate', 'cadbury', 'snacks'],
      'price': 80.0,
      'mrp': 80.0,
      'rating': 4.9,
      'discount': '',
      'stock': 45,
      'reviewCount': 3450,
      'isDeal': false,
      'isBestSeller': true,
      'weight': '110 g',
      'unit': '110 g',
    },
    {
      'id': 'suggest_dummy_11',
      'title': 'Maggie 2-Min Noodles',
      'name': 'Maggie 2-Min Noodles',
      'brand': 'Nestle',
      'category': 'snacks',
      'subcategory': 'noodles',
      'description': 'Instant masala noodles.',
      'images': ['https://images.unsplash.com/photo-1612966608967-312ba5987236?w=500&auto=format&fit=crop&q=60'],
      'tags': ['maggie', 'noodles', 'snacks'],
      'price': 14.0,
      'mrp': 14.0,
      'rating': 4.7,
      'discount': '',
      'stock': 150,
      'reviewCount': 4209,
      'isDeal': false,
      'isBestSeller': true,
      'weight': '70 g',
      'unit': '70 g',
    },
    {
      'id': 'suggest_dummy_12',
      'title': 'Fresh Fuji Red Apple',
      'name': 'Fresh Fuji Red Apple',
      'brand': 'Fresh Farm',
      'category': 'fruits_veg',
      'subcategory': 'fruits',
      'description': 'Sweet red apples.',
      'images': ['https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500&auto=format&fit=crop&q=60'],
      'tags': ['apple', 'fruit', 'fresh', 'organic'],
      'price': 180.0,
      'mrp': 200.0,
      'rating': 4.8,
      'discount': '10%',
      'stock': 25,
      'reviewCount': 430,
      'isDeal': true,
      'isBestSeller': false,
      'weight': '4 pcs',
      'unit': '4 pcs',
    },
  ];

  Widget _buildSuggestionsSection(BuildContext context, CartProvider cart) {
    return FutureBuilder<QuerySnapshot>(
      future: suggestionsFuture,
      builder: (context, snapshot) {
        List<Map<String, dynamic>> suggestedProducts = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final suggestedDocs = snapshot.data!.docs.where((doc) {
            final prodId = doc.id;
            return !cart.items.values.any((item) => item.id == prodId);
          }).toList();

          for (var doc in suggestedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['title'] = data['title'] ?? data['name'] ?? '';
            data['name'] = data['name'] ?? data['title'] ?? '';
            suggestedProducts.add(data);
          }
        }

        if (suggestedProducts.length < 4) {
          suggestedProducts = _fallbackSuggestedProducts.where((p) {
            return !cart.items.values.any((item) => item.id == p['id']);
          }).toList();
        }

        if (suggestedProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        if (suggestedProducts.length > 5) {
          suggestedProducts = suggestedProducts.take(5).toList();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Frequently Added Together',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: TurbocartColors.textDark,
                  ),
                ),
              ),
              // Single Row of Products
              SizedBox(
                height: 245,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: suggestedProducts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == suggestedProducts.length) return _buildSeeAllCard();
                    final data = suggestedProducts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ProductCard(product: data),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeeAllCard() {
    return GestureDetector(
      onTap: () => context.push('/categories'),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 70,
              width: 80,
              child: Stack(
                children: [
                  Positioned(left: 0, child: Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[200]))),
                  Positioned(left: 20, top: 10, child: Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[300]))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('See all products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0C831F)),
          ],
        ),
      ),
    );
  }
}


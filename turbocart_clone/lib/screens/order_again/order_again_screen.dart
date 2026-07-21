import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/snackbar_utils.dart';

class OrderAgainScreen extends StatefulWidget {
  const OrderAgainScreen({super.key});

  @override
  State<OrderAgainScreen> createState() => _OrderAgainScreenState();
}

class _OrderAgainScreenState extends State<OrderAgainScreen> {
  final String _selectedFilter = 'All'; // Retained for compatibility with past orders query helper if any

  static final List<Product> _dummyProducts = [
    Product(
      id: 'dummy_1',
      name: 'Amul Taaza Fresh Toned Milk',
      brand: 'Amul',
      category: 'dairy',
      subcategory: 'milk',
      description: 'Fresh toned milk from Amul.',
      images: ['https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400'],
      tags: ['milk', 'dairy', 'amul'],
      price: 27.0,
      mrp: 28.0,
      rating: 4.8,
      discount: 3,
      stock: 10,
      reviewCount: 154,
      isDeal: true,
      isBestSeller: true,
      weight: '500',
      unit: 'ml',
    ),
    Product(
      id: 'dummy_2',
      name: 'Fortune Premium Kachi Ghani Pure Mustard Oil',
      brand: 'Fortune',
      category: 'grocery',
      subcategory: 'oil',
      description: 'Pure mustard oil.',
      images: ['https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400'],
      tags: ['oil', 'mustard', 'fortune'],
      price: 165.0,
      mrp: 185.0,
      rating: 4.7,
      discount: 10,
      stock: 12,
      reviewCount: 320,
      isDeal: false,
      isBestSeller: true,
      weight: '1',
      unit: 'L',
    ),
    Product(
      id: 'dummy_3',
      name: 'Tata Salt Iodized',
      brand: 'Tata',
      category: 'grocery',
      subcategory: 'salt',
      description: 'Iodized salt.',
      images: ['https://images.unsplash.com/photo-1594732152861-12501a3cf841?w=400'],
      tags: ['salt', 'tata'],
      price: 24.0,
      mrp: 25.0,
      rating: 4.9,
      discount: 4,
      stock: 25,
      reviewCount: 1200,
      isDeal: false,
      isBestSeller: false,
      weight: '1',
      unit: 'kg',
    ),
    Product(
      id: 'dummy_4',
      name: 'Lay\'s India\'s Magic Masala Potato Chips',
      brand: 'Lays',
      category: 'snacks',
      subcategory: 'chips',
      description: 'Crunchy potato chips.',
      images: ['https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400'],
      tags: ['chips', 'lays', 'snacks'],
      price: 20.0,
      mrp: 20.0,
      rating: 4.6,
      discount: 0,
      stock: 50,
      reviewCount: 450,
      isDeal: false,
      isBestSeller: false,
      weight: '50',
      unit: 'g',
    ),
    Product(
      id: 'dummy_5',
      name: 'Coca Cola Soft Drink',
      brand: 'Coca Cola',
      category: 'beverages',
      subcategory: 'cold drink',
      description: 'Refreshing cold drink.',
      images: ['https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400'],
      tags: ['coke', 'beverages', 'cold drink'],
      price: 40.0,
      mrp: 45.0,
      rating: 4.5,
      discount: 11,
      stock: 4,
      reviewCount: 88,
      isDeal: true,
      isBestSeller: false,
      weight: '750',
      unit: 'ml',
    ),
    Product(
      id: 'dummy_6',
      name: 'Maggi 2-Minute Masala Noodles',
      brand: 'Nestle',
      category: 'snacks',
      subcategory: 'noodles',
      description: '2-minute instant noodles.',
      images: ['https://images.unsplash.com/photo-1612927601601-6638404737ce?w=400'],
      tags: ['maggi', 'noodles', 'snacks'],
      price: 14.0,
      mrp: 14.0,
      rating: 4.8,
      discount: 0,
      stock: 100,
      reviewCount: 2300,
      isDeal: false,
      isBestSeller: true,
      weight: '70',
      unit: 'g',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSearchBar(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.itemCount == 0) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
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
              child: ElevatedButton(
                onPressed: () => context.push('/cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.totalQuantity} ITEM${cart.totalQuantity > 1 ? 'S' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '₹${cart.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Proceed to Cart',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TurboCart',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userProvider.deliveryTime,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.timer_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '24/7',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: Color(0xFF0C831F), size: 24),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: userProvider.photoUrl != null && userProvider.photoUrl!.isNotEmpty
                          ? NetworkImage(userProvider.photoUrl!)
                          : null,
                      child: (userProvider.photoUrl == null || userProvider.photoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => context.go('/address'),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFF0C831F), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${userProvider.addressLabel} - ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        userProvider.addressText.isNotEmpty ? userProvider.addressText : 'Set your delivery location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search previous orders...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(Icons.search,
                color: Colors.grey[400], size: 20),
            suffixIcon: Icon(Icons.mic_outlined,
                color: Colors.grey[400], size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      height: 130,
      width: double.infinity,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('banners')
            .doc('order_again_banner')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildDefaultBannerErrorWidget();
          }

          final bannerUrl = (snapshot.data!.data() as Map<String, dynamic>?)?['imageUrl'] ?? '';

          if (bannerUrl.isEmpty) {
            return _buildDefaultBannerErrorWidget();
          }

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  width: double.infinity,
                  height: 130,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[200]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultBannerErrorWidget(),
                ),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.local_offer_outlined,
                          size: 12, color: Color(0xFF0C831F)),
                      SizedBox(width: 4),
                      Text(
                        'Best Deals',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0C831F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultBannerErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0C831F),
            Color(0xFF065210),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Order Again',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your favourite products, reordered fast',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8C200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Delivery in 8 mins',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Order it again',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'All your favourite products',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.access_time,
                        size: 12, color: Color(0xFF0C831F)),
                    SizedBox(width: 4),
                    Text(
                      '8 mins',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0C831F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .orderBy('rating', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return _buildProductsGridShimmer();
            }

            final products = (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                ? _dummyProducts
                : snapshot.data!.docs
                    .map((d) => Product.fromMap(
                        d.id,
                        d.data() as Map<String, dynamic>))
                    .toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.58,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(products[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    int quantity = 0;
    bool isWishlisted = false;

    return StatefulBuilder(
      builder: (context, setCardState) {
        return GestureDetector(
          onTap: () => context.go(
            '/product/${product.id}',
            extra: product.toMap(),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: product.images.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.images.first,
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Shimmer.fromColors(
                                baseColor: Colors.grey[200]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  height: 130,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Container(
                              height: 130,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                    ),
                    if (product.discount > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C831F),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${product.discount.toInt()}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          setCardState(() {
                            isWishlisted = !isWishlisted;
                          });
                          SnackBarUtils.showTopSnackBar(
                            context,
                            isWishlisted
                                ? '${product.name} added to wishlist'
                                : 'Removed from wishlist',
                            backgroundColor: isWishlisted ? Colors.pinkAccent : Colors.grey,
                            duration: const Duration(seconds: 1),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isWishlisted ? Colors.red.shade50 : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: isWishlisted ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: quantity == 0
                            ? GestureDetector(
                                key: ValueKey('add_${product.id}'),
                                onTap: () {
                                  setCardState(() => quantity = 1);
                                  Provider.of<CartProvider>(
                                          context, listen: false)
                                      .addItem(
                                    product,
                                    product.weight,
                                    product.price,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF0C831F),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Text(
                                    'ADD',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0C831F),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                key: ValueKey('qty_${product.id}'),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C831F),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setCardState(() =>
                                            quantity = quantity > 0
                                                ? quantity - 1 : 0);
                                        if (quantity == 0) {
                                          Provider.of<CartProvider>(
                                                  context, listen: false)
                                              .removeItem(
                                            product.id,
                                            product.weight,
                                          );
                                        } else {
                                          Provider.of<CartProvider>(
                                                  context, listen: false)
                                              .updateQuantity(
                                            product.id,
                                            product.weight,
                                            quantity,
                                          );
                                        }
                                      },
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 5),
                                        child: Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setCardState(
                                            () => quantity++);
                                        Provider.of<CartProvider>(
                                                context, listen: false)
                                            .updateQuantity(
                                          product.id,
                                          product.weight,
                                          quantity,
                                        );
                                      },
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 5),
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.weight} ${product.unit}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '₹${product.price.toInt()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (product.mrp > product.price)
                            Text(
                              '₹${product.mrp.toInt()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                decoration:
                                    TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (product.mrp > product.price)
                        Text(
                          '${product.discount.toInt()}% OFF on MRP',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF0C831F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 11,
                              color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            product.rating
                                .toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.access_time,
                              size: 10,
                              color: Colors.grey),
                          const SizedBox(width: 2),
                          const Text(
                            '8 mins',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          if (product.stock <= 5 &&
                              product.stock > 0) ...[
                            const Spacer(),
                            Text(
                              '${product.stock} left',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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
  }

  Widget _buildProductsGridShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.58,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey[200]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBody() {
    return RefreshIndicator(
      color: const Color(0xFF0C831F),
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            _buildAllProductsSection(),
            const SizedBox(height: 24),
            _buildPastOrdersSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPastOrdersSection() {
    final userProvider = Provider.of<UserProvider>(context);
    final uid = userProvider.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Your past orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _buildFilteredQuery(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildOrderShimmer();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final orders = snapshot.data!.docs
                .map((d) => OrderModel.fromMap(
                    d.id, d.data() as Map<String, dynamic>))
                .toList();

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _buildPastOrderCard(orders[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPastOrderCard(OrderModel order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Order #${order.id.substring(0, min(8, order.id.length)).toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor(order.status)
                            .withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 48,
                  child: Stack(
                    children: List.generate(
                      min(3, order.items.length),
                      (i) {
                        final images = order.items[i].product.images;
                        return Positioned(
                          left: i * 30.0,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: images.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: images.first,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image, size: 20),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.items.length} items',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.items
                            .take(2)
                            .map((i) => i.product.name)
                            .join(', ') +
                            (order.items.length > 2
                                ? ' +${order.items.length - 2} more'
                                : ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${order.total.toInt()}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go(
                      '/order-detail', extra: order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF616161),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _reorder(order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C831F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Reorder',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildFilteredQuery(String uid) {
    var query = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    final now = DateTime.now();

    if (_selectedFilter == 'Last 7 days') {
      query = query.where('createdAt',
          isGreaterThan: Timestamp.fromDate(
              now.subtract(const Duration(days: 7))));
    } else if (_selectedFilter == 'Last 30 days') {
      query = query.where('createdAt',
          isGreaterThan: Timestamp.fromDate(
              now.subtract(const Duration(days: 30))));
    }

    return query.snapshots();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'placed': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'out_for_delivery': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _reorder(OrderModel order) async {
    final cart = Provider.of<CartProvider>(
        context, listen: false);
    for (final item in order.items) {
      cart.addItem(item.product, item.variant, item.price);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.items.length} items added to cart'),
        backgroundColor: const Color(0xFF0C831F),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () => context.go('/cart'),
        ),
      ),
    );
  }

  Widget _buildOrderShimmer() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 160,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Lottie.asset(
              'assets/lottie/empty_orders.json',
              width: 180,
              height: 180,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 180,
                height: 180,
                color: Colors.grey[100],
                child: const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No orders yet!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your past orders will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Start Shopping',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

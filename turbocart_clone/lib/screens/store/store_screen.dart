import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../utils/snackbar_utils.dart';

class StoreScreen extends StatelessWidget {
  final String storeId;
  const StoreScreen({super.key, required this.storeId});

  static final List<Product> _mockStoreProducts = [
    Product(
      id: 'store_dummy_1',
      name: 'Fresh Organic Bananas Robusta',
      brand: 'Fresh Farm',
      category: 'fruits_veg',
      subcategory: 'fruits',
      description: 'Fresh yellow bananas.',
      images: ['https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400'],
      tags: ['banana', 'fruit', 'fresh', 'organic'],
      price: 45.0,
      mrp: 50.0,
      rating: 4.8,
      discount: 10,
      stock: 40,
      reviewCount: 980,
      isDeal: true,
      isBestSeller: true,
      weight: '1',
      unit: 'kg',
    ),
    Product(
      id: 'store_dummy_2',
      name: 'Fortune Premium Pure Mustard Oil',
      brand: 'Fortune',
      category: 'grocery_kitchen',
      subcategory: 'grocery',
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
      id: 'store_dummy_3',
      name: 'Amul Taaza Fresh Toned Milk',
      brand: 'Amul',
      category: 'dairy_bread',
      subcategory: 'Milk',
      description: 'Fresh toned milk from Amul.',
      images: ['https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400'],
      tags: ['milk', 'dairy', 'amul', 'bread'],
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
  ];

  @override
  Widget build(BuildContext context) {
    // Generate some friendly store name based on storeId
    final String storeName = storeId.replaceAll('_', ' ').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                storeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.star, color: Color(0xFF0C831F), size: 14),
                            SizedBox(width: 4),
                            Text('4.5', style: TextStyle(color: Color(0xFF0C831F), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Text('Delivery in 10-15 mins', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Text('Min. Order ₹99', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your neighborhood superstore. Fresh groceries, daily essentials, snacks, personal care, and more, delivered straight to your door.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('storeId', isEqualTo: storeId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: _buildShimmer(),
                  );
                }

                List<Product> products = [];
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  products = snapshot.data!.docs
                      .map((d) => Product.fromMap(d.id, d.data() as Map<String, dynamic>))
                      .toList();
                } else {
                  products = _mockStoreProducts;
                }

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.58,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildProductCard(context, products[index]);
                    },
                    childCount: products.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.58,
        ),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
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
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: product.images.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.images.first,
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C831F),
                            borderRadius: BorderRadius.circular(4),
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
                                onTap: () {
                                  setCardState(() => quantity = 1);
                                  Provider.of<CartProvider>(context, listen: false).addItem(
                                    product,
                                    product.weight,
                                    product.price,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
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
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C831F),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setCardState(() => quantity = quantity > 0 ? quantity - 1 : 0);
                                        if (quantity == 0) {
                                          Provider.of<CartProvider>(context, listen: false).removeItem(
                                            product.id,
                                            product.weight,
                                          );
                                        } else {
                                          Provider.of<CartProvider>(context, listen: false).updateQuantity(
                                            product.id,
                                            product.weight,
                                            quantity,
                                          );
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                        child: Icon(Icons.remove, size: 14, color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setCardState(() => quantity++);
                                        Provider.of<CartProvider>(context, listen: false).updateQuantity(
                                          product.id,
                                          product.weight,
                                          quantity,
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                        child: Icon(Icons.add, size: 14, color: Colors.white),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          Flexible(
                            child: Text(
                              '₹${product.price.toInt()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (product.mrp > product.price)
                            Flexible(
                              child: Text(
                                '₹${product.mrp.toInt()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
}

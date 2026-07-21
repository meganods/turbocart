import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../constants/colors.dart';
import '../constants/dummy_products_seed.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../widgets/antigravity_wrapper.dart';

class CategoryProductsScreen extends StatelessWidget {
  final String categoryId;
  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    // Normalise category ID for comparison
    final targetCategory = categoryId.toLowerCase().trim();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7F2),
            appBar: AppBar(
              title: Text(_formatCategoryName(categoryId), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: Colors.white,
              foregroundColor: TurbocartColors.textDark,
              elevation: 0.5,
            ),
            body: const Center(child: CircularProgressIndicator(color: TurbocartColors.primary)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7F2),
            appBar: AppBar(
              title: Text(_formatCategoryName(categoryId), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: Colors.white,
              foregroundColor: TurbocartColors.textDark,
              elevation: 0.5,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text('Error loading products. Please try again.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: TurbocartColors.primary),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        List<Product> products = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          products = snapshot.data!.docs.map((doc) {
            return Product.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).where((p) {
            final cat = p.category.toLowerCase().trim();
            final sub = p.subcategory.toLowerCase().trim();
            final tags = p.tags.map((t) => t.toLowerCase().trim()).toList();
            
            return cat == targetCategory || 
                   sub == targetCategory || 
                   targetCategory.contains(cat) || 
                   targetCategory.contains(sub) ||
                   tags.contains(targetCategory);
          }).toList();
        }

        // Fallback to local products if empty
        if (products.isEmpty) {
          products = dummyProductsSeed.where((p) {
            final cat = p.category.toLowerCase().trim();
            final sub = p.subcategory.toLowerCase().trim();
            final tags = p.tags.map((t) => t.toLowerCase().trim()).toList();
            
            return cat == targetCategory || 
                   sub == targetCategory || 
                   targetCategory.contains(cat) || 
                   targetCategory.contains(sub) ||
                   tags.contains(targetCategory);
          }).toList();
        }

        // Ultimate fallback (show some items if absolutely no match)
        if (products.isEmpty) {
          products = dummyProductsSeed.take(10).toList();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F2),
          appBar: AppBar(
            title: Text(
              _formatCategoryName(categoryId),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            backgroundColor: Colors.white,
            foregroundColor: TurbocartColors.textDark,
            elevation: 0.5,
          ),
          body: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.60,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return AntigravityWrapper(
                      key: ValueKey('${product.id}_$index'),
                      index: index,
                      category: product.category,
                      animateEntrance: true,
                      enableFloat: false,
                      child: ProductCard(
                        product: product.toMap(overrideId: product.id),
                        enableFloat: false,
                        width: null,
                      ),
                    );
                  },
                ),
              ),
              // Sticky bottom cart summary panel
              Consumer<CartProvider>(
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
            ],
          ),
        );
      },
    );
  }

  String _formatCategoryName(String id) {
    final clean = id.replaceAll('_', ' ').replaceAll('\n', ' ');
    if (clean.isEmpty) return 'Products';
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

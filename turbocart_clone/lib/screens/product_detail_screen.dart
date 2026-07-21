import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart'; // import to reuse ProductCard
import '../utils/snackbar_utils.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _pageController = PageController();
  int _selectedVariantIndex = 0;
  bool _isWishlisted = false;

  final List<String> _variants = ['250 g', '500 g', '1 kg'];
  final List<double> _variantPriceMultipliers = [0.6, 1.0, 1.8];

  // Static recommendations fallback
  final List<Map<String, dynamic>> _mockProducts = [
    {
      'id': 'p1',
      'title': 'Fresh Organic Tomatoes',
      'price': 45.0,
      'mrp': 60.0,
      'unit': '500 g',
      'image': 'https://cdn.pixabay.com/photo/2011/03/16/16/01/tomatoes-5356_1280.jpg',
      'categoryId': 'cat1',
      'isDeal': true,
      'isBestSeller': false,
      'discount': '25% OFF',
    },
    {
      'id': 'p2',
      'title': 'Amul Pure Butter',
      'price': 105.0,
      'mrp': 115.0,
      'unit': '100 g',
      'image': 'https://cdn.pixabay.com/photo/2016/04/11/17/47/butter-1322649_1280.jpg',
      'categoryId': 'cat2',
      'isDeal': true,
      'isBestSeller': true,
      'discount': '10% OFF',
    },
    {
      'id': 'p3',
      'title': 'Lay\'s Salted Chips',
      'price': 20.0,
      'mrp': 20.0,
      'unit': '50 g',
      'image': 'https://cdn.pixabay.com/photo/2016/09/26/16/43/chips-1696395_1280.jpg',
      'categoryId': 'cat3',
      'isDeal': false,
      'isBestSeller': true,
      'discount': '',
    },
    {
      'id': 'p4',
      'title': 'Haldiram\'s Bhujia',
      'price': 100.0,
      'mrp': 110.0,
      'unit': '400 g',
      'image': 'https://images.unsplash.com/photo-1600860368149-fb399bd68eb7?w=300',
      'categoryId': 'cat4',
      'isDeal': true,
      'isBestSeller': true,
      'discount': '9% OFF',
    },
    {
      'id': 'p5',
      'title': 'Parle-G Gold',
      'price': 50.0,
      'mrp': 50.0,
      'unit': '1 kg',
      'image': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=300',
      'categoryId': 'cat5',
      'isDeal': false,
      'isBestSeller': true,
      'discount': '',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final productId = widget.product['id'] as String;
    final String variantUnit = _variants[_selectedVariantIndex];



    final double basePrice = (widget.product['price'] as num).toDouble();
    final double baseMrp = (widget.product['mrp'] as num).toDouble();
    final double price = basePrice * _variantPriceMultipliers[_selectedVariantIndex];
    final double mrp = baseMrp * _variantPriceMultipliers[_selectedVariantIndex];
    final double discountPercent = mrp > price ? ((mrp - price) / mrp * 100) : 0;

    // Carousel Image List (multiplied mock images for PageView gallery)
    final List<String> imageUrls = [
      (widget.product['image'] ?? (widget.product['images'] is List && widget.product['images'].isNotEmpty ? widget.product['images'][0] : '') ?? '').toString(),
      'https://cdn.pixabay.com/photo/2015/05/04/10/16/vegetables-752185_1280.jpg',
      'https://cdn.pixabay.com/photo/2016/08/11/08/04/vegetables-1584999_1280.jpg',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. SliverAppBar (Gallery + Controls)
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0.5,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: TurbocartColors.textDark),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: TurbocartColors.textDark),
                    onPressed: () {
                      SnackBarUtils.showTopSnackBar(
                        context,
                        'Share feature coming soon!',
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: _isWishlisted ? Colors.redAccent : TurbocartColors.textDark,
                    ),
                    onPressed: () {
                      setState(() {
                        _isWishlisted = !_isWishlisted;
                      });
                      SnackBarUtils.showTopSnackBar(
                        context,
                        _isWishlisted ? 'Added to wishlist' : 'Removed from wishlist',
                        backgroundColor: TurbocartColors.primary,
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Hero(
                        tag: 'product-image-$productId',
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: imageUrls.length,
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: imageUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: imageUrls.length,
                          effect: const WormEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            activeDotColor: TurbocartColors.primary,
                            dotColor: TurbocartColors.lightGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand & Name
                      const Text(
                        'Groceries & Fresh Products',
                        style: TextStyle(color: TurbocartColors.textGrey, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.product['title'] ?? widget.product['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: TurbocartColors.textDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rating & Reviews row
                      Row(
                        children: [
                          Row(
                            children: List.generate(5, (index) {
                              return const Icon(Icons.star, color: Colors.amber, size: 16);
                            }),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '4.8',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(234 reviews)',
                            style: TextStyle(color: TurbocartColors.textGrey, fontSize: 12),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Variant Selector (Weight)
                      const Text(
                        'Select Pack Size:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: TurbocartColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        children: List.generate(_variants.length, (index) {
                          final variant = _variants[index];
                          final isSelected = _selectedVariantIndex == index;

                          return ChoiceChip(
                            label: Text(variant),
                            selected: isSelected,
                            selectedColor: TurbocartColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : TurbocartColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedVariantIndex = index;
                                });
                              }
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Price Details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: TurbocartColors.textDark),
                          ),
                          const SizedBox(width: 10),
                          if (mrp > price) ...[
                            Text(
                              'MRP ₹${mrp.toStringAsFixed(0)}',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: TurbocartColors.textGrey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: TurbocartColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${discountPercent.toStringAsFixed(0)}% OFF',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: TurbocartColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 32),

                      // About this product (displayed directly)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About this product',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TurbocartColors.textDark),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.product['description'] ?? 'Premium quality product fetched straight from local organic cultivators. Freshly packaged under strict hygiene protocols to preserve its health assets and nutritional standards.',
                            style: const TextStyle(color: TurbocartColors.textGrey, fontSize: 13, height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Recommendations horizontal scroll
                      const Text(
                        'You may also like',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: TurbocartColors.textDark),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 230,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _mockProducts.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _mockProducts.length) return _buildSeeAllCard();
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ProductCard(product: _mockProducts[index]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 100), // extra padding for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Sticky Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: cart.itemCount > 0
                    ? SizedBox(
                        key: const ValueKey('proceed_to_cart_btn'),
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => context.push('/cart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C831F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${cart.totalQuantity} item${cart.totalQuantity > 1 ? 's' : ''} in cart',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Row(
                                children: [
                                  Text(
                                    'Proceed to Cart',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        key: const ValueKey('add_to_cart_btn'),
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            cart.addItem(
                              productId,
                              (widget.product['title'] ?? widget.product['name'] ?? '').toString(),
                              price,
                              (widget.product['image'] ?? (widget.product['images'] is List && widget.product['images'].isNotEmpty ? widget.product['images'][0] : '') ?? '').toString(),
                              variantUnit,
                            );
                            SnackBarUtils.showTopSnackBar(
                              context,
                              'Added to cart!',
                              backgroundColor: TurbocartColors.primary,
                              duration: const Duration(seconds: 1),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TurbocartColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeeAllCard() {
    return GestureDetector(
      onTap: () => context.push('/categories'),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(vertical: 8),
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

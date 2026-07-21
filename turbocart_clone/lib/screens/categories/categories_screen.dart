import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' as math;
import '../../models/product_model.dart';
import '../../constants/dummy_products_seed.dart';
import '../../widgets/product_card.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  String _selectedCategoryName = 'Grocery & Kitchen';
  String _searchText = '';
  bool _isChangingCategory = false;
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  // Accordion State and Animation Controllers
  bool _isCategoryExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  // Antigravity floating controllers for the accordion grid items
  late AnimationController _floatController;

  final List<Map<String, dynamic>> _mainCategories = [
    {
      'id': 'grocery_kitchen',
      'name': 'Grocery &\nKitchen',
      'icon': Icons.local_grocery_store_outlined,
      'color': const Color(0xFFE8F5E9),
    },
    {
      'id': 'snacks_drinks',
      'name': 'Snacks &\nDrinks',
      'icon': Icons.fastfood_outlined,
      'color': const Color(0xFFFFF8E1),
    },
    {
      'id': 'beauty_care',
      'name': 'Beauty &\nCare',
      'icon': Icons.face_retouching_natural,
      'color': const Color(0xFFFCE4EC),
    },
    {
      'id': 'household',
      'name': 'Household',
      'icon': Icons.home_outlined,
      'color': const Color(0xFFE3F2FD),
    },
    {
      'id': 'dairy_bread',
      'name': 'Dairy &\nBread',
      'icon': Icons.egg_outlined,
      'color': const Color(0xFFFFF3E0),
    },
    {
      'id': 'fruits_veg',
      'name': 'Fruits &\nVeggies',
      'icon': Icons.eco_outlined,
      'color': const Color(0xFFE8F5E9),
    },
    {
      'id': 'meat_fish',
      'name': 'Meat &\nFish',
      'icon': Icons.set_meal_outlined,
      'color': const Color(0xFFFFEBEE),
    },
    {
      'id': 'pharmacy',
      'name': 'Pharmacy',
      'icon': Icons.medical_services_outlined,
      'color': const Color(0xFFE8F5E9),
    },
    {
      'id': 'baby_care',
      'name': 'Baby\nCare',
      'icon': Icons.child_care_outlined,
      'color': const Color(0xFFE3F2FD),
    },
    {
      'id': 'electronics',
      'name': 'Electronics',
      'icon': Icons.devices_outlined,
      'color': const Color(0xFFEDE7F6),
    },
    {
      'id': 'stationery',
      'name': 'Stationery',
      'icon': Icons.edit_outlined,
      'color': const Color(0xFFFFF9C4),
    },
    {
      'id': 'pet_care',
      'name': 'Pet\nCare',
      'icon': Icons.pets_outlined,
      'color': const Color(0xFFFCE4EC),
    },
    {
      'id': 'fashion',
      'name': 'Fashion',
      'icon': Icons.checkroom_outlined,
      'color': const Color(0xFFE8EAF6),
    },
    {
      'id': 'toys_games',
      'name': 'Toys &\nGames',
      'icon': Icons.sports_esports_outlined,
      'color': const Color(0xFFFFF8E1),
    },
    {
      'id': 'sports',
      'name': 'Sports',
      'icon': Icons.sports_soccer_outlined,
      'color': const Color(0xFFE8F5E9),
    },
    {
      'id': 'books',
      'name': 'Books',
      'icon': Icons.menu_book_outlined,
      'color': const Color(0xFFFFF3E0),
    },
    {
      'id': 'gifting',
      'name': 'Gifting',
      'icon': Icons.card_giftcard_outlined,
      'color': const Color(0xFFFFEBEE),
    },
  ];

  final Map<String, List<Map<String, dynamic>>> _subcategories = {
    'grocery_kitchen': [
      {'name': 'Vegetables\n& Fruits', 'icon': Icons.eco_outlined, 'color': const Color(0xFFE8F5E9)},
      {'name': 'Atta, Rice\n& Dal', 'icon': Icons.grain_outlined, 'color': const Color(0xFFFFF8E1)},
      {'name': 'Oil, Ghee\n& Masala', 'icon': Icons.local_dining_outlined, 'color': const Color(0xFFFFF3E0)},
      {'name': 'Dairy, Bread\n& Eggs', 'icon': Icons.egg_outlined, 'color': const Color(0xFFF3E5F5)},
      {'name': 'Bakery &\nBiscuits', 'icon': Icons.cake_outlined, 'color': const Color(0xFFFCE4EC)},
      {'name': 'Dry Fruits\n& Cereals', 'icon': Icons.set_meal_outlined, 'color': const Color(0xFFFFF8E1)},
      {'name': 'Chicken,\nMeat & Fish', 'icon': Icons.restaurant_outlined, 'color': const Color(0xFFFFEBEE)},
      {'name': 'Kitchenware', 'icon': Icons.kitchen_outlined, 'color': const Color(0xFFE3F2FD)},
      {'name': 'Instant\nFood', 'icon': Icons.fastfood_outlined, 'color': const Color(0xFFFFF3E0)},
    ],
    'snacks_drinks': [
      {'name': 'Chips &\nNamkeen', 'icon': Icons.fastfood_outlined, 'color': const Color(0xFFFFF8E1)},
      {'name': 'Sweets &\nChocolates', 'icon': Icons.icecream_outlined, 'color': const Color(0xFFFCE4EC)},
      {'name': 'Drinks &\nJuices', 'icon': Icons.local_drink_outlined, 'color': const Color(0xFFE3F2FD)},
    ],
    'electronics': [
      {'name': 'Smartphones', 'icon': Icons.phone_android_outlined, 'color': const Color(0xFFEDE7F6)},
      {'name': 'Audio', 'icon': Icons.headphones_outlined, 'color': const Color(0xFFE8F5E9)},
      {'name': 'Cables', 'icon': Icons.cable_outlined, 'color': const Color(0xFFFFF3E0)},
      {'name': 'Chargers', 'icon': Icons.power_outlined, 'color': const Color(0xFFFFEBEE)},
      {'name': 'Wearables', 'icon': Icons.watch_outlined, 'color': const Color(0xFFE3F2FD)},
    ],
    'beauty_care': [
      {'name': 'Makeup', 'icon': Icons.brush_outlined, 'color': const Color(0xFFFCE4EC)},
      {'name': 'Skincare', 'icon': Icons.face_outlined, 'color': const Color(0xFFE8F5E9)},
      {'name': 'Haircare', 'icon': Icons.spa_outlined, 'color': const Color(0xFFE3F2FD)},
    ],
    'household': [
      {'name': 'Detergents', 'icon': Icons.clean_hands_outlined, 'color': const Color(0xFFE3F2FD)},
      {'name': 'Cleaners', 'icon': Icons.cleaning_services_outlined, 'color': const Color(0xFFFFF9C4)},
    ],
    'dairy_bread': [
      {'name': 'Milk', 'icon': Icons.local_cafe_outlined, 'color': const Color(0xFFFFF3E0)},
      {'name': 'Bread', 'icon': Icons.breakfast_dining_outlined, 'color': const Color(0xFFFFF9C4)},
      {'name': 'Eggs', 'icon': Icons.egg_outlined, 'color': const Color(0xFFFFEBEE)},
    ],
    'fruits_veg': [
      {'name': 'Fresh Fruits', 'icon': Icons.apple_outlined, 'color': const Color(0xFFE8F5E9)},
      {'name': 'Vegetables', 'icon': Icons.eco_outlined, 'color': const Color(0xFFFFF9C4)},
    ],
    'meat_fish': [
      {'name': 'Chicken', 'icon': Icons.restaurant_outlined, 'color': const Color(0xFFFFEBEE)},
      {'name': 'Fish', 'icon': Icons.set_meal_outlined, 'color': const Color(0xFFE3F2FD)},
    ],
  };

  static final List<Product> _dummyProducts = dummyProductsSeed;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arrowAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _expandController.dispose();
    _arrowController.dispose();
    _floatController.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TurboCart',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600])),
                        Row(children: [
                          Text(
                            userProvider.deliveryTime,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
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
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('24/7',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600]))),
                        ]),
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
                child: Row(children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFF0C831F), size: 14),
                  const SizedBox(width: 4),
                  Text('${userProvider.addressLabel} - ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: Text(
                      userProvider.addressText.isNotEmpty ? userProvider.addressText : 'Set your delivery location',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey, size: 16),
                ]),
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
      child: TextField(
        onChanged: (val) => setState(() => _searchText = val),
        decoration: InputDecoration(
          hintText: 'Search categories and products...',
          hintStyle: TextStyle(
              fontSize: 14, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search,
              color: Colors.grey[400], size: 20),
          suffixIcon: _searchText.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _searchText = ''),
                  child: Icon(Icons.close,
                      color: Colors.grey[400], size: 18))
              : Icon(Icons.mic_outlined,
                  color: Colors.grey[400], size: 20),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF0C831F), width: 1)),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searchText.isNotEmpty) {
      return _buildSearchResults();
    }
    return Row(
      children: [
        _buildLeftSidebar(),
        Expanded(child: _buildRightContent()),
      ],
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 82,
      color: const Color(0xFFF0F0F0),
      child: ListView.builder(
        controller: _leftScrollController,
        padding: EdgeInsets.zero,
        itemCount: _mainCategories.length,
        itemBuilder: (context, index) {
          final cat = _mainCategories[index];
          final isSelected = _selectedCategoryIndex == index;

          return GestureDetector(
                onTap: () {
                  if (_selectedCategoryIndex == index) return;
                  if (_isCategoryExpanded) {
                    setState(() {
                      _isCategoryExpanded = false;
                    });
                    _expandController.reverse();
                    _arrowController.reverse();
                  }
                  setState(() {
                    _selectedCategoryIndex = index;
                    _selectedCategoryName = cat['name']
                        .toString().replaceAll('\n', ' ');
                  });
                  _rightScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0C831F)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cat['color']
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          cat['icon'],
                          size: 20,
                          color: isSelected
                              ? const Color(0xFF0C831F)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['name'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF0C831F)
                              : const Color(0xFF757575),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildRightContent() {
    final themeColor = _mainCategories[_selectedCategoryIndex]['color'] ?? Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: themeColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          key: ValueKey<int>(_selectedCategoryIndex),
          controller: _rightScrollController,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryBanner(),
              _buildAccordionButton(),
              _buildAccordionSubcategoriesGrid(),
              _buildCategoryProducts(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBanner() {
    final cat = _mainCategories[_selectedCategoryIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey('banner_$_selectedCategoryIndex'),
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: cat['color'],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedCategoryName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C831F),
                          ),
                        ),
                        const Text(
                          'Best deals on all products',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Spacing to keep content clear of the floaty cart badge in the top right
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Floating Cart Badge (Part 7)
            Positioned(
              top: 14,
              right: 14,
              child: Consumer<CartProvider>(
                builder: (context, cart, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/cart'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Color(0xFF0C831F),
                            size: 20,
                          ),
                        ),
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0C831F),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                '${cart.itemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Part 1: Accordion Header Button Design
  Widget _buildAccordionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: GestureDetector(
        onTap: () {
          if (_isCategoryExpanded) {
            setState(() {
              _isCategoryExpanded = false;
            });
            _expandController.reverse();
            _arrowController.reverse();
          } else {
            setState(() {
              _isCategoryExpanded = true;
            });
            _expandController.forward();
            _arrowController.forward();
          }
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop by category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Best deals on all products',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _arrowAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _arrowAnimation.value * 2 * math.pi,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Color(0xFF0C831F),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Part 2, 3, 5 & 9: Collapsible grid view with stagger and antigravity floating bob animations
  Widget _buildAccordionSubcategoriesGrid() {
    final subs = _subcategories[_mainCategories[_selectedCategoryIndex]['id']] ?? [];
    if (subs.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double heightVal = _expandAnimation.value * 340.0;
        return Opacity(
          opacity: _expandAnimation.value,
          child: ClipRect(
            child: SizedBox(
              height: heightVal,
              child: child,
            ),
          ),
        );
      },
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: subs.length,
            itemBuilder: (context, index) {
              final sub = subs[index];
              final int row = index ~/ 3;

              // Row staggered entrance delays
              double delay = 0.1;
              if (row == 1) delay = 0.18;
              if (row == 2) delay = 0.26;

              return AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, cardChild) {
                  final double startRatio = delay;
                  final double endRatio = (delay + 0.25).clamp(0.0, 1.0);
                  double localRatio = 0.0;
                  if (_expandAnimation.value > startRatio) {
                    localRatio = ((_expandAnimation.value - startRatio) / (endRatio - startRatio)).clamp(0.0, 1.0);
                  }
                  final double slideY = (1.0 - localRatio) * 15.0;
                  return Opacity(
                    opacity: localRatio,
                    child: Transform.translate(
                      offset: Offset(0, slideY),
                      child: cardChild,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () => context.push(
                    '/subcategory/${Uri.encodeComponent(sub['name'].toString().replaceAll('\n', ' '))}',
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: sub['color'],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                          ),
                          child: Center(
                            // Part 9: Subcategory Icon Floating Bob Animation
                            child: AnimatedBuilder(
                              animation: _floatController,
                              builder: (context, iconChild) {
                                final double phaseOffset = index * 250.0;
                                final double radians = (_floatController.value * 2 * math.pi) + (phaseOffset / 1000.0);
                                final double offsetBob = math.sin(radians) * 3.0;
                                return Transform.translate(
                                  offset: Offset(0, offsetBob),
                                  child: iconChild,
                                );
                              },
                              child: Icon(
                                sub['icon'],
                                size: 28,
                                color: const Color(0xFF0C831F),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        sub['name'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryProducts() {
    final categoryId = _mainCategories[_selectedCategoryIndex]['id'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Popular in $_selectedCategoryName',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.go(
                  '/category', extra: {'categoryId': categoryId}
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0C831F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
              .collection('products')
              .where('category', isEqualTo: categoryId)
              .limit(12)
              .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildProductsShimmer();
              }

              List<Product> products = [];
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                products = snapshot.data!.docs.map((doc) {
                  return Product.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                }).toList();
              }

              if (products.isEmpty) {
                products = _dummyProducts.where((p) => p.category == categoryId).toList();
              }

              if (products.isEmpty) {
                return _buildNoProducts();
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.53,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ProductCard(
                    product: product.toMap(overrideId: product.id),
                    enableFloat: false,
                    width: null,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final query = _searchText.toLowerCase().trim();
    final results = _dummyProducts.where((p) {
      final title = p.name.toLowerCase();
      final category = p.category.toLowerCase();
      final subcategory = p.subcategory.toLowerCase();
      return title.contains(query) ||
             category.contains(query) ||
             subcategory.contains(query);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No matching products found.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.53,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final product = results[index];
        return ProductCard(
          product: product.toMap(overrideId: product.id),
          enableFloat: false,
          width: null,
        );
      },
    );
  }

  Widget _buildProductsShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.53,
      ),
      itemCount: 4,
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
    );
  }

  Widget _buildNoProducts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No products in this category yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';


import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../models/category_theme.dart';
import '../widgets/category_animation.dart';
import '../widgets/product_card.dart';
import '../widgets/address_row.dart';
import '../widgets/antigravity_cart_badge.dart';
import '../widgets/antigravity_wrapper.dart';

class HomeStorefront extends StatefulWidget {
  final VoidCallback onCheckout;
  const HomeStorefront({super.key, required this.onCheckout});

  @override
  State<HomeStorefront> createState() => _HomeStorefrontState();
}

class _HomeStorefrontState extends State<HomeStorefront>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  int _bannerIndex = 0;
  final ScrollController _tabScrollController = ScrollController();

  // Tab transition animation
  late AnimationController _contentExitController;
  late AnimationController _contentEnterController;
  late Animation<double> _exitOpacity;
  late Animation<double> _exitTranslation;
  late Animation<double> _enterOpacity;
  late Animation<double> _enterTranslation;
  bool _isChangingTab = false;
  bool _contentVisible = true;

  // Product pagination per tab
  final Map<String, int> _loadedCount = {};
  static const int _pageSize = 12;

  final List<CategoryTheme> _themes = [
    CategoryTheme(
      id: 'all',
      name: 'All',
      bannerBgColor: const Color(0xFFF7C323),
      headerBgColor: const Color(0xFFF7C323),
      searchHint: 'Search "sweets"',
      sectionTitle: 'Top picks for you',
      sectionSubtitle: 'Everything you need',
      bannerImageUrl: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/14595-thumbs-up.json',
      subcategories: [
        SubCategoryCard(title: 'DAILY GROCERY', imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400', cardSize: 'large', price: 99),
        SubCategoryCard(title: 'Snacks', imageUrl: 'https://images.unsplash.com/photo-1599490659213-e2b9527bd087?w=400'),
        SubCategoryCard(title: 'Drinks', imageUrl: 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400'),
        SubCategoryCard(title: 'Bakery', imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400'),
        SubCategoryCard(title: 'Meat', imageUrl: 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'vacations',
      name: 'Vacations',
      bannerBgColor: const Color(0xFF31A1E8),
      headerBgColor: const Color(0xFF31A1E8),
      searchHint: 'Search "travel essentials"',
      sectionTitle: 'Endless fun for busy minds',
      sectionSubtitle: 'Smart picks to keep the kids on track',
      bannerImageUrl: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/tent.json',
      subcategories: [
        SubCategoryCard(title: 'KIDS AT HOME', imageUrl: 'https://images.unsplash.com/photo-1502086223501-7ea6ecd79368?w=400', cardSize: 'large', price: 129, mrp: 399),
        SubCategoryCard(title: 'Family Vacation', imageUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=400'),
        SubCategoryCard(title: 'Sports & Activities', imageUrl: 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=400'),
        SubCategoryCard(title: 'Hobby & Skills', imageUrl: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=400'),
        SubCategoryCard(title: 'Children\'s Books', imageUrl: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'electronics',
      name: 'Electronics',
      bannerBgColor: const Color(0xFFFFFFFF),
      headerBgColor: const Color(0xFFFFFFFF),
      searchHint: 'Search "headphones"',
      sectionTitle: 'Tech essentials',
      sectionSubtitle: 'Gadgets and gear',
      bannerImageUrl: 'https://images.unsplash.com/photo-1468495244123-6c6c332eeece?w=600',
      subcategories: [
        SubCategoryCard(title: 'SMARTPHONES', imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400', cardSize: 'large', price: 12999),
        SubCategoryCard(title: 'Audio', imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400'),
        SubCategoryCard(title: 'Cables', imageUrl: 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=400'),
        SubCategoryCard(title: 'Chargers', imageUrl: 'https://images.unsplash.com/photo-1622445262465-2481c457487f?w=400'),
        SubCategoryCard(title: 'Wearables', imageUrl: 'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'beauty',
      name: 'Beauty',
      bannerBgColor: const Color(0xFFD49093),
      headerBgColor: const Color(0xFFD49093),
      searchHint: 'Search "lipstick"',
      sectionTitle: 'Glow up essentials',
      sectionSubtitle: 'Best in beauty',
      bannerImageUrl: 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/LottieLogo1.json',
      subcategories: [
        SubCategoryCard(title: 'MAKEUP', imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400', cardSize: 'large', price: 499),
        SubCategoryCard(title: 'Skincare', imageUrl: 'https://images.unsplash.com/photo-1556228841-a3c527ebefe5?w=400'),
        SubCategoryCard(title: 'Haircare', imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400'),
        SubCategoryCard(title: 'Fragrances', imageUrl: 'https://images.unsplash.com/photo-1547887537-6158d64c35b3?w=400'),
        SubCategoryCard(title: 'Bath & Body', imageUrl: 'https://images.unsplash.com/photo-1515377905703-c4788e51af15?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'pharmacy',
      name: 'Pharmacy',
      bannerBgColor: const Color(0xFFC9F0E1),
      headerBgColor: const Color(0xFFC9F0E1),
      searchHint: 'Search "medicines"',
      sectionTitle: 'Wellness basics',
      sectionSubtitle: 'Stay healthy',
      bannerImageUrl: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=600',
      subcategories: [
        SubCategoryCard(title: 'MEDICINES', imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400', cardSize: 'large', price: 150),
        SubCategoryCard(title: 'Supplements', imageUrl: 'https://images.unsplash.com/photo-1584017911766-d451b3d0e843?w=400'),
        SubCategoryCard(title: 'First Aid', imageUrl: 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=400'),
        SubCategoryCard(title: 'Personal Care', imageUrl: 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=400'),
        SubCategoryCard(title: 'Baby Care', imageUrl: 'https://images.unsplash.com/photo-1519689680058-324335c77ebe?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'decor',
      name: 'Decor',
      bannerBgColor: const Color(0xFFF3E1CB),
      headerBgColor: const Color(0xFFF3E1CB),
      searchHint: 'Search "lamps"',
      sectionTitle: 'Home makeover',
      sectionSubtitle: 'Cozy vibes',
      bannerImageUrl: 'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/blub.json',
      subcategories: [
        SubCategoryCard(title: 'LIGHTING', imageUrl: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=400', cardSize: 'large', price: 899),
        SubCategoryCard(title: 'Cushions', imageUrl: 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=400'),
        SubCategoryCard(title: 'Wall Art', imageUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=400'),
        SubCategoryCard(title: 'Plants', imageUrl: 'https://images.unsplash.com/photo-1485955900006-10f4d324d411?w=400'),
        SubCategoryCard(title: 'Rugs', imageUrl: 'https://images.unsplash.com/photo-1600166898405-da9535204843?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'kids',
      name: 'Kids',
      bannerBgColor: const Color(0xFFD4E7F2),
      headerBgColor: const Color(0xFFD4E7F2),
      searchHint: 'Search "toys"',
      sectionTitle: 'Fun & play',
      sectionSubtitle: 'For the little ones',
      bannerImageUrl: 'https://images.unsplash.com/photo-1485546246426-74dc88dec4d9?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/HamburgerArrow.json',
      subcategories: [
        SubCategoryCard(title: 'TOYS & GAMES', imageUrl: 'https://images.unsplash.com/photo-1537655780520-1e392edd816a?w=400', cardSize: 'large', price: 599),
        SubCategoryCard(title: 'School Supplies', imageUrl: 'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=400'),
        SubCategoryCard(title: 'Clothing', imageUrl: 'https://images.unsplash.com/photo-1519242220831-09410926fbff?w=400'),
        SubCategoryCard(title: 'Baby Gear', imageUrl: 'https://images.unsplash.com/photo-1515488042361-404e9250afef?w=400'),
        SubCategoryCard(title: 'Party Supplies', imageUrl: 'https://images.unsplash.com/photo-1530103862676-de8c9debad1d?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'gifting',
      name: 'Gifting',
      bannerBgColor: const Color(0xFFFCBFC6),
      headerBgColor: const Color(0xFFFCBFC6),
      searchHint: 'Search "gifts"',
      sectionTitle: 'Perfect gifts',
      sectionSubtitle: 'For every occasion',
      bannerImageUrl: 'https://images.unsplash.com/photo-1513201099705-a9746e1e201f?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/17297-fireworks.json',
      subcategories: [
        SubCategoryCard(title: 'GIFT CARDS', imageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=400', cardSize: 'large', price: 1000),
        SubCategoryCard(title: 'Chocolates', imageUrl: 'https://images.unsplash.com/photo-1548907040-4d42b52115ca?w=400'),
        SubCategoryCard(title: 'Flowers', imageUrl: 'https://images.unsplash.com/photo-1490750967868-88df5691cc5b?w=400'),
        SubCategoryCard(title: 'Hampers', imageUrl: 'https://images.unsplash.com/photo-1607344645866-009c320b63e0?w=400'),
        SubCategoryCard(title: 'Wrapping', imageUrl: 'https://images.unsplash.com/photo-1512909006721-3d6018887383?w=400'),
      ],
    ),
    CategoryTheme(
      id: 'grocery',
      name: 'Grocery',
      bannerBgColor: const Color(0xFFE1E7C1),
      headerBgColor: const Color(0xFFE1E7C1),
      searchHint: 'Search "vegetables"',
      sectionTitle: 'Daily needs',
      sectionSubtitle: 'Fresh & organic',
      bannerImageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/blub.json',
      subcategories: [
        SubCategoryCard(title: 'FRESH VEGGIES', imageUrl: 'https://images.unsplash.com/photo-1566385101042-1a0a09022961?w=400', cardSize: 'large', price: 40),
        SubCategoryCard(title: 'Fruits', imageUrl: 'https://images.unsplash.com/photo-1619546813926-a78fa6372cd2?w=400'),
        SubCategoryCard(title: 'Grains', imageUrl: 'https://images.unsplash.com/photo-1574325131872-a1b858b82a3a?w=400'),
        SubCategoryCard(title: 'Oils', imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400'),
        SubCategoryCard(title: 'Spices', imageUrl: 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=400'),
      ],
    ),

    CategoryTheme(
      id: 'beverages',
      name: 'Beverages',
      bannerBgColor: const Color(0xFFF6FCC9),
      headerBgColor: const Color(0xFFF6FCC9),
      searchHint: 'Search "cold drinks"',
      sectionTitle: 'Thirst quenchers',
      sectionSubtitle: 'Chill out',
      bannerImageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600',
      lottieUrl: 'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/TwitterHeartButton.json',
      subcategories: [
        SubCategoryCard(title: 'COLD DRINKS', imageUrl: 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400', cardSize: 'large', price: 40),
        SubCategoryCard(title: 'Juices', imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400'),
        SubCategoryCard(title: 'Tea', imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=400'),
        SubCategoryCard(title: 'Coffee', imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400'),
        SubCategoryCard(title: 'Water', imageUrl: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400'),
      ],
    ),
  ];


  @override
  void initState() {
    super.initState();

    // Exit animation: content slides up and fades out
    _contentExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentExitController, curve: Curves.easeIn),
    );
    _exitTranslation = Tween<double>(begin: 0.0, end: -30.0).animate(
      CurvedAnimation(parent: _contentExitController, curve: Curves.easeIn),
    );

    // Enter animation: content slides up from below and fades in
    _contentEnterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _enterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentEnterController, curve: Curves.easeOutCubic),
    );
    _enterTranslation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentEnterController, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _onCategoryTabTapped(int index) async {
    if (index == _selectedCategoryIndex || _isChangingTab) return;

    // Scroll tab into view
    double screenWidth = MediaQuery.of(context).size.width;
    double tabWidth = 76.0;
    double targetOffset = (index * tabWidth) - (screenWidth / 2) + (tabWidth / 2);
    if (targetOffset < 0) targetOffset = 0;
    _tabScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() => _isChangingTab = true);

    // Step 1: Exit animation — content flies up and fades out
    _contentExitController.reset();
    await _contentExitController.forward();

    // Step 2: Switch tab index while invisible
    setState(() {
      _selectedCategoryIndex = index;
      _contentVisible = false;
    });

    // Small pause for the background color to start animating
    await Future.delayed(const Duration(milliseconds: 50));

    // Step 3: Enter animation — new content slides up from below
    _contentEnterController.reset();
    setState(() => _contentVisible = true);
    await _contentEnterController.forward();

    setState(() => _isChangingTab = false);
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _contentExitController.dispose();
    _contentEnterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _themes[_selectedCategoryIndex];
    final cart = Provider.of<CartProvider>(context);

    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildTopBar(currentTheme),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  child: Container(
                    color: currentTheme.bannerBgColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBar(currentTheme),
                        _buildCategoryTabs(currentTheme),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _contentExitController,
                    _contentEnterController,
                  ]),
                  builder: (context, child) {
                    double translation = 0;
                    double opacity = 1;
                    if (_contentExitController.isAnimating ||
                        _contentExitController.value > 0 && !_contentVisible) {
                      translation = _exitTranslation.value;
                      opacity = _exitOpacity.value;
                    } else if (_contentEnterController.isAnimating ||
                        _contentEnterController.value > 0) {
                      translation = _enterTranslation.value;
                      opacity = _enterOpacity.value;
                    }
                    return Transform.translate(
                      offset: Offset(0, translation),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: currentTheme.id == 'all'
                      ? _buildAllTabContent(currentTheme)
                      : _buildCategoryTabContent(currentTheme),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
          // Floating Cart — taps navigate to /cart
          if (cart.itemCount > 0)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => context.push('/cart'),
                child: Container(
                  decoration: BoxDecoration(
                    color: TurbocartColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: TurbocartColors.primary.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          AntigravityCartBadge(
                            quantity: cart.totalQuantity,
                            child: const Icon(Icons.shopping_bag, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${cart.totalQuantity} Items • ₹${cart.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Text('Tap to view cart & checkout', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(CategoryTheme currentTheme) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Container(
          color: currentTheme.bannerBgColor,
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
                        Text('TurboCart', style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userProvider.deliveryTime,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('24/7', style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Wallet
                  Column(
                    children: const [
                      Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0C831F), size: 26),
                      Text('₹0', style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Profile
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: userProvider.photoUrl != null && userProvider.photoUrl!.isNotEmpty
                          ? NetworkImage(userProvider.photoUrl!)
                          : null,
                      child: (userProvider.photoUrl == null || userProvider.photoUrl!.isEmpty)
                          ? Icon(Icons.person, size: 24, color: Colors.grey[800])
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const AddressRow(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(CategoryTheme currentTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () => context.go('/search'),
        child: Hero(
          tag: 'search-bar',
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Text(
                      currentTheme.searchHint,
                      key: ValueKey(currentTheme.searchHint),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.go('/search', extra: {'startVoiceSearch': true});
                  },
                  child: const Icon(Icons.mic_none, color: Colors.grey, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── All Tab Content ──
  Widget _buildAllTabContent(CategoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPromoBanner(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildBentoGrid(theme.subcategories),
        ),
        Container(
          color: Colors.white,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Grocery & Kitchen'),
              _buildCategoryGrid(groceryKitchenItems),
              _buildSectionTitle('Snacks & Drinks'),
              _buildCategoryGrid(snacksDrinksItems),
              
              _buildProductHorizontalSection(
                title: 'Bestsellers in Grocery',
                subtitle: 'Top picks for you',
                categoryFilter: 'grocery_kitchen',
              ),
              _buildProductHorizontalSection(
                title: 'Trending Snacks',
                subtitle: 'Munchies you\'ll love',
                categoryFilter: 'snacks_drinks',
              ),
              
              _buildSectionTitle('Beauty & Personal Care'),
              _buildCategoryGrid(beautyItems),
              _buildSectionTitle('Household Essentials'),
              _buildCategoryGrid(householdItems),
              
              _buildProductHorizontalSection(
                title: 'Self-care essentials',
                subtitle: 'Highly rated',
                categoryFilter: 'beauty_care',
              ),
              _buildFeaturedThisWeek(),
              _buildStoresInSpotlight(),
              _buildPicksForLifestyle(),
              _buildProductHorizontalSection(
                title: 'The drinks-break we all need',
                subtitle: 'Because you bought tea',
                categoryFilter: 'drinks',
              ),
              _buildProductHorizontalSection(
                title: 'Sneakerheads & shoe-lovers corner',
                subtitle: '',
                categoryFilter: 'footwear_care',
              ),
              _buildEventsThisWeek(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  // ── Category Tab Content (non-All tabs) ──
  Widget _buildCategoryTabContent(CategoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDynamicHeaderBanner(theme),
        Container(
          color: Colors.white,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryProductsSection(theme),
              _buildStoresInSpotlight(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  // Cache Firestore stream at State level to prevent flickering and rebuilds on cart/local state changes
  Stream<QuerySnapshot>? _productsStream;

  Stream<QuerySnapshot> _getProductsStream() {
    _productsStream ??= FirebaseFirestore.instance.collection('products').snapshots();
    return _productsStream!;
  }

  // ── Firestore-backed product grid with antigravity animations ──
  Widget _buildCategoryProductsSection(CategoryTheme theme) {
    final tag = theme.id;
    final currentLoadCount = _loadedCount[tag] ?? _pageSize;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return StreamBuilder<QuerySnapshot>(
          stream: _getProductsStream(),
          builder: (context, snapshot) {
            // Fallback products per category
            final fallback = _getFallbackProducts(theme.id);

            // Show shimmer only briefly, fallback to dummy products on error or empty data
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              // Show fallback immediately so the screen isn't blank
              final fallbackDisplayed = fallback.take(currentLoadCount).toList();
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(theme.sectionTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(theme.sectionSubtitle,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: fallbackDisplayed.length,
                        itemBuilder: (context, index) {
                          return AntigravityWrapper(
                            key: ValueKey('${theme.id}_fallback_$index'),
                            index: index,
                            category: theme.id,
                            animateEntrance: true,
                            enableFloat: true,
                            child: ProductCard(product: fallbackDisplayed[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            List<Map<String, dynamic>> products = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final docs = snapshot.data!.docs;
              // Filter by categoryTags arrayContains
              products = docs
                  .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                  .where((p) {
                    if (tag == 'all') return true;
                    final catTags = (p['categoryTags'] as List<dynamic>? ?? [])
                        .map((e) => e.toString().toLowerCase())
                        .toList();
                    final cat = (p['category'] as String? ?? '').toLowerCase();
                    return catTags.contains(tag) || cat == tag;
                  })
                  .toList();
            }

            if (products.isEmpty) {
              products = fallback;
            }

            final displayed = products.take(currentLoadCount).toList();
            final hasMore = products.length > currentLoadCount;

            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      theme.sectionTitle,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      theme.sectionSubtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (displayed.isEmpty)
                    _buildEmptyState(theme)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          return AntigravityWrapper(
                            key: ValueKey('${theme.id}_${displayed[index]['id'] ?? index}'),
                            index: index,
                            category: theme.id,
                            animateEntrance: true,
                            enableFloat: true,
                            child: ProductCard(product: displayed[index]),
                          );
                        },
                      ),
                    ),
                  if (hasMore) ...
                    [
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setLocalState(() {
                              _loadedCount[tag] = currentLoadCount + _pageSize;
                            });
                            setState(() {
                              _loadedCount[tag] = currentLoadCount + _pageSize;
                            });
                          },
                          icon: const Icon(Icons.expand_more,
                              color: Color(0xFF0C831F)),
                          label: const Text(
                            'Load More Products',
                            style: TextStyle(
                                color: Color(0xFF0C831F),
                                fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF0C831F), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _buildEmptyState(CategoryTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: -8.0, end: 0.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.translate(offset: Offset(0, value), child: child),
              child: Icon(
                _getIconForCategory(theme.id),
                size: 72,
                color: theme.bannerBgColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No products yet in ${theme.name}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back soon or browse all products',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => _onCategoryTabTapped(0),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0C831F), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Browse All Products',
                style: TextStyle(
                    color: Color(0xFF0C831F), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFallbackProducts(String categoryId) {
    final Map<String, List<Map<String, dynamic>>> fallbacks = {
      'vacations': [
        {'id': 'v1', 'title': 'Travel Backpack 40L', 'price': 1299.0, 'mrp': 1999.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=300', 'discount': '35% OFF', 'categoryTags': ['vacations']},
        {'id': 'v2', 'title': 'Sunscreen SPF 50+', 'price': 349.0, 'mrp': 450.0, 'unit': '100 ml', 'image': 'https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=300', 'discount': '22% OFF', 'categoryTags': ['vacations']},
        {'id': 'v3', 'title': 'Travel Pillow', 'price': 499.0, 'mrp': 699.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1508957941050-39bc53f08d97?w=300', 'discount': '28% OFF', 'categoryTags': ['vacations']},
        {'id': 'v4', 'title': 'Luggage Tag Set', 'price': 149.0, 'mrp': 199.0, 'unit': '4 pcs', 'image': 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=300', 'discount': '25% OFF', 'categoryTags': ['vacations']},
        {'id': 'v5', 'title': 'Travel Adapter', 'price': 799.0, 'mrp': 1200.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=300', 'discount': '33% OFF', 'categoryTags': ['vacations']},
        {'id': 'v6', 'title': 'Compact Umbrella', 'price': 299.0, 'mrp': 399.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1534534573898-db5148bc8b0c?w=300', 'discount': '25% OFF', 'categoryTags': ['vacations']},
      ],
      'electronics': [
        {'id': 'e1', 'title': 'Sony WH-1000XM5 Headphones', 'price': 24990.0, 'mrp': 34990.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=300', 'discount': '28% OFF', 'categoryTags': ['electronics']},
        {'id': 'e2', 'title': 'USB-C Charging Cable 2m', 'price': 299.0, 'mrp': 499.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=300', 'discount': '40% OFF', 'categoryTags': ['electronics']},
        {'id': 'e3', 'title': 'Wireless Earbuds', 'price': 1299.0, 'mrp': 2499.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=300', 'discount': '48% OFF', 'categoryTags': ['electronics']},
        {'id': 'e4', 'title': '65W GaN Charger', 'price': 1499.0, 'mrp': 1999.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=300', 'discount': '25% OFF', 'categoryTags': ['electronics']},
        {'id': 'e5', 'title': 'Smart Watch Series 8', 'price': 12999.0, 'mrp': 17999.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=300', 'discount': '27% OFF', 'categoryTags': ['electronics']},
        {'id': 'e6', 'title': 'Power Bank 20000mAh', 'price': 1799.0, 'mrp': 2799.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=300', 'discount': '35% OFF', 'categoryTags': ['electronics']},
      ],
      'beauty': [
        {'id': 'b1', 'title': 'Maybelline Fit Me Foundation', 'price': 349.0, 'mrp': 499.0, 'unit': '30 ml', 'image': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=300', 'discount': '30% OFF', 'categoryTags': ['beauty']},
        {'id': 'b2', 'title': 'Lakme Rose Face Powder', 'price': 149.0, 'mrp': 199.0, 'unit': '40 g', 'image': 'https://images.unsplash.com/photo-1512496015851-a90fb38ba796?w=300', 'discount': '25% OFF', 'categoryTags': ['beauty']},
        {'id': 'b3', 'title': 'Neutrogena Moisturizer', 'price': 399.0, 'mrp': 599.0, 'unit': '50 ml', 'image': 'https://images.unsplash.com/photo-1556228841-a3c527ebefe5?w=300', 'discount': '33% OFF', 'categoryTags': ['beauty']},
        {'id': 'b4', 'title': 'Dove Shampoo 650ml', 'price': 279.0, 'mrp': 349.0, 'unit': '650 ml', 'image': 'https://images.unsplash.com/photo-1571781926291-c477ebfd024b?w=300', 'discount': '20% OFF', 'categoryTags': ['beauty']},
        {'id': 'b5', 'title': 'L\'Oreal Lipstick', 'price': 449.0, 'mrp': 699.0, 'unit': '3.8 g', 'image': 'https://images.unsplash.com/photo-1586495777744-4e6232bf2b77?w=300', 'discount': '35% OFF', 'categoryTags': ['beauty']},
        {'id': 'b6', 'title': 'The Body Shop Tea Tree Oil', 'price': 799.0, 'mrp': 1099.0, 'unit': '30 ml', 'image': 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=300', 'discount': '27% OFF', 'categoryTags': ['beauty']},
      ],
      'pharmacy': [
        {'id': 'ph1', 'title': 'Crocin 500mg Tablets', 'price': 29.0, 'mrp': 36.0, 'unit': '15 tabs', 'image': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=300', 'discount': '19% OFF', 'categoryTags': ['pharmacy']},
        {'id': 'ph2', 'title': 'Himalaya Vitamin C', 'price': 199.0, 'mrp': 260.0, 'unit': '60 tabs', 'image': 'https://images.unsplash.com/photo-1550572017-edd951b55104?w=300', 'discount': '23% OFF', 'categoryTags': ['pharmacy']},
        {'id': 'ph3', 'title': 'Band-Aid Strips', 'price': 79.0, 'mrp': 99.0, 'unit': '30 pcs', 'image': 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=300', 'discount': '20% OFF', 'categoryTags': ['pharmacy']},
        {'id': 'ph4', 'title': 'Dettol Antiseptic 100ml', 'price': 89.0, 'mrp': 119.0, 'unit': '100 ml', 'image': 'https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?w=300', 'discount': '25% OFF', 'categoryTags': ['pharmacy']},
        {'id': 'ph5', 'title': 'Betadine Wound Care', 'price': 59.0, 'mrp': 75.0, 'unit': '30 ml', 'image': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=300', 'discount': '21% OFF', 'categoryTags': ['pharmacy']},
        {'id': 'ph6', 'title': 'Livogen Iron Tablets', 'price': 149.0, 'mrp': 195.0, 'unit': '30 tabs', 'image': 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=300', 'discount': '23% OFF', 'categoryTags': ['pharmacy']},
      ],
      'decor': [
        {'id': 'd1', 'title': 'Wooden Table Lamp', 'price': 799.0, 'mrp': 1199.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=300', 'discount': '33% OFF', 'categoryTags': ['decor']},
        {'id': 'd2', 'title': 'Boho Wall Art Set', 'price': 499.0, 'mrp': 799.0, 'unit': '3 pcs', 'image': 'https://images.unsplash.com/photo-1578500494198-246f612d3b3d?w=300', 'discount': '37% OFF', 'categoryTags': ['decor']},
        {'id': 'd3', 'title': 'Scented Soy Candle', 'price': 349.0, 'mrp': 499.0, 'unit': '200 g', 'image': 'https://images.unsplash.com/photo-1603006905003-be475563bc59?w=300', 'discount': '30% OFF', 'categoryTags': ['decor']},
        {'id': 'd4', 'title': 'Velvet Throw Pillow', 'price': 299.0, 'mrp': 449.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=300', 'discount': '33% OFF', 'categoryTags': ['decor']},
        {'id': 'd5', 'title': 'Indoor Succulent Plant', 'price': 199.0, 'mrp': 299.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?w=300', 'discount': '33% OFF', 'categoryTags': ['decor']},
        {'id': 'd6', 'title': 'Jute Braided Rug 3x5ft', 'price': 1299.0, 'mrp': 1999.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1600166898405-da9535204843?w=300', 'discount': '35% OFF', 'categoryTags': ['decor']},
      ],
      'kids': [
        {'id': 'k1', 'title': 'Lego Classic 500pcs', 'price': 1299.0, 'mrp': 1999.0, 'unit': '1 set', 'image': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=300', 'discount': '35% OFF', 'categoryTags': ['kids']},
        {'id': 'k2', 'title': 'Hot Wheels 10-Car Pack', 'price': 499.0, 'mrp': 699.0, 'unit': '10 pcs', 'image': 'https://images.unsplash.com/photo-1594787318286-3d835c1d207f?w=300', 'discount': '28% OFF', 'categoryTags': ['kids']},
        {'id': 'k3', 'title': 'Barbie Dreamhouse', 'price': 2999.0, 'mrp': 4999.0, 'unit': '1 set', 'image': 'https://images.unsplash.com/photo-1515488042361-404e9250afef?w=300', 'discount': '40% OFF', 'categoryTags': ['kids']},
        {'id': 'k4', 'title': 'Magnetic Drawing Board', 'price': 399.0, 'mrp': 599.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=300', 'discount': '33% OFF', 'categoryTags': ['kids']},
        {'id': 'k5', 'title': 'Play-Doh 10-Color Set', 'price': 349.0, 'mrp': 499.0, 'unit': '1 set', 'image': 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=300', 'discount': '30% OFF', 'categoryTags': ['kids']},
        {'id': 'k6', 'title': 'Kids Watercolor Set', 'price': 199.0, 'mrp': 299.0, 'unit': '24 colors', 'image': 'https://images.unsplash.com/photo-1542621334-a254cf47733d?w=300', 'discount': '33% OFF', 'categoryTags': ['kids']},
      ],
      'gifting': [
        {'id': 'g1', 'title': 'Amazon Gift Card ₹500', 'price': 500.0, 'mrp': 500.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=300', 'discount': '', 'categoryTags': ['gifting']},
        {'id': 'g2', 'title': 'Ferrero Rocher Box 16pcs', 'price': 549.0, 'mrp': 699.0, 'unit': '200 g', 'image': 'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=300', 'discount': '21% OFF', 'categoryTags': ['gifting']},
        {'id': 'g3', 'title': 'Rose Bouquet (Fresh)', 'price': 699.0, 'mrp': 999.0, 'unit': '12 stems', 'image': 'https://images.unsplash.com/photo-1490750967868-88df5691cc5b?w=300', 'discount': '30% OFF', 'categoryTags': ['gifting']},
        {'id': 'g4', 'title': 'Premium Gift Hamper', 'price': 1499.0, 'mrp': 2199.0, 'unit': '1 set', 'image': 'https://images.unsplash.com/photo-1607344645866-009c320b63e0?w=300', 'discount': '31% OFF', 'categoryTags': ['gifting']},
        {'id': 'g5', 'title': 'Personalized Mug', 'price': 349.0, 'mrp': 499.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1504972078668-bb7e40f2a5d3?w=300', 'discount': '30% OFF', 'categoryTags': ['gifting']},
        {'id': 'g6', 'title': 'Silk Gift Wrap Set', 'price': 199.0, 'mrp': 299.0, 'unit': '5 pcs', 'image': 'https://images.unsplash.com/photo-1512909006721-3d6018887383?w=300', 'discount': '33% OFF', 'categoryTags': ['gifting']},
      ],
      'grocery': [
        {'id': 'gr1', 'title': 'Fresh Tomatoes 1kg', 'price': 45.0, 'mrp': 60.0, 'unit': '1 kg', 'image': 'https://images.unsplash.com/photo-1546470427-227c42e5a788?w=300', 'discount': '25% OFF', 'categoryTags': ['grocery']},
        {'id': 'gr2', 'title': 'Aashirvaad Atta 5kg', 'price': 235.0, 'mrp': 299.0, 'unit': '5 kg', 'image': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=300', 'discount': '21% OFF', 'categoryTags': ['grocery']},
        {'id': 'gr3', 'title': 'Fortune Sunflower Oil 1L', 'price': 139.0, 'mrp': 179.0, 'unit': '1 L', 'image': 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300', 'discount': '22% OFF', 'categoryTags': ['grocery']},
        {'id': 'gr4', 'title': 'Tata Sampann Dal 500g', 'price': 89.0, 'mrp': 115.0, 'unit': '500 g', 'image': 'https://images.unsplash.com/photo-1585996840017-7c03bbf77e5e?w=300', 'discount': '22% OFF', 'categoryTags': ['grocery']},
        {'id': 'gr5', 'title': 'Green Capsicum 500g', 'price': 35.0, 'mrp': 50.0, 'unit': '500 g', 'image': 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?w=300', 'discount': '30% OFF', 'categoryTags': ['grocery']},
        {'id': 'gr6', 'title': 'Alphonso Mangoes 1kg', 'price': 199.0, 'mrp': 280.0, 'unit': '1 kg', 'image': 'https://images.unsplash.com/photo-1601493700631-2b16ec4b4716?w=300', 'discount': '28% OFF', 'categoryTags': ['grocery']},
      ],
      'dairy': [
        {'id': 'da1', 'title': 'Amul Taaza Milk 1L', 'price': 62.0, 'mrp': 65.0, 'unit': '1 L', 'image': 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=300', 'discount': '5% OFF', 'categoryTags': ['dairy']},
        {'id': 'da2', 'title': 'Amul Butter 500g', 'price': 255.0, 'mrp': 285.0, 'unit': '500 g', 'image': 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=300', 'discount': '10% OFF', 'categoryTags': ['dairy']},
        {'id': 'da3', 'title': 'Britannia Brown Bread', 'price': 45.0, 'mrp': 55.0, 'unit': '400 g', 'image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300', 'discount': '18% OFF', 'categoryTags': ['dairy']},
        {'id': 'da4', 'title': 'Mother Dairy Curd 400g', 'price': 45.0, 'mrp': 55.0, 'unit': '400 g', 'image': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=300', 'discount': '18% OFF', 'categoryTags': ['dairy']},
        {'id': 'da5', 'title': 'Farm Fresh Eggs 6pcs', 'price': 49.0, 'mrp': 60.0, 'unit': '6 pcs', 'image': 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=300', 'discount': '18% OFF', 'categoryTags': ['dairy']},
        {'id': 'da6', 'title': 'Amul Cheese Slices 10pc', 'price': 79.0, 'mrp': 95.0, 'unit': '200 g', 'image': 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a318?w=300', 'discount': '16% OFF', 'categoryTags': ['dairy']},
      ],
      'snacks': [
        {'id': 's1', 'title': 'Lay\'s Classic Salted 50g', 'price': 20.0, 'mrp': 25.0, 'unit': '50 g', 'image': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300', 'discount': '20% OFF', 'categoryTags': ['snacks']},
        {'id': 's2', 'title': 'Bingo Mad Angles', 'price': 20.0, 'mrp': 25.0, 'unit': '75 g', 'image': 'https://images.unsplash.com/photo-1599490659213-e2b9527bd087?w=300', 'discount': '20% OFF', 'categoryTags': ['snacks']},
        {'id': 's3', 'title': 'Oreo Chocolate Cookies', 'price': 30.0, 'mrp': 40.0, 'unit': '120 g', 'image': 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=300', 'discount': '25% OFF', 'categoryTags': ['snacks']},
        {'id': 's4', 'title': 'KitKat 4-Finger Bar', 'price': 50.0, 'mrp': 65.0, 'unit': '41.5 g', 'image': 'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=300', 'discount': '23% OFF', 'categoryTags': ['snacks']},
        {'id': 's5', 'title': 'Haldiram Aloo Bhujia 200g', 'price': 79.0, 'mrp': 99.0, 'unit': '200 g', 'image': 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=300', 'discount': '20% OFF', 'categoryTags': ['snacks']},
        {'id': 's6', 'title': 'Popcorn Caramel 125g', 'price': 89.0, 'mrp': 119.0, 'unit': '125 g', 'image': 'https://images.unsplash.com/photo-1585647347483-22b66260dfff?w=300', 'discount': '25% OFF', 'categoryTags': ['snacks']},
      ],
      'beverages': [
        {'id': 'bv1', 'title': 'Coca-Cola 750ml', 'price': 40.0, 'mrp': 45.0, 'unit': '750 ml', 'image': 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=300', 'discount': '11% OFF', 'categoryTags': ['beverages']},
        {'id': 'bv2', 'title': 'Real Fruit Juice 1L', 'price': 79.0, 'mrp': 99.0, 'unit': '1 L', 'image': 'https://images.unsplash.com/photo-1534353341086-3297e384cba4?w=300', 'discount': '20% OFF', 'categoryTags': ['beverages']},
        {'id': 'bv3', 'title': 'Tata Tea Gold 250g', 'price': 145.0, 'mrp': 185.0, 'unit': '250 g', 'image': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=300', 'discount': '21% OFF', 'categoryTags': ['beverages']},
        {'id': 'bv4', 'title': 'Nescafe Classic 50g', 'price': 175.0, 'mrp': 220.0, 'unit': '50 g', 'image': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=300', 'discount': '20% OFF', 'categoryTags': ['beverages']},
        {'id': 'bv5', 'title': 'Kinley Water 1L', 'price': 20.0, 'mrp': 25.0, 'unit': '1 L', 'image': 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=300', 'discount': '20% OFF', 'categoryTags': ['beverages']},
        {'id': 'bv6', 'title': 'Red Bull Energy 250ml', 'price': 125.0, 'mrp': 150.0, 'unit': '250 ml', 'image': 'https://images.unsplash.com/photo-1581636625402-29b2a704ef13?w=300', 'discount': '16% OFF', 'categoryTags': ['beverages']},
      ],
    };
    return fallbacks[categoryId] ?? [
      {'id': 'def1', 'title': 'Sample Product', 'price': 99.0, 'mrp': 149.0, 'unit': '1 pc', 'image': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300', 'discount': '33% OFF', 'categoryTags': [categoryId]},
    ];
  }

  Widget _buildCategoryTabs(CategoryTheme currentTheme) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _themes.length,
        itemBuilder: (context, index) {
          final theme = _themes[index];
          final isSelected = index == _selectedCategoryIndex;

          return GestureDetector(
            onTap: () => _onCategoryTabTapped(index),
            child: Container(
              width: 76,
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconForCategory(theme.id),
                        size: 28,
                        color: isSelected ? Colors.black : Colors.black54,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          color: isSelected ? Colors.black : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 0,
                      child: Container(
                        height: 3,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
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

  IconData _getIconForCategory(String id) {
    switch (id) {
      case 'all': return Icons.grid_view_rounded;
      case 'vacations': return Icons.beach_access_outlined;
      case 'electronics': return Icons.headphones_outlined;
      case 'beauty': return Icons.face_retouching_natural;
      case 'pharmacy': return Icons.medical_services_outlined;
      case 'decor': return Icons.light_outlined;
      case 'kids': return Icons.child_care_outlined;
      case 'gifting': return Icons.card_giftcard_outlined;
      case 'grocery': return Icons.local_grocery_store_outlined;
      case 'dairy': return Icons.egg_outlined;
      case 'snacks': return Icons.fastfood_outlined;
      case 'beverages': return Icons.local_cafe_outlined;
      default: return Icons.category_outlined;
    }
  }

  Widget _buildDynamicHeaderBanner(CategoryTheme theme) {
    // Local asset images for specific categories
    final String? localAsset = theme.id == 'pharmacy'
        ? 'assets/images/pharmacy_banner.png'
        : theme.id == 'electronics'
            ? 'assets/images/electronics_banner.jpg'
            : theme.id == 'vacations'
                ? 'assets/images/vacation.png'
                : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: SizedBox(
              key: ValueKey(theme.id),
              height: 220,
              width: double.infinity,
              child: localAsset != null
                  ? Image.asset(
                      localAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          CategoryAnimationWidget(
                            categoryId: theme.id,
                            primaryColor: theme.bannerBgColor,
                            size: 220,
                          ),
                    )
                  : CategoryAnimationWidget(
                      categoryId: theme.id,
                      primaryColor: theme.bannerBgColor,
                      size: 220,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(List<SubCategoryCard> cards) {
    if (cards.isEmpty) return const SizedBox();
    
    final largeCard = cards.firstWhere((c) => c.cardSize == 'large', orElse: () => cards.first);
    final smallCards = cards.where((c) => c != largeCard).take(4).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Large Card
        Expanded(
          flex: 1,
          child: _buildBentoCard(largeCard, height: 260),
        ),
        const SizedBox(width: 12),
        // Right Grid (2x2)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildBentoCard(smallCards.isNotEmpty ? smallCards[0] : null, height: 124)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildBentoCard(smallCards.length > 1 ? smallCards[1] : null, height: 124)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildBentoCard(smallCards.length > 2 ? smallCards[2] : null, height: 124)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildBentoCard(smallCards.length > 3 ? smallCards[3] : null, height: 124)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard(SubCategoryCard? card, {required double height}) {
    if (card == null) return Container(height: height, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(12)));
    
    return GestureDetector(
      onTap: () {
        context.push('/category', extra: {'categoryId': card.title.toLowerCase().replaceAll('\n', '_').replaceAll(' ', '_')});
      },
      child: Container(
        height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Text(
                    card.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: TurbocartColors.primary),
                    maxLines: 2,
                  ),
                ),
                if (card.price != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade200, borderRadius: BorderRadius.circular(4)),
                    child: Text('₹${card.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CachedNetworkImage(
                      imageUrl: card.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (c, u, e) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ── All Tab Content Helper Methods ──

  Widget _buildPromoBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('banners').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        final mockBanners = [
          'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600',
          'https://images.unsplash.com/photo-1506084868230-bb9d95c24759?w=600',
        ];
        final bool hasData = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final listLength = hasData ? snapshot.data!.docs.length : mockBanners.length;

        return Column(
          children: [
            CarouselSlider.builder(
              itemCount: listLength,
              options: CarouselOptions(
                height: 160,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4),
                viewportFraction: 1.0,
                onPageChanged: (index, _) => setState(() => _bannerIndex = index),
              ),
              itemBuilder: (ctx, i, _) {
                final String url = hasData ? snapshot.data!.docs[i]['imageUrl'] : mockBanners[i];
                return CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                );
              },
            ),
            const SizedBox(height: 6),
            SmoothPageIndicator(
              controller: PageController(initialPage: _bannerIndex),
              count: listLength,
              effect: WormEffect(
                dotHeight: 6,
                dotWidth: 6,
                activeDotColor: const Color(0xFF0C831F),
                dotColor: Colors.grey[300]!,
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See all', style: TextStyle(color: Color(0xFF0C831F))),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<CategoryGridItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => context.push('/category', extra: {'categoryId': item.routeId}),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[200]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedThisWeek() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Featured this week'),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featuredStores.length,
            itemBuilder: (ctx, i) {
              final store = featuredStores[i];
              return GestureDetector(
                onTap: () => context.push('/category', extra: {'categoryId': store.id}),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: store.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              store.badge,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black54, Colors.transparent],
                              ),
                            ),
                            child: Text(
                              store.title,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoresInSpotlight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Stores in spotlight'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: spotlightStores.length,
            itemBuilder: (ctx, i) {
              final store = spotlightStores[i];
              return GestureDetector(
                onTap: () => context.push('/category', extra: {'categoryId': store.title.toLowerCase().replaceAll('\n', '_')}),
                child: Container(
                  decoration: BoxDecoration(
                    color: store.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text(
                          store.title,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
                            child: CachedNetworkImage(
                              imageUrl: store.imageUrl,
                              fit: BoxFit.contain,
                              height: 75,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPicksForLifestyle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Picks for your lifestyle'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: lifestyleStores.length,
            itemBuilder: (ctx, i) {
              final store = lifestyleStores[i];
              return GestureDetector(
                onTap: () => context.push('/category', extra: {'categoryId': store.title.toLowerCase().replaceAll('\n', '_')}),
                child: Container(
                  decoration: BoxDecoration(
                    color: store.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text(
                          store.title,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
                            child: CachedNetworkImage(
                              imageUrl: store.imageUrl,
                              fit: BoxFit.contain,
                              height: 75,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductHorizontalSection({
    required String title,
    required String subtitle,
    required String categoryFilter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, subtitle: subtitle.isEmpty ? null : subtitle),
        SizedBox(
          height: 290,
          child: StreamBuilder<QuerySnapshot>(
            stream: _getProductsStream(),
            builder: (ctx, snapshot) {
              final fallbackProducts = [
                {
                  'id': 'p1',
                  'title': 'Fresh Organic Tomatoes',
                  'price': 45.0,
                  'mrp': 60.0,
                  'unit': '500 g',
                  'image': 'https://cdn.pixabay.com/photo/2011/03/16/16/01/tomatoes-5356_1280.jpg',
                  'tags': ['tomato', 'vegetable', 'fresh', 'organic'],
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
                  'tags': ['butter', 'dairy', 'amul', 'bread'],
                  'isDeal': true,
                  'isBestSeller': true,
                  'discount': '10% OFF',
                },
                {
                  'id': 'p3',
                  'title': 'Aashirvaad Whole Wheat Atta',
                  'price': 225.0,
                  'mrp': 240.0,
                  'unit': '5 kg',
                  'image': 'https://images.unsplash.com/photo-1627485937980-221c88ac04f9?w=300',
                  'tags': ['atta', 'flour', 'wheat', 'grocery'],
                  'isDeal': true,
                  'isBestSeller': true,
                  'discount': '6% OFF',
                },
                {
                  'id': 'p4',
                  'title': 'Fortune Sunflower Oil',
                  'price': 145.0,
                  'mrp': 155.0,
                  'unit': '1 L',
                  'image': 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300',
                  'tags': ['oil', 'cooking', 'grocery', 'fortune'],
                  'isDeal': false,
                  'isBestSeller': false,
                  'discount': '',
                },
                {
                  'id': 'p5',
                  'title': 'Britannia Good Day Cookies',
                  'price': 30.0,
                  'mrp': 35.0,
                  'unit': '250 g',
                  'image': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=300',
                  'tags': ['biscuits', 'cookies', 'snacks', 'sweet'],
                  'isDeal': true,
                  'isBestSeller': true,
                  'discount': '14% OFF',
                },
              ];

              final bool hasData = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              List<Map<String, dynamic>> finalProducts = fallbackProducts;

              if (hasData) {
                final filtered = snapshot.data!.docs
                    .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                    .where((p) {
                      final category = (p['category'] as String? ?? '').toLowerCase();
                      final tags = (p['tags'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
                      return category == categoryFilter.toLowerCase() || tags.contains(categoryFilter.toLowerCase());
                    })
                    .toList();
                if (filtered.isNotEmpty) {
                  finalProducts = filtered;
                } else {
                  finalProducts = snapshot.data!.docs
                      .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                      .take(5)
                      .toList();
                }
              }
              if (finalProducts.length > 5) {
                finalProducts = finalProducts.take(5).toList();
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: finalProducts.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == finalProducts.length) return _buildSeeAllCard(categoryFilter);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ProductCard(product: finalProducts[i]),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSeeAllCard(String category) {
    return GestureDetector(
      onTap: () => context.push('/category', extra: {'categoryId': category}),
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
            const Text('See all products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0C831F)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsThisWeek() {
    final events = [
      'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500',
      'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?w=500',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Events this week'),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: events.length,
            itemBuilder: (ctx, i) {
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: events[i],
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnimatedBanner extends StatefulWidget {
  final String imageUrl;

  const AnimatedBanner({super.key, required this.imageUrl});

  @override
  State<AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<AnimatedBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}

// ── Models & Lists for All Tab content ──

class CategoryGridItem {
  final String title;
  final String imageUrl;
  final String routeId;
  final Color bgColor;
  const CategoryGridItem({
    required this.title,
    required this.imageUrl,
    required this.routeId,
    this.bgColor = Colors.white,
  });
}

class FeaturedStore {
  final String id;
  final String title;
  final String imageUrl;
  final String badge;
  const FeaturedStore({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.badge,
  });
}

class SpotlightStore {
  final String title;
  final String imageUrl;
  final Color bgColor;
  const SpotlightStore({
    required this.title,
    required this.imageUrl,
    required this.bgColor,
  });
}

final groceryKitchenItems = [
  const CategoryGridItem(title: 'Vegetables\n& Fruits', imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=300', routeId: 'veg_fruits', bgColor: Color(0xFFF0FFF0)),
  const CategoryGridItem(title: 'Atta, Rice\n& Dal', imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=300', routeId: 'atta_rice', bgColor: Color(0xFFFFF8F0)),
  const CategoryGridItem(title: 'Oil, Ghee\n& Masala', imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300', routeId: 'oil_ghee', bgColor: Color(0xFFFFFAF0)),
  const CategoryGridItem(title: 'Dairy, Bread\n& Eggs', imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300', routeId: 'dairy', bgColor: Color(0xFFF0F8FF)),
  const CategoryGridItem(title: 'Bakery &\nBiscuits', imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300', routeId: 'bakery', bgColor: Color(0xFFFFF5E0)),
  const CategoryGridItem(title: 'Dry Fruits\n& Cereals', imageUrl: 'https://images.unsplash.com/photo-1596517592652-3023e1ca8e48?w=300', routeId: 'dry_fruits', bgColor: Color(0xFFFAF0E6)),
  const CategoryGridItem(title: 'Kitchenware\n& Appliances', imageUrl: 'https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?w=300', routeId: 'kitchenware', bgColor: Color(0xFFF5F5F5)),
];

final snacksDrinksItems = [
  const CategoryGridItem(title: 'Chips &\nNamkeen', imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300', routeId: 'chips', bgColor: Color(0xFFFFFDE7)),
  const CategoryGridItem(title: 'Sweets &\nChocolates', imageUrl: 'https://images.unsplash.com/photo-1581798459219-318e76aecc7b?w=300', routeId: 'sweets', bgColor: Color(0xFFFCE4EC)),
  const CategoryGridItem(title: 'Drinks &\nJuices', imageUrl: 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=300', routeId: 'drinks', bgColor: Color(0xFFE3F2FD)),
  const CategoryGridItem(title: 'Tea, Coffee\n& Milk Drinks', imageUrl: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=300', routeId: 'tea_coffee', bgColor: Color(0xFFEFEBE9)),
  const CategoryGridItem(title: 'Instant\nFood', imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300', routeId: 'instant_food', bgColor: Color(0xFFFFF8E1)),
  const CategoryGridItem(title: 'Sauces &\nSpreads', imageUrl: 'https://images.unsplash.com/photo-1471193945509-9ad0617afabf?w=300', routeId: 'sauces', bgColor: Color(0xFFE8F5E9)),
  const CategoryGridItem(title: 'Paan\nCorner', imageUrl: 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=300', routeId: 'paan', bgColor: Color(0xFFE8F5E9)),
  const CategoryGridItem(title: 'Ice Creams\n& More', imageUrl: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=300', routeId: 'ice_cream', bgColor: Color(0xFFE3F2FD)),
];

final beautyItems = [
  const CategoryGridItem(title: 'Bath &\nBody', imageUrl: 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=300', routeId: 'bath_body', bgColor: Color(0xFFFCE4EC)),
  const CategoryGridItem(title: 'Hair', imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=300', routeId: 'hair', bgColor: Color(0xFFEDE7F6)),
  const CategoryGridItem(title: 'Skin &\nFace', imageUrl: 'https://images.unsplash.com/photo-1598440947619-2c35fc9aa908?w=300', routeId: 'skin_face', bgColor: Color(0xFFFFF9C4)),
  const CategoryGridItem(title: 'Beauty &\nCosmetics', imageUrl: 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=300', routeId: 'cosmetics', bgColor: Color(0xFFFCE4EC)),
  const CategoryGridItem(title: 'Feminine\nHygiene', imageUrl: 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=300', routeId: 'feminine', bgColor: Color(0xFFFFEBEE)),
  const CategoryGridItem(title: 'Baby\nCare', imageUrl: 'https://images.unsplash.com/photo-1515488042361-404e9250afef?w=300', routeId: 'baby_care', bgColor: Color(0xFFE8F5E9)),
  const CategoryGridItem(title: 'Sexual\nWellness', imageUrl: 'https://images.unsplash.com/photo-1583947582381-8012b1d7d06e?w=300', routeId: 'sexual', bgColor: Color(0xFFE8EAF6)),
  const CategoryGridItem(title: 'Health &\nWellness', imageUrl: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=300', routeId: 'health', bgColor: Color(0xFFE8F5E9)),
];

final householdItems = [
  const CategoryGridItem(title: 'Home &\nLifestyle', imageUrl: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=300', routeId: 'home_lifestyle', bgColor: Color(0xFFE8F5E9)),
  const CategoryGridItem(title: 'Cleaners &\nRepellents', imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=300', routeId: 'cleaners', bgColor: Color(0xFFE3F2FD)),
  const CategoryGridItem(title: 'Electronics', imageUrl: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=300', routeId: 'electronics', bgColor: Color(0xFFE8EAF6)),
  const CategoryGridItem(title: 'Stationery\n& Games', imageUrl: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=300', routeId: 'stationery', bgColor: Color(0xFFFFF9C4)),
];

final featuredStores = [
  const FeaturedStore(id: 'hot_wheels', title: 'Newly\nLaunched', imageUrl: 'https://images.unsplash.com/photo-1594787318286-3d835c1d207f?w=300', badge: 'New'),
  const FeaturedStore(id: 'puramate', title: 'Puramate', imageUrl: 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=300', badge: 'Featured'),
  const FeaturedStore(id: 'magazine', title: 'Magazine\nCorner', imageUrl: 'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=300', badge: 'Featured'),
  const FeaturedStore(id: 'rainy_day', title: 'Rainy\nDay Es...', imageUrl: 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=300', badge: 'Featured'),
  const FeaturedStore(id: 'sneaker', title: 'Sneaker\nCare', imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=300', badge: 'Featured'),
  const FeaturedStore(id: 'derma', title: 'Derma\nStore', imageUrl: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=300', badge: 'Featured'),
];

final spotlightStores = [
  const SpotlightStore(title: 'Ice Cream\nStore', imageUrl: 'https://images.unsplash.com/photo-1501443715934-6271812452de?w=300', bgColor: Color(0xFFFFF9C4)),
  const SpotlightStore(title: 'Travel\nStore', imageUrl: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=300', bgColor: Color(0xFFFFF3E0)),
  const SpotlightStore(title: 'Hobby\nStore', imageUrl: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=300', bgColor: Color(0xFFEDE7F6)),
  const SpotlightStore(title: 'Sports\nStore', imageUrl: 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=300', bgColor: Color(0xFFE8F5E9)),
];

final lifestyleStores = [
  const SpotlightStore(title: 'Spiritual\nNeeds', imageUrl: 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=300', bgColor: Color(0xFFFFF8E1)),
  const SpotlightStore(title: 'Pet\nStore', imageUrl: 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=300', bgColor: Color(0xFFFCE4EC)),
  const SpotlightStore(title: 'Fashion\nBasics', imageUrl: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=300', bgColor: Color(0xFFE3F2FD)),
  const SpotlightStore(title: 'Toy\nStore', imageUrl: 'https://images.unsplash.com/photo-1539627831859-a911cf04d3cd?w=300', bgColor: Color(0xFFFFF9C4)),
  const SpotlightStore(title: 'Book\nStore', imageUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=300', bgColor: Color(0xFFE8F5E9)),
  const SpotlightStore(title: 'Pharma\nStore', imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=300', bgColor: Color(0xFFE8EAF6)),
  const SpotlightStore(title: 'E-Gifts\nStore', imageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=300', bgColor: Color(0xFFFFF3E0)),
  const SpotlightStore(title: 'Jewellery\nStore', imageUrl: 'https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=300', bgColor: Color(0xFFFFF9C4)),
];

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 134.0; 
  @override
  double get maxExtent => 134.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../utils/snackbar_utils.dart';
import '../utils/image_utils.dart';
import 'antigravity_wrapper.dart';
import 'particle_burst_wrapper.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool enableFloat;
  final double? width;

  const ProductCard({super.key, required this.product, this.enableFloat = true, this.width = 156});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isWishlisted = false;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final String variantUnit = widget.product['unit'] ?? '1 pc';
    final String cartKey = '${widget.product['id']}_$variantUnit';
    final isAdded = cart.items.containsKey(cartKey);
    final quantity = isAdded ? cart.items[cartKey]!.quantity : 0;

    final double price = (widget.product['price'] as num? ?? 0).toDouble();
    final double mrp = (widget.product['mrp'] as num? ?? 0).toDouble();
    final String discount = (widget.product['discount'] ?? '').toString();
    final String ageLabel = widget.product['ageLabel'] ?? '';

    final String category = widget.product['category'] ?? 'grocery_kitchen';
    final int pseudoIndex = (widget.product['id'] ?? '').hashCode.abs() % 10;

    final int stock = (widget.product['stock'] as num? ?? 10).toInt();

    return AntigravityWrapper(
      index: pseudoIndex,
      category: category,
      enableFloat: widget.enableFloat,
      child: GestureDetector(
        onTap: () => context.push(
          '/product/${widget.product['id']}',
          extra: widget.product,
        ),
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Area
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getCleanImageUrl(
                            widget.product['image'] ?? (widget.product['images'] is List && widget.product['images'].isNotEmpty ? widget.product['images'][0] : '') ?? '',
                            category: category,
                            title: widget.product['title'] ?? widget.product['name'],
                          ),
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => Image.network(
                            'https://images.unsplash.com/photo-1542838132-92c53300491e?w=200',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // ── Wishlist Heart (tappable, toggles) ──
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isWishlisted = !_isWishlisted;
                          });
                          SnackBarUtils.showTopSnackBar(
                            context,
                            _isWishlisted
                                ? 'Added "${widget.product['title'] ?? widget.product['name'] ?? ''}" to wishlist!'
                                : 'Removed "${widget.product['title'] ?? widget.product['name'] ?? ''}" from wishlist!',
                            backgroundColor: _isWishlisted ? TurbocartColors.primary : Colors.grey[800],
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
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
                          child: Icon(
                            _isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: _isWishlisted ? Colors.red : Colors.grey,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    // ── ADD / Quantity Controller ──
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: stock <= 0
                          ? Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text(
                                'Out of Stock',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : quantity > 0
                              ? Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: TurbocartColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => cart.removeItem(
                                            widget.product['id'], variantUnit),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 4.0),
                                          child: Icon(Icons.remove,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                      Text(
                                        '$quantity',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (quantity >= stock) {
                                            SnackBarUtils.showTopSnackBar(
                                                context, 'Cannot add more items. Stock limit reached.');
                                            return;
                                          }
                                          cart.addItem(
                                              widget.product['id'],
                                              widget.product['title'] ?? widget.product['name'] ?? '',
                                              price,
                                              widget.product['image'] ?? (widget.product['images'] is List && widget.product['images'].isNotEmpty ? widget.product['images'][0] : '') ?? '',
                                              variantUnit);
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 4.0),
                                          child: Icon(Icons.add,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SizedBox(
                                  height: 32,
                                  width: 60,
                                  child: ParticleBurstWrapper(
                                    onTap: () => cart.addItem(
                                        widget.product['id'],
                                        widget.product['title'] ?? widget.product['name'] ?? '',
                                        price,
                                        widget.product['image'] ?? (widget.product['images'] is List && widget.product['images'].isNotEmpty ? widget.product['images'][0] : '') ?? '',
                                        variantUnit),
                                    child: OutlinedButton(
                                      onPressed: () {
                                        cart.addItem(
                                            widget.product['id'],
                                            widget.product['title'] ?? widget.product['name'] ?? '',
                                            price,
                                            widget.product['image'] ?? (widget.product['images'] is List && widget.product['images'].isNotEmpty ? widget.product['images'][0] : '') ?? '',
                                            variantUnit);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: TurbocartColors.primary, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'ADD',
                                        style: TextStyle(
                                            color: TurbocartColors.primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),

              // Details Area
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (discount.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(3)),
                              child: Text(
                                discount,
                                style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (discount.isNotEmpty) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            variantUnit,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 10),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.black87),
                    ),
                    if (mrp > price)
                      Text(
                        'MRP ₹${mrp.toStringAsFixed(0)}',
                        style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.black38,
                            fontSize: 10),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product['title'] ?? widget.product['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ── Hindi name (shown only when field exists) ──
                    Builder(builder: (_) {
                      final hindiName = widget.product['hindiName'] as String?;
                      if (hindiName == null || hindiName.isEmpty) return const SizedBox.shrink();
                      return Text(
                        hindiName,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                    if (ageLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.yellow.shade100,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(ageLabel,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.brown.shade800,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

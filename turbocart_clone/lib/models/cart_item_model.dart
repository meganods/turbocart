import 'product_model.dart';

class CartItem {
  final Product product;
  final String variant;
  final int quantity;
  final double price;

  CartItem({
    required this.product,
    required this.variant,
    required this.quantity,
    required this.price,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product.fromMap(map['productId'] ?? '', map['product'] ?? {}),
      variant: map['variant'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'productName': product.name,
      'variant': variant,
      'quantity': quantity,
      'price': price,
      'imageUrl': product.images.isNotEmpty ? product.images.first : '',
      'product': product.toMap(),
    };
  }
}

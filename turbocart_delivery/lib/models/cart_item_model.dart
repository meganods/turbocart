class CartItem {
  final String productId;
  final String productName;
  final String variant;
  final int quantity;
  final double price;
  final String imageUrl;

  CartItem({
    required this.productId,
    required this.productName,
    required this.variant,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final prodMap = map['product'] as Map<String, dynamic>? ?? {};
    final String name = map['productName'] ?? prodMap['name'] ?? 'Item';
    final List<dynamic> images = prodMap['images'] as List<dynamic>? ?? [];
    final String img = map['imageUrl'] ?? (images.isNotEmpty ? images.first.toString() : '');

    return CartItem(
      productId: map['productId'] ?? '',
      productName: name,
      variant: map['variant'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: img,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String subcategory;
  final String description;
  final List<String> images;
  final List<String> tags;
  final double price;
  final double mrp;
  final double rating;
  final int discount;
  final int stock;
  final int reviewCount;
  final bool isDeal;
  final bool isBestSeller;
  final String weight;
  final String unit;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.subcategory,
    required this.description,
    required this.images,
    required this.tags,
    required this.price,
    required this.mrp,
    required this.rating,
    required this.discount,
    required this.stock,
    required this.reviewCount,
    required this.isDeal,
    required this.isBestSeller,
    required this.weight,
    required this.unit,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      category: map['category'] ?? '',
      subcategory: map['subcategory'] ?? '',
      description: map['description'] ?? '',
      images: map['images'] != null && (map['images'] as List).isNotEmpty
          ? List<String>.from(map['images'])
          : (map['image'] != null ? [map['image'] as String] : []),
      tags: List<String>.from(map['tags'] ?? []),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      discount: map['discount'] is num
          ? (map['discount'] as num).toInt()
          : int.tryParse((map['discount'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isDeal: map['isDeal'] ?? false,
      isBestSeller: map['isBestSeller'] ?? false,
      weight: map['weight'] ?? '',
      unit: map['unit'] ?? '',
    );
  }

  Map<String, dynamic> toMap({String? overrideId}) {
    final String resolvedId = overrideId ?? id;
    return {
      'id': resolvedId,
      'name': name,
      'title': name,                       // alias for ProductCard
      'brand': brand,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'images': images,
      'image': images.isNotEmpty ? images[0] : '',  // alias for ProductCard
      'tags': tags,
      'price': price,
      'mrp': mrp,
      'rating': rating,
      'discount': discount > 0 ? '$discount% OFF' : '',  // string for ProductCard
      'stock': stock,
      'reviewCount': reviewCount,
      'isDeal': isDeal,
      'isBestSeller': isBestSeller,
      'weight': weight,
      'unit': unit.isNotEmpty ? '$weight $unit' : '1 pc',  // combined unit string
    };
  }
}

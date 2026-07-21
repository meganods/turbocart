class Category {
  final String id;
  final String name;
  final String iconUrl;
  final String color;
  final int order;
  final List<String> subcategories;

  Category({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.color,
    required this.order,
    required this.subcategories,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      iconUrl: map['icon'] ?? '',
      color: map['color'] ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      subcategories: List<String>.from(map['subcategories'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': iconUrl,
      'color': color,
      'order': order,
      'subcategories': subcategories,
    };
  }
}

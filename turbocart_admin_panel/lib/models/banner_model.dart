class BannerModel {
  final String id;
  final String imageUrl;
  final int order;
  final bool active;
  final String? categoryId; // Optional category redirection link

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.order,
    required this.active,
    this.categoryId,
  });

  factory BannerModel.fromMap(String id, Map<String, dynamic> map) {
    return BannerModel(
      id: id,
      imageUrl: map['imageUrl'] ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      active: map['active'] ?? true,
      categoryId: map['categoryId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'order': order,
      'active': active,
      'categoryId': categoryId,
    };
  }
}

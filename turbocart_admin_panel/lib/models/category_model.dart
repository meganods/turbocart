class Category {
  final String id;
  final String name;
  final String icon;
  final int order;
  final String color;
  final String headerBgColor;
  final String bannerBgColor;
  final String bannerImageUrl;
  final String searchHint;
  final String sectionTitle;
  final String sectionSubtitle;
  final List<SubcategoryDetail> subcategories;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.order,
    required this.color,
    required this.headerBgColor,
    required this.bannerBgColor,
    required this.bannerImageUrl,
    required this.searchHint,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.subcategories,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    final subList = (map['subcategoriesDetail'] as List<dynamic>?)
            ?.map((s) => SubcategoryDetail.fromMap(s as Map<String, dynamic>))
            .toList() ??
        [];

    // Fallback if subcategoriesDetail is empty but raw subcategories strings are present
    if (subList.isEmpty && map['subcategories'] != null) {
      final rawSubs = List<String>.from(map['subcategories']);
      for (final name in rawSubs) {
        final subId = name.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_');
        subList.add(SubcategoryDetail(id: subId, name: name, icon: ''));
      }
    }

    return Category(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      color: map['color'] ?? '',
      headerBgColor: map['headerBgColor'] ?? '',
      bannerBgColor: map['bannerBgColor'] ?? '',
      bannerImageUrl: map['bannerImageUrl'] ?? '',
      searchHint: map['searchHint'] ?? '',
      sectionTitle: map['sectionTitle'] ?? '',
      sectionSubtitle: map['sectionSubtitle'] ?? '',
      subcategories: subList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'order': order,
      'color': color,
      'headerBgColor': headerBgColor,
      'bannerBgColor': bannerBgColor,
      'bannerImageUrl': bannerImageUrl,
      'searchHint': searchHint,
      'sectionTitle': sectionTitle,
      'sectionSubtitle': sectionSubtitle,
      'subcategoriesDetail': subcategories.map((s) => s.toMap()).toList(),
      // Embedded array of names for backward compatibility with the mobile client
      'subcategories': subcategories.map((s) => s.name).toList(),
    };
  }
}

class SubcategoryDetail {
  final String id;
  final String name;
  final String icon;

  SubcategoryDetail({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory SubcategoryDetail.fromMap(Map<String, dynamic> map) {
    return SubcategoryDetail(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }
}

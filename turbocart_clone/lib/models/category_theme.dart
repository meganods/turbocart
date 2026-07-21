import 'package:flutter/material.dart';

class SubCategoryCard {
  final String title;
  final String imageUrl;
  final double? price;
  final double? mrp;
  final String cardSize; // 'large' or 'small'

  SubCategoryCard({
    required this.title,
    required this.imageUrl,
    this.price,
    this.mrp,
    this.cardSize = 'small',
  });
}

class CategoryTheme {
  final String id;
  final String name;
  final Color bannerBgColor;
  final Color headerBgColor;
  final String searchHint;
  final String sectionTitle;
  final String sectionSubtitle;
  final String bannerImageUrl;
  final String? lottieUrl;
  final List<SubCategoryCard> subcategories;

  const CategoryTheme({
    required this.id,
    required this.name,
    required this.bannerBgColor,
    required this.headerBgColor,
    required this.searchHint,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.bannerImageUrl,
    this.lottieUrl,
    required this.subcategories,
  });
}

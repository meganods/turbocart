class ImageUtils {
  static String getCleanImageUrl(String? url, {String? category, String? title}) {
    if (url == null || url.trim().isEmpty) {
      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300';
    }

    final cleanUrl = url.trim();

    // 1. Redirect Pixabay 403 Forbidden links to clean Unsplash photos
    if (cleanUrl.contains('pixabay.com')) {
      final term = '${title ?? ""} ${category ?? ""}'.toLowerCase();
      if (term.contains('tomato')) return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=400';
      if (term.contains('capsicum') || term.contains('pepper') || term.contains('mirch')) return 'https://images.unsplash.com/photo-1526346658255-114c856a74b0?w=400';
      if (term.contains('spinach') || term.contains('palak')) return 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=400';
      if (term.contains('onion') || term.contains('pyaz')) return 'https://images.unsplash.com/photo-1508747703725-719777637510?w=400';
      if (term.contains('mango') || term.contains('aam')) return 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=400';
      if (term.contains('butter')) return 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=400';
      if (term.contains('milk') || term.contains('dairy') || term.contains('taaza')) return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400';
      if (term.contains('oil') || term.contains('fortune')) return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400';
      if (term.contains('almond') || term.contains('badam') || term.contains('nuts')) return 'https://images.unsplash.com/photo-1543257580-7269da773bf5?w=400';
      if (term.contains('atta') || term.contains('flour') || term.contains('aashirvaad')) return 'https://images.unsplash.com/photo-1627485937980-221c88ac04f9?w=400';
      if (term.contains('bread') || term.contains('bakery')) return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400';
      if (term.contains('detergent') || term.contains('wash') || term.contains('ariel')) return 'https://images.unsplash.com/photo-1607344645866-009c320c5ab8?w=400';
      if (term.contains('chocolate') || term.contains('cadbury')) return 'https://images.unsplash.com/photo-1549007994-cb92ca8a3bd0?w=400';
      if (term.contains('snack') || term.contains('chips') || term.contains('lays') || term.contains('kurkure')) return 'https://images.unsplash.com/photo-1599490659273-e3b69007f457?w=400';
      if (term.contains('salt') || term.contains('tata')) return 'https://images.unsplash.com/photo-1594732152861-12501a3cf841?w=400';
      if (term.contains('coke') || term.contains('beverage') || term.contains('pepsi') || term.contains('drink')) return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400';
      if (term.contains('maggi') || term.contains('noodles')) return 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=400';

      // General fallback based on category tag
      if (category == 'snacks_drinks') {
        return 'https://images.unsplash.com/photo-1599490659273-e3b69007f457?w=400';
      }
      if (category == 'beauty') {
        return 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=400';
      }
      if (category == 'pharmacy') {
        return 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400';
      }
      if (category == 'electronics') {
        return 'https://images.unsplash.com/photo-1588508065123-287b28e013da?w=400';
      }

      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400';
    }

    // 2. Redirect broken Unsplash IDs (that return 404) to working Unsplash photos
    if (cleanUrl.contains('1515488042361-404e9250afef')) {
      return 'https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?w=400'; // Barbie/Kids/Baby
    }
    if (cleanUrl.contains('1596517592652-3023e1ca8e48')) {
      return 'https://images.unsplash.com/photo-1543257580-7269da773bf5?w=400'; // Almonds
    }
    if (cleanUrl.contains('1583947582381-8012b1d7d06e')) {
      return 'https://images.unsplash.com/photo-1607344645866-009c320c5ab8?w=400'; // Ariel Detergent
    }
    if (cleanUrl.contains('1501443715934-6271812452de')) {
      return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400'; // Atta/Flour
    }

    return cleanUrl;
  }
}

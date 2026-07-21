// search_suggestions_data.dart
// All static data for the instant search suggestions dropdown

enum SuggestionType { recent, brand, category, product }

class SuggestionItem {
  final String text;
  final String label;
  final SuggestionType type;

  const SuggestionItem({
    required this.text,
    required this.label,
    required this.type,
  });
}

/// All known brand names — matched by startsWith (case-insensitive)
const List<String> kBrands = [
  'Amul', 'Britannia', 'Parle', 'Maggi', 'Nestle', 'Haldirams', 'Cadbury',
  'Lays', 'Kurkure', 'Bingo', 'Tata', 'Fortune', 'Aashirvaad', 'Dove',
  'Pantene', 'Colgate', 'Ariel', 'Surf Excel', 'Pampers', 'Huggies',
  'Johnson', 'Himalaya', 'Patanjali', 'Dabur', 'boAt', 'Realme', 'MI',
  'Samsung', 'Fogg', 'Nivea', 'Lakme', 'Garnier', 'Neutrogena', 'MDH',
  'Everest', 'Catch', 'Saffola', 'Kelloggs', 'Tropicana', 'Red Bull',
  'Pringles', 'Priyagold', 'Yogabar', 'Biotique', 'Revital', 'Real',
];

/// Category & English keyword → display label
/// Matched by startsWith (case-insensitive)
const List<(String, String)> kCategoryKeywords = [
  ('Vegetables', 'Category'),
  ('Soap', 'Personal Care'),
  ('Salt', 'Grocery'),
  ('Salad', 'Vegetables'),
  ('Mustard Oil', 'Oil'),
  ('Sauce', 'Condiments'),
  ('Sanitizer', 'Hygiene'),
  ('Lentils', 'Dal'),
  ('Saffron', 'Spices'),
  ('Fruits', 'Category'),
  ('Dairy', 'Category'),
  ('Milk', 'Dairy'),
  ('Yogurt', 'Dairy'),
  ('Bread', 'Bakery'),
  ('Snacks', 'Category'),
  ('Chips', 'Snacks'),
  ('Biscuit', 'Snacks'),
  ('Cookies', 'Snacks'),
  ('Chocolate', 'Sweets'),
  ('Juice', 'Beverages'),
  ('Drinks', 'Category'),
  ('Shampoo', 'Hair Care'),
  ('Cream', 'Skincare'),
  ('Spices', 'Spices'),
  ('Flour', 'Flour'),
  ('Rice', 'Grocery'),
  ('Ghee', 'Dairy'),
  ('Butter', 'Dairy'),
  ('Oil', 'Grocery'),
  ('Eggs', 'Protein'),
  ('Chicken', 'Meat'),
  ('Mutton', 'Meat'),
  ('Fish', 'Seafood'),
  ('Medicine', 'Pharmacy'),
  ('Diaper', 'Baby Care'),
  ('Baby', 'Baby Care'),
  ('Toy', 'Toys'),
  ('Gift', 'Gifts'),
  ('Perfume', 'Beauty'),
  ('Deo', 'Beauty'),
  ('Spinach', 'Vegetables'),
  ('Cottage Cheese', 'Dairy'),
  ('Pasta', 'Instant Food'),
  ('Ketchup', 'Condiments'),
  ('Pumpkin', 'Vegetables'),
  ('Bitter Gourd', 'Vegetables'),
  ('Black Salt', 'Salt'),
  ('Turmeric', 'Spices'),
  ('Hair Oil', 'Hair Care'),
  ('Red Chili', 'Spices'),
  ('Lemon', 'Fruits'),
  ('Bottle Gourd', 'Vegetables'),
  ('Tomato', 'Vegetables'),
  ('Toothpaste', 'Oral Care'),
  ('Toothbrush', 'Oral Care'),
  ('Mint', 'Beverages'),
  ('Sugar', 'Sugar'),
  ('Mango', 'Fruits'),
  ('Refined Oil', 'Oil'),
  ('Biryani Rice', 'Rice'),
  ('Okra', 'Vegetables'),
  ('Biryani Spices', 'Spices'),
  ('Coconut Oil', 'Oil'),
  ('Coconut', 'Fruits'),
  ('Cereal', 'Cereal'),
  ('Dates', 'Dry Fruits'),
  ('Capsicum', 'Vegetables'),
  ('Tea', 'Beverages'),
  ('Cushions', 'Home Decor'),
  ('Plants', 'Home Decor'),
  ('Dark Chocolate', 'Sweets'),
  ('Cheese', 'Dairy'),
  ('Corn Flakes', 'Breakfast'),
  ('Cold Drink', 'Beverages'),
  ('Coriander', 'Vegetables'),
  ('Brown Rice', 'Rice'),
  ('Brown Bread', 'Bakery'),
  ('Broccoli', 'Vegetables'),
  ('Muesli', 'Breakfast'),
  ('Macaroni', 'Pasta'),
  ('Hand Sanitizer', 'Hygiene'),
];

/// Instant suggestions for common 2-letter prefixes
/// Key = lowercase prefix, value = list of SuggestionItems (shown immediately, no debounce)
final Map<String, List<SuggestionItem>> kInstantSuggestions = {
  've': [
    SuggestionItem(text: 'Vegetables', label: 'Vegetables', type: SuggestionType.category),
    SuggestionItem(text: 'Vegan Cheese', label: 'Dairy Alternatives', type: SuggestionType.product),
  ],
  'sa': [
    SuggestionItem(text: 'Salad', label: 'Vegetables', type: SuggestionType.category),
    SuggestionItem(text: 'Salt', label: 'Grocery', type: SuggestionType.product),
    SuggestionItem(text: 'Sauce', label: 'Condiments', type: SuggestionType.product),
    SuggestionItem(text: 'Hand Sanitizer', label: 'Hygiene', type: SuggestionType.product),
    SuggestionItem(text: 'Salad Leaves', label: 'Vegetables', type: SuggestionType.product),
  ],
  'mi': [
    SuggestionItem(text: 'Milk', label: 'Dairy', type: SuggestionType.category),
    SuggestionItem(text: 'Mint', label: 'Beverages', type: SuggestionType.product),
    SuggestionItem(text: 'Mixed Lentils', label: 'Dal', type: SuggestionType.category),
  ],
  'ch': [
    SuggestionItem(text: 'Chips', label: 'Snacks', type: SuggestionType.category),
    SuggestionItem(text: 'Chocolate', label: 'Sweets', type: SuggestionType.category),
    SuggestionItem(text: 'Cheese', label: 'Dairy', type: SuggestionType.category),
    SuggestionItem(text: 'Chicken', label: 'Meat', type: SuggestionType.category),
  ],
  'bu': [
    SuggestionItem(text: 'Butter', label: 'Dairy', type: SuggestionType.category),
    SuggestionItem(text: 'Butter Cookies', label: 'Snacks', type: SuggestionType.product),
  ],
  'bi': [
    SuggestionItem(text: 'Biscuit', label: 'Snacks', type: SuggestionType.category),
    SuggestionItem(text: 'Biryani Rice', label: 'Rice', type: SuggestionType.product),
    SuggestionItem(text: 'Biotique', label: 'Brand', type: SuggestionType.brand),
  ],
  'da': [
    SuggestionItem(text: 'Dairy', label: 'Dairy', type: SuggestionType.category),
    SuggestionItem(text: 'Dark Chocolate', label: 'Brand — Cadbury', type: SuggestionType.brand),
    SuggestionItem(text: 'Dates', label: 'Dry Fruits', type: SuggestionType.product),
    SuggestionItem(text: 'Dabur', label: 'Brand', type: SuggestionType.brand),
  ],
  'gh': [
    SuggestionItem(text: 'Ghee', label: 'Dairy', type: SuggestionType.category),
    SuggestionItem(text: 'Organic Ghee', label: 'Dairy', type: SuggestionType.product),
  ],
  'pa': [
    SuggestionItem(text: 'Pasta', label: 'Instant Food', type: SuggestionType.product),
    SuggestionItem(text: 'Pantene', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Patanjali', label: 'Brand', type: SuggestionType.brand),
  ],
  'la': [
    SuggestionItem(text: 'Lays', label: 'Brand — Lays', type: SuggestionType.brand),
    SuggestionItem(text: 'Lemon', label: 'Fruits', type: SuggestionType.product),
    SuggestionItem(text: 'Lakme', label: 'Brand', type: SuggestionType.brand),
  ],
  'to': [
    SuggestionItem(text: 'Tomato', label: 'Vegetables', type: SuggestionType.category),
    SuggestionItem(text: 'Tomato Ketchup', label: 'Brand — Maggi', type: SuggestionType.brand),
    SuggestionItem(text: 'Toothpaste', label: 'Oral Care', type: SuggestionType.category),
    SuggestionItem(text: 'Toothbrush', label: 'Oral Care', type: SuggestionType.product),
  ],
  'ri': [
    SuggestionItem(text: 'Rice', label: 'Grocery', type: SuggestionType.category),
  ],
  're': [
    SuggestionItem(text: 'Red Bull', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Refined Oil', label: 'Oil', type: SuggestionType.category),
    SuggestionItem(text: 'Revital', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Real Juice', label: 'Brand — Real', type: SuggestionType.brand),
  ],
  'br': [
    SuggestionItem(text: 'Bread', label: 'Bakery', type: SuggestionType.category),
    SuggestionItem(text: 'Britannia', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Broccoli', label: 'Vegetables', type: SuggestionType.category),
    SuggestionItem(text: 'Brown Rice', label: 'Rice', type: SuggestionType.product),
    SuggestionItem(text: 'Brown Bread', label: 'Brand — Britannia', type: SuggestionType.brand),
  ],
  'co': [
    SuggestionItem(text: 'Colgate', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Corn Flakes', label: 'Brand — Kelloggs', type: SuggestionType.brand),
    SuggestionItem(text: 'Coriander', label: 'Vegetables', type: SuggestionType.category),
    SuggestionItem(text: 'Coconut Oil', label: 'Oil', type: SuggestionType.category),
    SuggestionItem(text: 'Cold Drink', label: 'Beverages', type: SuggestionType.category),
    SuggestionItem(text: 'Cookie', label: 'Snacks', type: SuggestionType.category),
  ],
  'ju': [
    SuggestionItem(text: 'Juice', label: 'Beverages', type: SuggestionType.category),
  ],
  'sh': [
    SuggestionItem(text: 'Shampoo', label: 'Hair Care', type: SuggestionType.category),
  ],
  'te': [
    SuggestionItem(text: 'Tea', label: 'Beverages', type: SuggestionType.category),
  ],
  'mu': [
    SuggestionItem(text: 'Muesli', label: 'Brand — Yogabar', type: SuggestionType.brand),
  ],
  'ha': [
    SuggestionItem(text: 'Haldirams', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Hand Sanitizer', label: 'Hygiene', type: SuggestionType.category),
    SuggestionItem(text: 'Hair Oil', label: 'Hair Care', type: SuggestionType.category),
  ],
  'pr': [
    SuggestionItem(text: 'Protein', label: 'Supplements', type: SuggestionType.category),
    SuggestionItem(text: 'Priyagold Biscuit', label: 'Brand — Priyagold', type: SuggestionType.brand),
    SuggestionItem(text: 'Pringles', label: 'Brand', type: SuggestionType.brand),
  ],
  'bo': [
    SuggestionItem(text: 'boAt', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Bottle', label: 'Kitchenware', type: SuggestionType.category),
    SuggestionItem(text: 'Bottle Gourd', label: 'Vegetables', type: SuggestionType.category),
    SuggestionItem(text: 'Bourbon Biscuit', label: 'Brand — Britannia', type: SuggestionType.brand),
  ],
  'am': [
    SuggestionItem(text: 'Amul', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Amul Butter', label: 'Dairy', type: SuggestionType.product),
    SuggestionItem(text: 'Amul Ghee', label: 'Dairy', type: SuggestionType.product),
    SuggestionItem(text: 'Amul Taaza Milk', label: 'Dairy', type: SuggestionType.product),
    SuggestionItem(text: 'Aashirvaad Atta', label: 'Brand — Aashirvaad', type: SuggestionType.brand),
  ],
  'ta': [
    SuggestionItem(text: 'Tata', label: 'Brand', type: SuggestionType.brand),
  ],
  'eg': [
    SuggestionItem(text: 'Eggs', label: 'Protein', type: SuggestionType.category),
  ],
  'di': [
    SuggestionItem(text: 'Diaper', label: 'Baby Care', type: SuggestionType.category),
  ],
  'fo': [
    SuggestionItem(text: 'Fogg', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Fortune', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Fortune Sunflower Oil', label: 'Oil', type: SuggestionType.product),
  ],
  'ni': [
    SuggestionItem(text: 'Nivea', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Nivea Soft Cream', label: 'Skincare', type: SuggestionType.product),
  ],
  'do': [
    SuggestionItem(text: 'Dove', label: 'Brand', type: SuggestionType.brand),
    SuggestionItem(text: 'Dove Soap', label: 'Personal Care', type: SuggestionType.product),
  ],
  'ku': [
    SuggestionItem(text: 'Kurkure', label: 'Brand', type: SuggestionType.brand),
  ],
};

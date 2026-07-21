import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/categories_provider.dart';
import '../../models/category_model.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoriesProvider>(context, listen: false).fetchCategories();
    });
  }

  void _showDeleteConfirmation(Category category, CategoriesProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "${category.name}"? This will delete the category, its icons, banners, and nested subcategory associations permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await provider.deleteCategory(category.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Category deleted successfully!' : 'Failed to delete category.'),
                    backgroundColor: success ? const Color(0xFF0C831F) : Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CategoriesProvider>(context);
    final primaryGreen = const Color(0xFF0C831F);

    if (provider.isLoading && provider.categories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              children: [
                const Text(
                  'Manage Categories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go('/categories/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reorderable ListView containing category cards
            Expanded(
              child: provider.categories.isEmpty
                  ? const Center(child: Text('No categories found. Click Add Category to create one.'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false, // Custom drag handle icon
                      itemCount: provider.categories.length,
                      onReorder: (oldIdx, newIdx) {
                        provider.updateCategoryOrder(oldIdx, newIdx);
                      },
                      itemBuilder: (context, index) {
                        final category = provider.categories[index];
                        final hexColorStr = category.color.replaceFirst('#', '');
                        Color? pillBgColor;
                        try {
                          if (hexColorStr.isNotEmpty) {
                            pillBgColor = Color(int.parse('FF$hexColorStr', radix: 16));
                          }
                        } catch (_) {}

                        return Card(
                          key: ValueKey(category.id),
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                // Left Drag Handle
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Icon(Icons.drag_indicator, color: Colors.grey.shade400),
                                  ),
                                ),

                                // Category Thumbnail
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: pillBgColor?.withOpacity(0.15) ?? Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: category.icon.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: CachedNetworkImage(
                                            imageUrl: category.icon,
                                            fit: BoxFit.contain,
                                            errorWidget: (context, url, error) => const Icon(Icons.category, size: 20),
                                          ),
                                        )
                                      : const Icon(Icons.category, size: 20, color: Colors.grey),
                                ),
                                const SizedBox(width: 16),

                                // Category Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${category.id}  •  Subcategories: ${category.subcategories.length}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Order Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Order: ${category.order}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Action Buttons
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                  onPressed: () {
                                    context.go('/categories/edit/${category.id}');
                                  },
                                  tooltip: 'Edit Category',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () => _showDeleteConfirmation(category, provider),
                                  tooltip: 'Delete Category',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

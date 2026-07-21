import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/products_provider.dart';
import '../../models/product_model.dart';
import '../../utils/admin_logger.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedProductIds = {};
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isImporting = false;

  Future<void> _pickAndImportCsv(ProductsProvider provider) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final csvString = utf8.decode(file.bytes!);
      
      // Parse CSV lines custom
      final List<List<dynamic>> fields = [];
      final lines = csvString.split('\n');
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        final cells = line.split(',');
        fields.add(cells.map((cell) {
          var c = cell.trim();
          if (c.startsWith('"') && c.endsWith('"') && c.length >= 2) {
            c = c.substring(1, c.length - 1).replaceAll('""', '"');
          }
          return c;
        }).toList());
      }

      if (fields.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid CSV file: No data found.')),
          );
        }
        return;
      }

      final headers = fields.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final nameIdx = headers.indexOf('name');
      final hindiIdx = headers.indexOf('hindiname');
      final brandIdx = headers.indexOf('brand');
      final catIdx = headers.indexOf('category');
      final subIdx = headers.indexOf('subcategory');
      final priceIdx = headers.indexOf('price');
      final mrpIdx = headers.indexOf('mrp');
      final stockIdx = headers.indexOf('stock');
      final imgIdx = headers.indexOf('imageurl');
      final descIdx = headers.indexOf('description');

      if (nameIdx == -1 || priceIdx == -1 || catIdx == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Required headers missing (Name, Price, Category required).')),
          );
        }
        return;
      }

      setState(() {
        _isImporting = true;
      });

      int importCount = 0;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length <= nameIdx || row[nameIdx].toString().trim().isEmpty) continue;

        final name = row[nameIdx].toString().trim();
        final hindiName = hindiIdx != -1 && row.length > hindiIdx ? row[hindiIdx].toString().trim() : '';
        final brand = brandIdx != -1 && row.length > brandIdx ? row[brandIdx].toString().trim() : '';
        final category = catIdx != -1 && row.length > catIdx ? row[catIdx].toString().trim() : '';
        final subcategory = subIdx != -1 && row.length > subIdx ? row[subIdx].toString().trim() : '';
        final price = priceIdx != -1 && row.length > priceIdx ? double.tryParse(row[priceIdx].toString()) ?? 0.0 : 0.0;
        final mrp = mrpIdx != -1 && row.length > mrpIdx ? double.tryParse(row[mrpIdx].toString()) ?? price : price;
        final stock = stockIdx != -1 && row.length > stockIdx ? int.tryParse(row[stockIdx].toString()) ?? 10 : 10;
        final imageUrl = imgIdx != -1 && row.length > imgIdx ? row[imgIdx].toString().trim() : '';
        final description = descIdx != -1 && row.length > descIdx ? row[descIdx].toString().trim() : '';

        final docRef = db.collection('products').doc();
        batch.set(docRef, {
          'id': docRef.id,
          'title': name,
          'hindiName': hindiName,
          'name': name,
          'brand': brand,
          'category': category,
          'subcategory': subcategory,
          'price': price,
          'mrp': mrp,
          'stock': stock,
          'image': imageUrl,
          'images': imageUrl.isNotEmpty ? [imageUrl] : [],
          'description': description,
          'categoryTags': ['all', category.toLowerCase()],
          'rating': 4.5,
          'reviewCount': 10,
          'isActive': true,
          'isDeal': false,
          'isBestSeller': false,
          'discount': '',
        });
        importCount++;
      }

      await batch.commit();
      await provider.fetchProducts();

      await AdminLogger.log(
        actionType: 'BULK_IMPORT_PRODUCTS',
        affectedDocId: 'multiple',
        details: 'Bulk imported $importCount products via CSV.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $importCount products!'),
            backgroundColor: const Color(0xFF0C831F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import products: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductsProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(Product product, ProductsProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "${product.name}"? This will remove its database record and media files permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await provider.deleteProduct(product.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Product deleted successfully!' : 'Failed to delete product.'),
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

  void _showBulkDeleteConfirmation(ProductsProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Selected Products', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete ${_selectedProductIds.length} selected products? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final list = _selectedProductIds.toList();
                final success = await provider.bulkDelete(list);
                if (success) {
                  setState(() {
                    _selectedProductIds.clear();
                  });
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Selected products deleted successfully!' : 'Failed to delete selected products.'),
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
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductsProvider>(context);
    final primaryGreen = const Color(0xFF0C831F);

    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
        ),
      );
    }

    // Pagination logic
    final filteredList = provider.filteredProducts;
    final totalItems = filteredList.length;
    final totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final startIdx = _currentPage * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, totalItems);
    final pageItems = filteredList.sublist(startIdx, endIdx);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Filters Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Category Filter Dropdown
                      const Text(
                        'Category:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: provider.selectedCategory,
                            dropdownColor: Colors.white,
                            items: provider.categories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                provider.setSelectedCategory(val);
                                setState(() {
                                  _currentPage = 0;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Search bar
                      SizedBox(
                        width: 250,
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (val) {
                            provider.setSearchQuery(val);
                            setState(() {
                              _currentPage = 0;
                            });
                          },
                        ),
                      ),
                      // Bulk Import Button
                      ElevatedButton.icon(
                        onPressed: () => _pickAndImportCsv(provider),
                        icon: const Icon(Icons.file_upload, size: 18),
                        label: const Text('Bulk Import CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryGreen,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Add Product Button
                      ElevatedButton.icon(
                        onPressed: () {
                          context.go('/products/add');
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Product'),
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
                ),

                const SizedBox(height: 20),

                // 2. Data Grid Card
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                showCheckboxColumn: true,
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                columns: const [
                                  DataColumn(label: Text('Image')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('Price')),
                                  DataColumn(label: Text('MRP')),
                                  DataColumn(label: Text('Stock')),
                                  DataColumn(label: Text('Rating')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: pageItems.map((product) {
                                  final isSelected = _selectedProductIds.contains(product.id);
                                  final imgUrl = product.images.isNotEmpty ? product.images.first : '';

                                  return DataRow(
                                    selected: isSelected,
                                    onSelectChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedProductIds.add(product.id);
                                        } else {
                                          _selectedProductIds.remove(product.id);
                                        }
                                      });
                                    },
                                    cells: [
                                      // Image Column
                                      DataCell(
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade200),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: imgUrl.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: CachedNetworkImage(
                                                    imageUrl: imgUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => const SizedBox(),
                                                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 20),
                                                  ),
                                                )
                                              : const Icon(Icons.image, size: 20, color: Colors.grey),
                                        ),
                                      ),
                                      // Name Column
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            product.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      // Category Column
                                      DataCell(Text(product.category)),
                                      // Price Column
                                      DataCell(Text('₹${product.price.toStringAsFixed(2)}')),
                                      // MRP Column
                                      DataCell(Text('₹${product.mrp.toStringAsFixed(2)}')),
                                      // Stock Column
                                      DataCell(
                                        Text(
                                          product.stock.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: product.stock < 10 ? Colors.redAccent : const Color(0xFF0C831F),
                                          ),
                                        ),
                                      ),
                                      // Rating Column
                                      DataCell(
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(product.rating.toStringAsFixed(1)),
                                          ],
                                        ),
                                      ),
                                      // Status Column
                                      DataCell(
                                        Switch(
                                          value: product.isActive,
                                          activeThumbColor: primaryGreen,
                                          onChanged: (val) async {
                                            final messenger = ScaffoldMessenger.of(context);
                                            final success = await provider.toggleProductStatus(product.id, product.isActive);
                                            if (!success && mounted) {
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text('Failed to update product status.'),
                                                  backgroundColor: Colors.redAccent,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      // Actions Column
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                              onPressed: () {
                                                context.go('/products/edit/${product.id}');
                                              },
                                              tooltip: 'Edit Product',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                              onPressed: () => _showDeleteConfirmation(product, provider),
                                              tooltip: 'Delete Product',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // 3. Pagination Controls footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey.shade100)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${totalItems == 0 ? 0 : startIdx + 1} - $endIdx of $totalItems products',
                                style: const TextStyle(color: Color(0xFF6B7280)),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _currentPage > 0
                                        ? () {
                                            setState(() {
                                              _currentPage--;
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _currentPage < totalPages - 1
                                        ? () {
                                            setState(() {
                                              _currentPage++;
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Floating Action Bar for Bulk Selection
          if (_selectedProductIds.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: const Color(0xFF1F2937),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedProductIds.length} items selected',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 24),
                        // Set Active Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await provider.bulkSetStatus(_selectedProductIds.toList(), true);
                            if (success) {
                              setState(() {
                                _selectedProductIds.clear();
                              });
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Selected items set to active!' : 'Bulk update failed.'),
                                backgroundColor: success ? primaryGreen : Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Set Active'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Set Inactive Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await provider.bulkSetStatus(_selectedProductIds.toList(), false);
                            if (success) {
                              setState(() {
                                _selectedProductIds.clear();
                              });
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Selected items set to inactive!' : 'Bulk update failed.'),
                                backgroundColor: success ? Colors.amber.shade700 : Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.remove_circle_outline, size: 16),
                          label: const Text('Set Inactive'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Delete Button
                        ElevatedButton.icon(
                          onPressed: () => _showBulkDeleteConfirmation(provider),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete Selected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isImporting)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F))),
                          SizedBox(height: 16),
                          Text('Importing products from CSV, please wait...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

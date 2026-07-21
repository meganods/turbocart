import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import '../../providers/products_provider.dart';
import '../../models/product_model.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _nameHindiController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _weightController = TextEditingController();
  final _stockController = TextEditingController();
  final _tagsController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _keywordsHindiController = TextEditingController();

  // Dropdowns & Toggles
  String? _selectedCategory;
  String? _selectedSubcategory;
  String _selectedUnit = 'pcs';
  double _rating = 0.0;
  bool _isDeal = false;
  bool _isBestSeller = false;

  // Image State
  List<String> _existingImages = [];
  final List<_PickedImage> _newPickedImages = [];
  bool _isUploadingImages = false;

  final List<String> _units = ['g', 'kg', 'ml', 'l', 'pcs', 'set'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ProductsProvider>(context, listen: false);
      await provider.fetchCategoriesAndSubcategories();
      
      if (widget.productId != null) {
        _loadProductDetails(provider);
      }
    });
  }

  void _loadProductDetails(ProductsProvider provider) {
    final product = provider.products.firstWhere((p) => p.id == widget.productId);
    
    setState(() {
      _nameController.text = product.name;
      _nameHindiController.text = product.nameHindi;
      _brandController.text = product.brand;
      
      // Select category and subcategory safely
      if (provider.categoriesMap.containsKey(product.category)) {
        _selectedCategory = product.category;
        final subcats = provider.categoriesMap[product.category] ?? [];
        if (subcats.contains(product.subcategory)) {
          _selectedSubcategory = product.subcategory;
        }
      }
      
      _descriptionController.text = product.description;
      _priceController.text = product.price.toString();
      _mrpController.text = product.mrp.toString();
      _weightController.text = product.weight;
      
      if (_units.contains(product.unit)) {
        _selectedUnit = product.unit;
      }
      
      _stockController.text = product.stock.toString();
      _rating = product.rating;
      _tagsController.text = product.tags.join(', ');
      _keywordsController.text = product.searchKeywords;
      _keywordsHindiController.text = product.searchKeywordsHindi;
      _isDeal = product.isDeal;
      _isBestSeller = product.isBestSeller;
      _existingImages = List<String>.from(product.images);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameHindiController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _weightController.dispose();
    _stockController.dispose();
    _tagsController.dispose();
    _keywordsController.dispose();
    _keywordsHindiController.dispose();
    super.dispose();
  }

  // Live calculated discount percentage next to MRP field
  String _calculateDiscountPercentage() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text) ?? 0.0;
    if (mrp <= 0 || price <= 0 || price > mrp) {
      return '';
    }
    final discountPercent = ((mrp - price) / mrp) * 100;
    return '${discountPercent.toStringAsFixed(0)}% OFF';
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.bytes != null) {
            _newPickedImages.add(_PickedImage(
              bytes: file.bytes!,
              name: file.name,
            ));
          }
        }
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both Category and Subcategory.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final provider = Provider.of<ProductsProvider>(context, listen: false);
    setState(() {
      _isUploadingImages = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final uploadedUrls = <String>[];

      // Upload new images to Firebase Storage
      for (final picked in _newPickedImages) {
        final task = await provider.uploadProductImageTask(
          bytes: picked.bytes,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory!,
          filename: '${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
        );

        // Monitor upload task progress
        task.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          setState(() {
            picked.progress = progress;
          });
        });

        final snapshot = await task;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      // Combine existing images (minus any deleted ones) and newly uploaded ones
      final finalImageUrls = [..._existingImages, ...uploadedUrls];

      // Clean tags text to array
      final tagsArray = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final calculatedDiscount = _calculateDiscountValue();

      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text.trim(),
        nameHindi: _nameHindiController.text.trim(),
        brand: _brandController.text.trim(),
        category: _selectedCategory!,
        subcategory: _selectedSubcategory!,
        description: _descriptionController.text.trim(),
        images: finalImageUrls,
        tags: tagsArray,
        price: double.parse(_priceController.text),
        mrp: double.parse(_mrpController.text),
        rating: _rating,
        discount: calculatedDiscount,
        stock: int.parse(_stockController.text),
        reviewCount: widget.productId != null
            ? provider.products.firstWhere((p) => p.id == widget.productId).reviewCount
            : 0,
        isDeal: _isDeal,
        isBestSeller: _isBestSeller,
        weight: _weightController.text.trim(),
        unit: _selectedUnit,
        isActive: widget.productId != null
            ? provider.products.firstWhere((p) => p.id == widget.productId).isActive
            : true,
        searchKeywords: _keywordsController.text.trim(),
        searchKeywordsHindi: _keywordsHindiController.text.trim(),
      );

      final success = await provider.saveProduct(
        product: product,
        imageUrls: finalImageUrls,
        isEditing: widget.productId != null,
      );

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully!'),
            backgroundColor: Color(0xFF0C831F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        router.go('/products');
      } else {
        setState(() {
          _isUploadingImages = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to save product in Firestore.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImages = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error occurred during save: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _calculateDiscountValue() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text) ?? 0.0;
    if (mrp <= 0 || price <= 0 || price > mrp) {
      return 0;
    }
    final discountPercent = ((mrp - price) / mrp) * 100;
    return discountPercent.round();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductsProvider>(context);
    final primaryGreen = const Color(0xFF0C831F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 950;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/products'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.productId == null ? 'Add New Product' : 'Edit Product',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildLeftFieldsCard(provider, primaryGreen),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: _buildRightImagesCard(primaryGreen),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildLeftFieldsCard(provider, primaryGreen),
                        const SizedBox(height: 24),
                        _buildRightImagesCard(primaryGreen),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // Actions row footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isUploadingImages ? null : () => context.go('/products'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFF9CA3AF)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF4B5563))),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isUploadingImages ? null : _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isUploadingImages
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Save Product', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLeftFieldsCard(ProductsProvider provider, Color accentColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Name and Hindi Name
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameHindiController,
                    decoration: const InputDecoration(labelText: 'Hindi Name', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 2: Brand and Category
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                    dropdownColor: Colors.white,
                    items: provider.formCategories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                        _selectedSubcategory = null; // reset subcategory on category change
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 3: Subcategory and Unit
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubcategory,
                    decoration: const InputDecoration(labelText: 'Subcategory *', border: OutlineInputBorder()),
                    dropdownColor: Colors.white,
                    items: _selectedCategory == null
                        ? []
                        : (provider.categoriesMap[_selectedCategory] ?? []).map((sub) {
                            return DropdownMenuItem(value: sub, child: Text(sub));
                          }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSubcategory = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(labelText: 'Unit *', border: OutlineInputBorder()),
                    dropdownColor: Colors.white,
                    items: _units.map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedUnit = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 4: Weight and Stock
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Weight/Size *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock Level *', border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required field';
                      if (int.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 5: Price and MRP with Live Discount calculation next to it
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Sale Price *', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required field';
                      if (double.tryParse(v) == null) return 'Must be a valid decimal';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _mrpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'MRP *',
                      border: const OutlineInputBorder(),
                      suffixText: _calculateDiscountPercentage(),
                      suffixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required field';
                      final parsedMrp = double.tryParse(v);
                      final parsedPrice = double.tryParse(_priceController.text);
                      if (parsedMrp == null) return 'Must be a valid decimal';
                      if (parsedPrice != null && parsedMrp < parsedPrice) {
                        return 'MRP cannot be less than sale price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description Textarea
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Product Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // Rating slider input
            Row(
              children: [
                const Text('Rating:', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF4B5563))),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 0.0,
                    max: 5.0,
                    divisions: 50,
                    activeColor: accentColor,
                    label: _rating.toStringAsFixed(1),
                    onChanged: (val) {
                      setState(() {
                        _rating = val;
                      });
                    },
                  ),
                ),
                Text(_rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),

            // Tags (Comma separated)
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (Comma separated, e.g. organic, milk, fresh)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Search Keywords
            TextFormField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                labelText: 'Search Keywords (Comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Search Keywords Hindi
            TextFormField(
              controller: _keywordsHindiController,
              decoration: const InputDecoration(
                labelText: 'Search Keywords Hindi (Comma separated, supports Hindi script)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Deal & Best Seller Switch Toggles
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Is Deal of the Day'),
                    value: _isDeal,
                    activeColor: accentColor,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isDeal = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Is Best Seller'),
                    value: _isBestSeller,
                    activeColor: accentColor,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isBestSeller = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightImagesCard(Color accentColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Product Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 16),

            // Drag and Drop Zone Picker Box
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB), width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF9FAFB),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 44, color: Color(0xFF9CA3AF)),
                    SizedBox(height: 12),
                    Text(
                      'Click to browse files',
                      style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Supports JPG, PNG, WEBP',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Previews Grid (Existing + New Picked)
            const Text(
              'Selected Previews',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            if (_existingImages.isEmpty && _newPickedImages.isEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('No images selected', style: TextStyle(color: Color(0xFF9CA3AF))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: _existingImages.length + _newPickedImages.length,
                itemBuilder: (context, index) {
                  // Render existing URLs first
                  if (index < _existingImages.length) {
                    final url = _existingImages[index];
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _existingImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Render newly picked files next
                  final pickedIndex = index - _existingImages.length;
                  final picked = _newPickedImages[pickedIndex];
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(picked.bytes, fit: BoxFit.cover),
                        ),
                      ),
                      // Upload progress bar overlay
                      if (picked.progress > 0 && picked.progress < 1.0)
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: picked.progress,
                              minHeight: 6,
                              color: accentColor,
                              backgroundColor: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _newPickedImages.removeAt(pickedIndex);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PickedImage {
  final Uint8List bytes;
  final String name;
  double progress = 0.0;

  _PickedImage({required this.bytes, required this.name});
}

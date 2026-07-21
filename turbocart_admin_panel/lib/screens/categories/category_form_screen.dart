import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import '../../providers/categories_provider.dart';
import '../../models/category_model.dart';

class CategoryFormScreen extends StatefulWidget {
  final String? categoryId;
  const CategoryFormScreen({super.key, this.categoryId});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _headerBgColorController = TextEditingController();
  final _bannerBgColorController = TextEditingController();
  final _searchHintController = TextEditingController();
  final _sectionTitleController = TextEditingController();
  final _sectionSubtitleController = TextEditingController();
  final _orderController = TextEditingController();

  // Picked Images Bytes (Web compatible)
  Uint8List? _pickedIconBytes;
  String? _pickedIconName;
  String? _existingIconUrl;

  Uint8List? _pickedBannerBytes;
  String? _pickedBannerName;
  String? _existingBannerUrl;

  // Subcategories local list items
  final List<_SubcategoryFormItem> _subcategories = [];
  bool _isSaving = false;

  // Visual Color Presets for Hex Picking
  final List<Map<String, String>> _colorPresets = [
    {'name': 'Mint Green', 'hex': '#0C831F'},
    {'name': 'Orange Accent', 'hex': '#FF8A00'},
    {'name': 'Sky Blue', 'hex': '#00A3FF'},
    {'name': 'Grape Purple', 'hex': '#9B51E0'},
    {'name': 'Cherry Red', 'hex': '#EB5757'},
    {'name': 'Light Grey', 'hex': '#F3F4F6'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<CategoriesProvider>(context, listen: false);
      await provider.fetchCategories();

      if (widget.categoryId != null) {
        _loadCategoryDetails(provider);
      } else {
        // Set default order number based on current count
        _orderController.text = provider.categories.length.toString();
        // Add a default empty subcategory row to start
        _addSubcategoryRow();
      }
    });
  }

  void _loadCategoryDetails(CategoriesProvider provider) {
    final category = provider.categories.firstWhere((c) => c.id == widget.categoryId);
    setState(() {
      _idController.text = category.id;
      _nameController.text = category.name;
      _colorController.text = category.color;
      _headerBgColorController.text = category.headerBgColor;
      _bannerBgColorController.text = category.bannerBgColor;
      _searchHintController.text = category.searchHint;
      _sectionTitleController.text = category.sectionTitle;
      _sectionSubtitleController.text = category.sectionSubtitle;
      _orderController.text = category.order.toString();
      
      _existingIconUrl = category.icon;
      _existingBannerUrl = category.bannerImageUrl;

      _subcategories.clear();
      for (final sub in category.subcategories) {
        _subcategories.add(_SubcategoryFormItem(
          id: sub.id,
          name: sub.name,
          existingIconUrl: sub.icon,
        ));
      }
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _headerBgColorController.dispose();
    _bannerBgColorController.dispose();
    _searchHintController.dispose();
    _sectionTitleController.dispose();
    _sectionSubtitleController.dispose();
    _orderController.dispose();
    for (final sub in _subcategories) {
      sub.dispose();
    }
    super.dispose();
  }

  void _addSubcategoryRow() {
    setState(() {
      _subcategories.add(_SubcategoryFormItem());
    });
  }

  void _removeSubcategoryRow(int index) {
    setState(() {
      _subcategories[index].dispose();
      _subcategories.removeAt(index);
    });
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _pickedIconBytes = result.files.first.bytes;
        _pickedIconName = result.files.first.name;
      });
    }
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _pickedBannerBytes = result.files.first.bytes;
        _pickedBannerName = result.files.first.name;
      });
    }
  }

  Future<void> _pickSubcategoryIcon(int index) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _subcategories[index].pickedIconBytes = result.files.first.bytes;
        _subcategories[index].pickedIconName = result.files.first.name;
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_existingIconUrl == null && _pickedIconBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a Category Icon image.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final provider = Provider.of<CategoriesProvider>(context, listen: false);
    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      // 1. Upload main icon if picked
      String finalIconUrl = _existingIconUrl ?? '';
      if (_pickedIconBytes != null) {
        finalIconUrl = await provider.uploadCategoryImage(
          bytes: _pickedIconBytes!,
          pathPrefix: 'icons',
          filename: '${_idController.text.trim()}_icon.jpg',
        );
      }

      // 2. Upload banner if picked
      String finalBannerUrl = _existingBannerUrl ?? '';
      if (_pickedBannerBytes != null) {
        finalBannerUrl = await provider.uploadCategoryImage(
          bytes: _pickedBannerBytes!,
          pathPrefix: 'banners',
          filename: '${_idController.text.trim()}_banner.jpg',
        );
      }

      // 3. Process subcategories uploads
      final finalSubcategories = <SubcategoryDetail>[];
      for (final sub in _subcategories) {
        String subIconUrl = sub.existingIconUrl ?? '';
        
        if (sub.pickedIconBytes != null) {
          subIconUrl = await provider.uploadCategoryImage(
            bytes: sub.pickedIconBytes!,
            pathPrefix: 'subcategories/icons',
            filename: '${sub.idController.text.trim()}_subicon.jpg',
          );
        }

        finalSubcategories.add(SubcategoryDetail(
          id: sub.idController.text.trim(),
          name: sub.nameController.text.trim(),
          icon: subIconUrl,
        ));
      }

      final category = Category(
        id: _idController.text.trim().toLowerCase(),
        name: _nameController.text.trim(),
        icon: finalIconUrl,
        order: int.tryParse(_orderController.text.trim()) ?? 0,
        color: _colorController.text.trim(),
        headerBgColor: _headerBgColorController.text.trim(),
        bannerBgColor: _bannerBgColorController.text.trim(),
        bannerImageUrl: finalBannerUrl,
        searchHint: _searchHintController.text.trim(),
        sectionTitle: _sectionTitleController.text.trim(),
        sectionSubtitle: _sectionSubtitleController.text.trim(),
        subcategories: finalSubcategories,
      );

      final success = await provider.saveCategory(
        category: category,
        isEditing: widget.categoryId != null,
      );

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Category saved successfully!'),
            backgroundColor: Color(0xFF0C831F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        router.go('/categories');
      } else {
        setState(() {
          _isSaving = false;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save category.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving category: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/categories'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.categoryId == null ? 'Add New Category' : 'Edit Category',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Layout container: Left Inputs, Right Images & Colors presets
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 950;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildFormCard(),
                              const SizedBox(height: 24),
                              _buildSubcategoriesCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: _buildRightSideCard(primaryGreen),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildFormCard(),
                        const SizedBox(height: 24),
                        _buildRightSideCard(primaryGreen),
                        const SizedBox(height: 24),
                        _buildSubcategoriesCard(),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => context.go('/categories'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF9CA3AF)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF4B5563))),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final isNewCategory = widget.categoryId == null;

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
              'Category Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 20),

            // Row 1: ID and Name
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _idController,
                    enabled: isNewCategory,
                    decoration: InputDecoration(
                      labelText: 'Category ID (lowercase, no spaces) *',
                      border: const OutlineInputBorder(),
                      filled: !isNewCategory,
                      fillColor: !isNewCategory ? Colors.grey.shade100 : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required field';
                      if (v.contains(' ') || RegExp(r'[A-Z]').hasMatch(v)) {
                        return 'ID must be lowercase and contain no spaces';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Display Name *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 2: Search Hint and Order Number
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchHintController,
                    decoration: const InputDecoration(
                      labelText: 'Search Hint Text (e.g. Search "milk")',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Order Number *', border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required field';
                      if (int.tryParse(v) == null) return 'Must be a valid integer';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Row 3: Section Title and Subtitle
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sectionTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Theme Section Title (e.g. Dairy, Bread & Eggs)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _sectionSubtitleController,
                    decoration: const InputDecoration(
                      labelText: 'Theme Section Subtitle (e.g. Fresh milk & daily bakery)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSideCard(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Image Pickers Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Media Uploads',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 16),

                // Main Category Icon upload
                const Text('Category Icon *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildSingleImagePicker(
                  onTap: _pickIcon,
                  pickedBytes: _pickedIconBytes,
                  pickedName: _pickedIconName,
                  existingUrl: _existingIconUrl,
                ),

                const SizedBox(height: 20),

                // Category Banner upload
                const Text('Category Banner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildSingleImagePicker(
                  onTap: _pickBanner,
                  pickedBytes: _pickedBannerBytes,
                  pickedName: _pickedBannerName,
                  existingUrl: _existingBannerUrl,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 2. Theme Colors Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme Colors',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 16),

                // Color Presets grid
                const Text(
                  'Quick Presets:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colorPresets.map((preset) {
                    final hexColor = Color(int.parse(preset['hex']!.replaceFirst('#', 'FF'), radix: 16));
                    return Tooltip(
                      message: preset['name']!,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _colorController.text = preset['hex']!;
                            _headerBgColorController.text = preset['hex']!;
                            _bannerBgColorController.text = preset['hex']!;
                          });
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: hexColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Color Hex TextFields
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Screen BG Color Hex (e.g. #0C831F)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _headerBgColorController,
                  decoration: const InputDecoration(
                    labelText: 'Top Bar BG Color Hex',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bannerBgColorController,
                  decoration: const InputDecoration(
                    labelText: 'Banner BG Color Hex',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleImagePicker({
    required VoidCallback onTap,
    required Uint8List? pickedBytes,
    required String? pickedName,
    required String? existingUrl,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF9FAFB),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (pickedName != null)
                    Text(
                      pickedName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (existingUrl != null && existingUrl.isNotEmpty)
                    const Text('Existing Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                  else
                    const Text('Choose Image File', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Click to upload', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                ],
              ),
            ),
            if (pickedBytes != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(pickedBytes, width: 80, height: 80, fit: BoxFit.cover),
                ),
              )
            else if (existingUrl != null && existingUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: existingUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoriesCard() {
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
            Row(
              children: [
                const Text(
                  'Subcategories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addSubcategoryRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Row'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_subcategories.isEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('No subcategories added yet. Click Add Row.', style: TextStyle(color: Color(0xFF9CA3AF))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subcategories.length,
                itemBuilder: (context, index) {
                  final sub = _subcategories[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFFAFAFA),
                    ),
                    child: Row(
                      children: [
                        // ID Field
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: sub.idController,
                            decoration: const InputDecoration(
                              labelText: 'Subcategory ID *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (v.contains(' ') || RegExp(r'[A-Z]').hasMatch(v)) {
                                return 'ID must be lowercase without spaces';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name Field
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: sub.nameController,
                            decoration: const InputDecoration(
                              labelText: 'Subcategory Name *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Image Picker Row
                        Expanded(
                          flex: 4,
                          child: InkWell(
                            onTap: () => _pickSubcategoryIcon(index),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.image_outlined, size: 20, color: Colors.grey.shade400),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sub.pickedIconName ?? 
                                      (sub.existingIconUrl != null && sub.existingIconUrl!.isNotEmpty ? 'Existing Icon' : 'Select Icon'),
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (sub.pickedIconBytes != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(sub.pickedIconBytes!, width: 32, height: 32, fit: BoxFit.cover),
                                    )
                                  else if (sub.existingIconUrl != null && sub.existingIconUrl!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: CachedNetworkImage(
                                        imageUrl: sub.existingIconUrl!,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        errorWidget: (c, u, e) => const Icon(Icons.broken_image),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Delete Row Button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => _removeSubcategoryRow(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryFormItem {
  final TextEditingController idController;
  final TextEditingController nameController;
  Uint8List? pickedIconBytes;
  String? pickedIconName;
  String? existingIconUrl;

  _SubcategoryFormItem({
    String? id,
    String? name,
    this.existingIconUrl,
  })  : idController = TextEditingController(text: id),
        nameController = TextEditingController(text: name);

  void dispose() {
    idController.dispose();
    nameController.dispose();
  }
}

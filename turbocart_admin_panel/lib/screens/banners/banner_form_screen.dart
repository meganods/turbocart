import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import '../../providers/banners_provider.dart';
import '../../providers/categories_provider.dart';
import '../../models/banner_model.dart';

class BannerFormScreen extends StatefulWidget {
  final String? bannerId;
  const BannerFormScreen({super.key, this.bannerId});

  @override
  State<BannerFormScreen> createState() => _BannerFormScreenState();
}

class _BannerFormScreenState extends State<BannerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _orderController = TextEditingController();
  String? _selectedCategoryId;
  bool _isActive = true;

  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bannersProvider = Provider.of<BannersProvider>(context, listen: false);
      await bannersProvider.fetchBanners();

      // Fetch categories for linking dropdown
      final catsProvider = Provider.of<CategoriesProvider>(context, listen: false);
      await catsProvider.fetchCategories();

      if (widget.bannerId != null) {
        _loadBannerDetails(bannersProvider);
      } else {
        _orderController.text = bannersProvider.banners.length.toString();
      }
    });
  }

  void _loadBannerDetails(BannersProvider provider) {
    final banner = provider.banners.firstWhere((b) => b.id == widget.bannerId);
    setState(() {
      _orderController.text = banner.order.toString();
      _selectedCategoryId = banner.categoryId;
      _isActive = banner.active;
      _existingImageUrl = banner.imageUrl;
    });
  }

  @override
  void dispose() {
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickBannerImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _pickedImageBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_existingImageUrl == null && _pickedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image file to upload.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final bannersProvider = Provider.of<BannersProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      String finalImageUrl = _existingImageUrl ?? '';
      if (_pickedImageBytes != null) {
        final filename = '${DateTime.now().millisecondsSinceEpoch}_banner.jpg';
        finalImageUrl = await bannersProvider.uploadBannerImage(_pickedImageBytes!, filename);
      }

      final banner = BannerModel(
        id: widget.bannerId ?? '',
        imageUrl: finalImageUrl,
        order: int.tryParse(_orderController.text.trim()) ?? 0,
        active: _isActive,
        categoryId: _selectedCategoryId,
      );

      final success = await bannersProvider.saveBanner(banner);

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Banner saved successfully!'),
            backgroundColor: Color(0xFF0C831F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        router.go('/banners');
      } else {
        setState(() {
          _isSaving = false;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save banner.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving banner: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF0C831F);
    final catsProvider = Provider.of<CategoriesProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navigation Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/banners'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.bannerId == null ? 'Add Promotional Banner' : 'Edit Banner Settings',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Layout Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildBannerForm(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: _buildBannerPreviewCard(catsProvider),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildBannerForm(),
                        const SizedBox(height: 20),
                        _buildBannerPreviewCard(catsProvider),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // Form Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => context.go('/banners'),
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
                        : const Text('Save Banner', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerForm() {
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
              'Banner Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 24),

            // Image Picker Section
            const Text('Upload Banner Image *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Recommended size: 1200 x 400 pixels (aspect ratio 3:1)', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickBannerImage,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF9FAFB),
                ),
                alignment: Alignment.center,
                child: _pickedImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(_pickedImageBytes!, width: double.infinity, height: 180, fit: BoxFit.cover),
                      )
                    : (_existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: _existingImageUrl!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 48),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 48),
                              const SizedBox(height: 12),
                              const Text('Click to choose banner image file', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('Supports JPG, PNG formats', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                            ],
                          )),
              ),
            ),
            const SizedBox(height: 24),

            // Order field
            TextFormField(
              controller: _orderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Display Order *', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required field';
                if (int.tryParse(v) == null) return 'Must be a valid integer';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerPreviewCard(CategoriesProvider catsProvider) {
    final primaryGreen = const Color(0xFF0C831F);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Actions & Properties',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const Divider(height: 24),

            // Link to Category dropdown
            DropdownButtonFormField<String>(
              value: catsProvider.categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
              hint: const Text('Link to Category (Optional)...'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: catsProvider.categories.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                });
              },
            ),

            const SizedBox(height: 24),

            // Active Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Show banner in storefront carousel', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
                Switch(
                  value: _isActive,
                  activeColor: primaryGreen,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

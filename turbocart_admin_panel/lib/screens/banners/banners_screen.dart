import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/banners_provider.dart';
import '../../models/banner_model.dart';

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BannersProvider>(context, listen: false).fetchBanners();
    });
  }

  void _showDeleteConfirmation(BannerModel banner, BannersProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Banner', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this promotional banner? This will remove the image from Storage and delete it permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await provider.deleteBanner(banner.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Banner deleted successfully!' : 'Failed to delete banner.'),
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
    final provider = Provider.of<BannersProvider>(context);
    final primaryGreen = const Color(0xFF0C831F);

    if (provider.isLoading && provider.banners.isEmpty) {
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
                  'Promotional Banners',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go('/banners/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Banner'),
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

            // Reorderable ListView
            Expanded(
              child: provider.banners.isEmpty
                  ? const Center(child: Text('No banners found. Click Add Banner to upload promotional material.'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: provider.banners.length,
                      onReorder: (oldIdx, newIdx) {
                        provider.updateBannersOrder(oldIdx, newIdx);
                      },
                      itemBuilder: (context, index) {
                        final banner = provider.banners[index];
                        return Card(
                          key: ValueKey(banner.id),
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Reorder Drag Handle
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Icon(Icons.drag_indicator, color: Colors.grey.shade400),
                                  ),
                                ),

                                // Image Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 180,
                                    height: 70,
                                    color: Colors.grey.shade50,
                                    child: banner.imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: banner.imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                                          )
                                        : const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 24),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sequence Order: ${banner.order}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        banner.categoryId != null && banner.categoryId!.isNotEmpty
                                            ? 'Links to Category: ${banner.categoryId}'
                                            : 'No linked category (General Promo)',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Active Toggle Status
                                Column(
                                  children: [
                                    const Text('Active', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                    const SizedBox(height: 2),
                                    Switch(
                                      value: banner.active,
                                      activeColor: primaryGreen,
                                      onChanged: (val) async {
                                        await provider.toggleBannerStatus(banner.id, val);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),

                                // Actions
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                      onPressed: () {
                                        context.go('/banners/edit/${banner.id}');
                                      },
                                      tooltip: 'Edit Banner',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _showDeleteConfirmation(banner, provider),
                                      tooltip: 'Delete Banner',
                                    ),
                                  ],
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

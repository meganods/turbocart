import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/users_provider.dart';
import '../../models/user_model.dart';
import '../../utils/csv_exporter.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UsersProvider>(context, listen: false).fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    if (_searchQuery.isEmpty) return users;
    return users.where((u) {
      final nameMatch = u.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatch = u.phone.contains(_searchQuery);
      return nameMatch || phoneMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UsersProvider>(context);
    final primaryGreen = const Color(0xFF0C831F);

    if (provider.isLoading && provider.users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C831F)),
        ),
      );
    }

    final filteredUsers = _filterUsers(provider.users);

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
                  'Manage Users',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    final header = ['UID', 'Name', 'Phone', 'Email', 'Blocked Status', 'Created At'];
                    final List<List<dynamic>> rows = [
                      header,
                      ...filteredUsers.map((u) => [
                        u.uid,
                        u.name,
                        u.phone,
                        u.email,
                        u.blocked ? 'BLOCKED' : 'ACTIVE',
                        DateFormat('dd MMM yyyy').format(u.createdAt.toDate())
                      ])
                    ];
                    CsvExporter.exportToCsv(rows: rows, filename: 'users_export.csv');
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryGreen,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 320,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name or phone...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table Card
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: filteredUsers.isEmpty
                    ? const Center(child: Text('No users found matching search query.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  columnSpacing: 32,
                                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                  showCheckboxColumn: false,
                                  columns: const [
                                    DataColumn(label: Text('Photo')),
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Phone')),
                                    DataColumn(label: Text('Email')),
                                    DataColumn(label: Text('Total Orders')),
                                    DataColumn(label: Text('Total Spent')),
                                    DataColumn(label: Text('Joined Date')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filteredUsers.map((user) {
                                    final orderCount = provider.getOrderCount(user.phone, user.email);
                                    final totalSpent = provider.getTotalSpent(user.phone, user.email);
                                    final joinedStr = DateFormat('dd MMM yyyy').format(user.createdAt.toDate());

                                    return DataRow(
                                      onSelectChanged: (_) {
                                        context.go('/users/${user.uid}');
                                      },
                                      cells: [
                                        // Photo
                                        DataCell(
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              shape: BoxShape.circle,
                                            ),
                                            child: ClipOval(
                                              child: user.photoUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: user.photoUrl,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (context, url, error) => const Icon(Icons.person, size: 20),
                                                    )
                                                  : const Icon(Icons.person, size: 20, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        // Name
                                        DataCell(
                                          Text(
                                            user.name.isNotEmpty ? user.name : 'No Name',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        // Phone
                                        DataCell(Text(user.phone)),
                                        // Email
                                        DataCell(Text(user.email.isNotEmpty ? user.email : 'N/A')),
                                        // Total Orders
                                        DataCell(Text(orderCount.toString())),
                                        // Total Spent
                                        DataCell(Text('₹${totalSpent.toStringAsFixed(2)}')),
                                        // Joined Date
                                        DataCell(Text(joinedStr)),
                                        // Status Toggle Switch
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                user.blocked ? 'Blocked' : 'Active',
                                                style: TextStyle(
                                                  color: user.blocked ? Colors.redAccent : primaryGreen,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Switch(
                                                value: !user.blocked, // active = not blocked
                                                activeColor: primaryGreen,
                                                inactiveThumbColor: Colors.redAccent,
                                                onChanged: (val) async {
                                                  // Toggle: val is true -> user active -> blocked = false
                                                  final isBlocked = !val;
                                                  await provider.toggleUserBlockStatus(user.uid, isBlocked);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Actions: Delete
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                            tooltip: 'Delete User',
                                            onPressed: () {
                                              _showDeleteUserConfirmation(context, user, provider);
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteUserConfirmation(BuildContext context, UserModel user, UsersProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete User', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to permanently delete user "${user.name.isNotEmpty ? user.name : user.phone}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await provider.deleteUser(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'User deleted successfully' : 'Failed to delete user'),
                      backgroundColor: success ? const Color(0xFF0C831F) : Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class MarketplaceItemDetailScreen extends StatefulWidget {
  final String itemId;
  final String currentUserId;

  const MarketplaceItemDetailScreen({
    super.key,
    required this.itemId,
    required this.currentUserId,
  });

  @override
  State<MarketplaceItemDetailScreen> createState() =>
      _MarketplaceItemDetailScreenState();
}

class _MarketplaceItemDetailScreenState
    extends State<MarketplaceItemDetailScreen> {
  Map<String, dynamic>? item;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadItem();
  }

  Future<void> loadItem() async {
    try {
      final data = await ApiService.getMarketplaceItem(widget.itemId);
      setState(() {
        item = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Item not found')),
      );
    }

    final isFree = item!['price'] == 0 || item!['price'] == 0.0;
    final isOwner = item!['user_id'].toString() == widget.currentUserId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: item!['image_url'] != null
                  ? Image.network(
                      item!['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.shopping_bag, size: 100),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.shopping_bag, size: 100),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFree ? 'FREE' : '\$${item!['price']}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isFree ? Colors.green : Colors.blue,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item!['status']),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item!['status'].toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    item!['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Condition
                  Row(
                    children: [
                      const Icon(Icons.star, size: 20, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Condition: ${item!['condition']}'.toUpperCase(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category
                  Chip(
                    label: Text(item!['category'].toString().toUpperCase()),
                    backgroundColor: Colors.blue[100],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item!['description'] ?? 'No description provided',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  if (item!['location'] != null) ...[
                    const Text(
                      'Location',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          item!['location'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(),
                  const SizedBox(height: 16),

                  // Seller Info
                  const Text(
                    'Seller',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: item!['profile_image_url'] != null
                          ? NetworkImage(item!['profile_image_url'])
                          : null,
                      child: item!['profile_image_url'] == null
                          ? Text(item!['seller_name'][0].toUpperCase())
                          : null,
                    ),
                    title: Text(
                      item!['seller_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(item!['seller_email'] ?? ''),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (!isOwner && item!['status'] == 'available') ...[
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pushNamed(
                          context,
                          '/direct-messages',
                          arguments: {
                            'userId': widget.currentUserId,
                            'receiverId': item!['user_id'].toString(),
                            'receiverName': item!['user_name'] ?? 'Seller',
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Contact Seller',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  if (isOwner) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ApiService.updateMarketplaceItemStatus(
                                widget.itemId,
                                item!['status'] == 'available'
                                    ? 'sold'
                                    : 'available',
                              );
                              loadItem();
                            },
                            child: Text(
                              item!['status'] == 'available'
                                  ? 'Mark as Sold'
                                  : 'Mark as Available',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Item'),
                                  content: const Text(
                                      'Are you sure you want to delete this item?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                await ApiService.deleteMarketplaceItem(
                                    widget.itemId);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.grey;
      case 'reserved':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

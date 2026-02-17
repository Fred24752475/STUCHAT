import 'package:flutter/material.dart';
import 'dart:async';

import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/loading_skeleton.dart';

class FindFriendsScreen extends StatefulWidget {
  final String userId;

  const FindFriendsScreen({super.key, required this.userId});

  @override
  State<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends State<FindFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final users = await ApiService.getAvailableUsers(widget.userId);
      
      if (mounted) {
        setState(() {
          _users = users.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to load users', Colors.red);
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final requests = await ApiService.getFriendRequests(widget.userId);
      
      if (mounted) {
        setState(() {
          _friendRequests = requests.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      LoggerService.error('Error loading friend requests: $e');
      // Continue with empty list - Supabase doesn't have friends table
    }
  }

  Future<void> _loadSentRequests() async {
    try {
      final sentRequests = await ApiService.getSentFriendRequests(widget.userId);
      
      if (mounted) {
        setState(() {
          _sentRequests = sentRequests.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      LoggerService.error('Error loading sent requests: $e');
      // Continue with empty list
    }
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await ApiService.getFriends(widget.userId);
      
      if (mounted) {
        setState(() {
          _friends = friends.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      LoggerService.error('Error loading friends: $e');
      // Continue with empty list - Supabase doesn't have friends table
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    try {
      setState(() {
        _isSearching = true;
      });

      final success = await ApiService.sendFriendRequest(widget.userId, targetUserId);
      
      if (success && mounted) {
        // Add to sent requests list  
        try {
          final user = _users.firstWhere((user) => (user['user_id'] ?? user['id'] ?? '').toString() == targetUserId);
          setState(() {
            _sentRequests.add(user);
            _isSearching = false;
          });
          _showSnackBar('Friend request sent!', Colors.green);
        } catch (e) {
          setState(() {
            _isSearching = false;
          });
        }
      } else {
        setState(() {
          _isSearching = false;
        });
        _showSnackBar('Coming soon! Backend required for friends.', Colors.orange);
      }
    } catch (e) {
      LoggerService.error('Error sending friend request: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _showSnackBar('Coming soon! Backend required for friends.', Colors.orange);
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId, String requesterId) async {
    try {
      final success = await ApiService.acceptFriendRequest(requestId, widget.userId, requesterId);
      
      if (success && mounted) {
        final request = _friendRequests.firstWhere((req) => req['id'].toString() == requestId);
        setState(() {
          _friendRequests.removeWhere((req) => req['id'].toString() == requestId);
          _friends.insert(0, {
            'id': request['sender_id'],
            'name': request['name'],
            'email': request['email'],
            'profile_image_url': request['profile_image_url'],
            'course': request['course'],
            'year': request['year'],
          });
        });
        _showSnackBar('Friend request accepted! You are now friends.', Colors.green);
        _loadFriends(); // Refresh friends list
      }
    } catch (e) {
      LoggerService.error('Error accepting friend request: $e');
      if (mounted) {
        _showSnackBar('Failed to accept friend request', Colors.red);
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      final success = await ApiService.rejectFriendRequest(requestId, widget.userId);
      
      if (success && mounted) {
        setState(() {
          _friendRequests.removeWhere((req) => req['id'].toString() == requestId);
        });
        _showSnackBar('Friend request rejected', Colors.orange);
      }
    } catch (e) {
      LoggerService.error('Error rejecting friend request: $e');
      if (mounted) {
        _showSnackBar('Failed to reject friend request', Colors.red);
      }
    }
  }

  void _searchUsers(String query) {
    if (query.isEmpty) {
      _loadUsers();
      return;
    }

    final filtered = _users.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final searchLower = query.toLowerCase();
      return name.contains(searchLower) || email.contains(searchLower);
    }).toList();

    setState(() {
      _users = filtered;
    });
  }

    void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = (user['user_id'] ?? user['id'] ?? '').toString();
    final isFriend = _friends.any((friend) => (friend['user_id'] ?? friend['id'] ?? '').toString() == userId);
    final isRequested = _sentRequests.any((req) => (req['user_id'] ?? req['id'] ?? '').toString() == userId);
    final hasRequest = _friendRequests.any((req) => (req['sender_id'] ?? '').toString() == userId);
    final isCurrentUser = userId == widget.userId;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: user['profile_image_url'] != null 
                ? NetworkImage(user['profile_image_url']) 
                : null,
            child: user['profile_image_url'] == null 
                ? Icon(Icons.person, color: Colors.blue.shade700, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['email'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (user['course'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📚 ${user['course']} - Year ${user['year'] ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCurrentUser)
            const Text(
              'You',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            GlassButton(
              text: 'Add Friend',
              onPressed: () => _sendFriendRequest(userId),
              color: Colors.blue,
              isLoading: _isSearching,
            ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsSection() {
    if (_friendRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Friend Requests (${_friendRequests.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
        ..._friendRequests.map((request) => _buildFriendRequestCard(request)).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFriendRequestCard(Map<String, dynamic> request) {
    final userId = request['sender_id'].toString();
    final name = request['name'] ?? 'Unknown';
    final email = request['email'] ?? '';
    final imageUrl = request['profile_image_url'];

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.purple.shade100,
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null ? Icon(Icons.person, color: Colors.purple.shade700, size: 30) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _acceptFriendRequest(request['id'].toString(), userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Accept'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _rejectFriendRequest(request['id'].toString()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassTextField(
              controller: _searchController,
              hintText: 'Search users by name or email...',
              prefixIcon: Icons.search,
              onChanged: _searchUsers,
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: _isLoading 
                  ? const LoadingSkeleton()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Available users section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Suggested for You',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          
                          if (_users.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No users found',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._users.map((user) => _buildUserCard(user)).toList(),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
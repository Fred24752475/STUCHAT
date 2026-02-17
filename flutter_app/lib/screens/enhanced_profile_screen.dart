import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_background.dart';

class EnhancedProfileScreen extends StatefulWidget {
  final String userId;
  
  const EnhancedProfileScreen({super.key, required this.userId});

  @override
  State<EnhancedProfileScreen> createState() => _EnhancedProfileScreenState();
}

class _EnhancedProfileScreenState extends State<EnhancedProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _userProfile;
  List<dynamic> _userPosts = [];
  List<dynamic> _userFollowers = [];
  List<dynamic> _userFollowing = [];
  List<dynamic> _userBookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id.toString() ?? widget.userId;
      
      // Load all user data
      final profile = await ApiService.getUserProfile(userId);
      final posts = await ApiService.getUserPosts(userId);
      final followers = await ApiService.getFollowers(userId);
      final following = await ApiService.getFollowing(userId);
      final bookmarks = await ApiService.getBookmarks(userId);
      await ApiService.getUserStatistics(userId);
      
      setState(() {
        _userProfile = profile;
        _userPosts = posts;
        _userFollowers = followers;
        _userFollowing = following;
        _userBookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }



  void _updateProfile() async {
    try {
      await ApiService.updateProfile(widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: GlassBackground(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Profile Picture
                      GestureDetector(
                        onTap: () {
                          // TODO: Implement profile picture update
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile picture update coming soon!')),
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.2),
                            border: Border.all(color: Colors.blue, width: 3),
                          ),
                          child: _userProfile?['profile_image_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.network(
                                    _userProfile!['profile_image_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.blue,
                                        size: 40,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                            _userProfile?['name'] ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                            const SizedBox(height: 4),
                            Text(
                              _userProfile?['bio'] ?? 'No bio yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.school,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_userProfile?['course'] ?? 'Not specified'} • Year ${_userProfile?['year'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                GlassButton(
                                  text: 'Edit Profile',
                                  icon: Icons.edit,
                                  onPressed: _updateProfile,
                                ),
                                const SizedBox(width: 12),
                                GlassButton(
                                  text: 'Share Profile',
                                  icon: Icons.share,
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          // TODO: Implement profile picture update with image picker
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('📷 Photo upload coming soon!')),
                          );
                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats Row
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.blue.withOpacity(0.2),
                  Colors.purple.withOpacity(0.1),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('Posts', _userPosts.length.toString(), Icons.article),
                  _buildStatCard('Followers', _userFollowers.length.toString(), Icons.people),
                  _buildStatCard('Following', _userFollowing.length.toString(), Icons.person_add),
                ],
              ),
            ),

            // Tabs
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsTab(),
                    _buildBookmarksTab(),
                    _buildFollowersTab(),
                    _buildFollowingTab(),
                    _buildStatsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Posts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GlassButton(
                text: 'Create Post',
                icon: Icons.add,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // TODO: Navigate to create post screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✍️ Write post coming soon!')),
                          );
                        },
              ),
            ],
          ),
        ),
        Expanded(
          child: _userPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No posts yet',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Share your first thought!',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _userPosts.length,
                  itemBuilder: (context, index) {
                    final post = _userPosts[index];
                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['content'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.favorite, color: Colors.pink, size: 16),
                              const SizedBox(width: 4),
                              Text('${post['likes'] ?? 0}'),
                              const SizedBox(width: 16),
                              Icon(Icons.chat_bubble, color: Colors.blue, size: 16),
                              const SizedBox(width: 4),
                              Text('${post['comments'] ?? 0}'),
                              const Spacer(),
                              Text(
                                _formatTime(post['created_at']),
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookmarksTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Saved Posts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _userBookmarks.isEmpty
              ? const Center(
                  child: Text(
                    'No saved posts yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _userBookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = _userBookmarks[index];
                    return GlassCard(
                      child: ListTile(
                        leading: const Icon(Icons.bookmark, color: Colors.blue),
                        title: Text(
                          bookmark['post_content'] ?? 'Saved Post',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Saved ${_formatTime(bookmark['created_at'])}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // TODO: Implement unfollow functionality with confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('❌ Unfollow coming soon!')),
                          );
                        },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFollowersTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Followers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _userFollowers.isEmpty
              ? const Center(
                  child: Text(
                    'No followers yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _userFollowers.length,
                  itemBuilder: (context, index) {
                    final follower = _userFollowers[index];
                    return GlassCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[index % Colors.primaries.length],
                          child: Text(
                            (follower['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          follower['name'] ?? 'User',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          follower['course'] ?? 'Student',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        trailing: GlassButton(
                          text: 'Follow Back',
                          icon: Icons.person_add,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // TODO: Implement remove bookmark functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🗑️ Delete bookmark coming soon!')),
                          );
                        },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFollowingTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Following',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _userFollowing.isEmpty
              ? const Center(
                  child: Text(
                    'Not following anyone yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _userFollowing.length,
                  itemBuilder: (context, index) {
                    final following = _userFollowing[index];
                    return GlassCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[index % Colors.primaries.length],
                          child: Text(
                            (following['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          following['name'] ?? 'User',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          following['course'] ?? 'Student',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // TODO: Implement profile sharing with QR code
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🔗 Share profile coming soon!')),
                          );
                        },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Your Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Mock stats cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCardItem('Total Posts', '${_userPosts.length}', Icons.article, Colors.blue),
              _buildStatCardItem('Total Likes', '1,234', Icons.favorite, Colors.pink),
              _buildStatCardItem('Total Comments', '567', Icons.chat_bubble, Colors.green),
              _buildStatCardItem('Profile Views', '8,901', Icons.visibility, Colors.purple),
              _buildStatCardItem('Study Streak', '15 days', Icons.local_fire_department, Colors.orange),
              _buildStatCardItem('Rank', '#42', Icons.emoji_events, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardItem(String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Just now';
    }
  }
}
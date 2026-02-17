import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String currentUserId;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.currentUserId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? profile;
  List<dynamic> posts = [];
  List<dynamic> achievements = [];
  bool isFollowing = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadProfile();
    loadPosts();
    loadAchievements();
    checkFollowStatus();
  }

  Future<void> loadProfile() async {
    try {
      final data = await ApiService.getUserProfile(widget.userId);
      setState(() {
        profile = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadPosts() async {
    final data = await ApiService.getUserPosts(widget.userId);
    setState(() => posts = data);
  }

  Future<void> loadAchievements() async {
    final data = await ApiService.getUserAchievements(widget.userId);
    setState(() => achievements = data);
  }

  Future<void> checkFollowStatus() async {
    if (widget.userId == widget.currentUserId) return;
    final following =
        await ApiService.checkIfFollowing(widget.currentUserId, widget.userId);
    setState(() => isFollowing = following);
  }

  Future<void> toggleFollow() async {
    if (isFollowing) {
      await ApiService.unfollowUser(widget.currentUserId, widget.userId);
    } else {
      await ApiService.followUser(widget.currentUserId, widget.userId);
    }
    setState(() => isFollowing = !isFollowing);
    loadProfile(); // Refresh counts
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Profile not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(profile!['name']),
        actions: [
          if (widget.userId != widget.currentUserId)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // Show options menu
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profile!['profile_image_url'] != null
                      ? NetworkImage(profile!['profile_image_url'])
                      : null,
                  child: profile!['profile_image_url'] == null
                      ? Text(
                          profile!['name'][0].toUpperCase(),
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  profile!['name'],
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (profile!['bio'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile!['bio'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 8),
                Text('${profile!['course']} - Year ${profile!['year']}'),
                if (profile!['major'] != null)
                  Text('Major: ${profile!['major']}'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('Posts', profile!['posts_count'] ?? 0),
                    _buildStatColumn(
                        'Followers', profile!['followers_count'] ?? 0),
                    _buildStatColumn(
                        'Following', profile!['following_count'] ?? 0),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.userId != widget.currentUserId)
                  ElevatedButton(
                    onPressed: toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                  ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Achievements'),
            ],
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildAchievementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildPostsTab() {
    if (posts.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return PostCard(
          post: posts[index],
          currentUserId: widget.currentUserId,
          onUpdate: loadPosts,
        );
      },
    );
  }

  Widget _buildAchievementsTab() {
    if (achievements.isEmpty) {
      return const Center(child: Text('No achievements yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                achievement['icon'] ?? '🏆',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                achievement['name'],
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${achievement['points']} pts',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'user_profile_screen.dart';
import 'hashtag_posts_screen.dart';

class SearchScreen extends StatefulWidget {
  final String currentUserId;

  const SearchScreen({super.key, required this.currentUserId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> users = [];
  List<dynamic> posts = [];
  List<dynamic> hashtags = [];
  List<dynamic> discover = [];
  bool isLoading = false;

  // Track followed users with timestamp
  final Map<String, DateTime> _followedUsers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadDiscover();
    loadTrendingHashtags();
  }

  Future<void> loadDiscover() async {
    final data = await ApiService.discoverUsers(widget.currentUserId);
    setState(() => discover = data);
  }

  Future<void> loadTrendingHashtags() async {
    final data = await ApiService.getTrendingHashtags();
    setState(() => hashtags = data);
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;

    setState(() => isLoading = true);

    final userResults = await ApiService.searchUsers(query);
    final postResults = await ApiService.searchPosts(query);

    setState(() {
      users = userResults;
      posts = postResults;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search users, posts, hashtags...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: search,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Posts'),
            Tab(text: 'Hashtags'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(users),
          _buildPostsList(posts),
          _buildHashtagsList(hashtags),
          _buildDiscoverList(discover),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<dynamic> users) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (users.isEmpty) {
      return const Center(child: Text('No users found. Try searching!'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['profile_image_url'] != null
                ? NetworkImage(user['profile_image_url'])
                : null,
            child: user['profile_image_url'] == null
                ? Text(user['name'][0].toUpperCase())
                : null,
          ),
          title: Text(user['name']),
          subtitle: Text('${user['course']} - Year ${user['year']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.message, color: Colors.blue),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'userId': widget.currentUserId,
                      'otherUserId': user['id'].toString(),
                      'otherUserName': user['name'],
                      'otherUserImage': user['profile_image_url'],
                    },
                  );
                },
                tooltip: 'Message',
              ),
              IconButton(
                icon: const Icon(Icons.person, color: Colors.grey),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userId: user['id'].toString(),
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                  );
                },
                tooltip: 'View Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostsList(List<dynamic> posts) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (posts.isEmpty) {
      return const Center(child: Text('No posts found'));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: post['profile_image_url'] != null
                  ? NetworkImage(post['profile_image_url'])
                  : null,
            ),
            title: Text(post['user_name']),
            subtitle: Text(post['content'],
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
      },
    );
  }

  Widget _buildHashtagsList(List<dynamic> hashtags) {
    if (hashtags.isEmpty) {
      return const Center(child: Text('No trending hashtags'));
    }

    return ListView.builder(
      itemCount: hashtags.length,
      itemBuilder: (context, index) {
        final hashtag = hashtags[index];
        return ListTile(
          leading: const Icon(Icons.tag, color: Colors.blue),
          title: Text('#${hashtag['name']}'),
          subtitle: Text('${hashtag['usage_count']} posts'),
          trailing: const Icon(Icons.trending_up, color: Colors.orange),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HashtagPostsScreen(
                  hashtag: hashtag['name'],
                  currentUserId: widget.currentUserId,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiscoverList(List<dynamic> users) {
    if (users.isEmpty) {
      return const Center(child: Text('No suggestions'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user['profile_image_url'] != null
                  ? NetworkImage(user['profile_image_url'])
                  : null,
              child: user['profile_image_url'] == null
                  ? Text(user['name'][0].toUpperCase())
                  : null,
            ),
            title: Text(user['name']),
            subtitle:
                Text('${user['course']} - ${user['follower_count']} followers'),
            trailing: _buildFollowButton(user),
          ),
        );
      },
    );
  }

  Widget _buildFollowButton(Map<String, dynamic> user) {
    final userId = user['id'].toString();
    final isFollowed = _followedUsers.containsKey(userId);

    return ElevatedButton.icon(
      onPressed: isFollowed
          ? null
          : () async {
              await ApiService.followUser(widget.currentUserId, userId);
              if (mounted) {
                setState(() {
                  _followedUsers[userId] = DateTime.now();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Following ${user['name']}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
      icon: Icon(
        isFollowed ? Icons.check : Icons.person_add,
        size: 18,
      ),
      label: Text(isFollowed ? 'Following' : 'Follow'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowed ? Colors.green : null,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool showFollowers; // true = followers, false = following

  const FollowersListScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.showFollowers = true,
  });

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showFollowers ? 0 : 1,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final followers = await ApiService.getFollowers(widget.userId);
    final following = await ApiService.getFollowing(widget.userId);

    setState(() {
      _followers = followers;
      _following = following;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Followers (${_followers.length})'),
            Tab(text: 'Following (${_following.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_followers, 'No followers yet'),
                _buildUserList(_following, 'Not following anyone yet'),
              ],
            ),
    );
  }

  Widget _buildUserList(List<dynamic> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
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
            title: Text(
              user['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(user['course'] ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: user['id'].toString(),
                    currentUserId: widget.userId,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

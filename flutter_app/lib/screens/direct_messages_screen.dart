import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import 'real_time_chat_screen.dart';
import 'all_users_screen.dart';
import 'find_friends_screen.dart';

class DirectMessagesScreen extends StatefulWidget {
  final String userId;

  const DirectMessagesScreen({super.key, required this.userId});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  List<dynamic> conversations = [];
  List<dynamic> friends = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadConversations();
    loadFriends();
  }

  Future<void> loadFriends() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final friendsList = await ApiService.getFollowing(widget.userId);
      
      if (mounted) {
        setState(() {
          friends = friendsList;
          isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading friends: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load friends';
        });
      }
    }
  }

  Future<void> loadConversations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getConversations(widget.userId);
      if (mounted) {
        setState(() {
          conversations = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          conversations = [];
          isLoading = false;
          errorMessage = 'Could not load conversations';
        });
      }
    }
  }

  void startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllUsersScreen(currentUserId: widget.userId),
      ),
    ).then((_) => loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Messages'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FindFriendsScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'Find Friends',
          ),
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: startNewChat,
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: startNewChat,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: startNewChat,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Friends Dashboard Section
    if (friends.isNotEmpty) {
      return Column(
        children: [
          // Friends Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Your Friends (${friends.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Friends List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: friend['profile_image_url'] != null
                      ? NetworkImage(friend['profile_image_url'])
                      : null,
                  child: friend['profile_image_url'] == null
                      ? Icon(Icons.person, color: Colors.blue.shade700, size: 25)
                      : null,
                ),
                title: Text(
                  friend['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  friend['email'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RealTimeChatScreen(
                          userId: widget.userId,
                          otherUserId: friend['id'].toString(),
                          otherUserName: friend['name'],
                          otherUserImage: friend['profile_image_url'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const Divider(height: 1),
        ],
      );
    }

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start chatting with your friends!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: startNewChat,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue,
                  backgroundImage: conv['profile_image_url'] != null
                      ? NetworkImage(conv['profile_image_url'])
                      : null,
                  child: conv['profile_image_url'] == null
                      ? Text(
                          (conv['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (conv['unread_count'] != null && conv['unread_count'] > 0)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${conv['unread_count']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              conv['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              conv['last_message'] ?? 'Start chatting...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: conv['last_message_time'] != null
                ? Text(
                    _formatTime(conv['last_message_time']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RealTimeChatScreen(
                    userId: widget.userId,
                    otherUserId: conv['other_user_id'].toString(),
                    otherUserName: conv['name'] ?? 'User',
                    otherUserImage: conv['profile_image_url'],
                  ),
                ),
              ).then((_) => loadConversations());
            },
          ),
        );
      },
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (e) {
      return '';
    }
  }
}

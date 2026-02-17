import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'real_time_chat_screen.dart';
import 'user_profile_screen.dart';

class AllUsersScreen extends StatefulWidget {
  final String currentUserId;

  const AllUsersScreen({super.key, required this.currentUserId});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAllUsers();
  }

  Future<void> loadAllUsers() async {
    try {
      print('🔍 Loading users from API...');
      final data = await ApiService.searchUsers('');
      print('✅ Received ${data.length} users from API');

      setState(() {
        users = data
            .where((u) => u['id'].toString() != widget.currentUserId)
            .toList();
        filteredUsers = users;
        isLoading = false;
      });

      print(
          '✅ Filtered to ${filteredUsers.length} users (excluding current user)');
    } catch (e) {
      print('❌ Error loading users: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  void filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers = users.where((user) {
          final name = user['name'].toString().toLowerCase();
          final course = user['course'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || course.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Start New Chat'),
        backgroundColor: Colors.blue,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: filterUsers,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No users found'
                            : 'No users match your search',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage: user['profile_image_url'] != null
                              ? NetworkImage(user['profile_image_url'])
                              : null,
                          child: user['profile_image_url'] == null
                              ? Text(
                                  user['name'][0].toUpperCase(),
                                  style: const TextStyle(fontSize: 20),
                                )
                              : null,
                        ),
                        title: Text(
                          user['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            Text('${user['course']} - Year ${user['year']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.message, color: Colors.blue),
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RealTimeChatScreen(
                                      userId: widget.currentUserId,
                                      otherUserId: user['id'].toString(),
                                      otherUserName: user['name'],
                                      otherUserImage: user['profile_image_url'],
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Message',
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.person, color: Colors.grey),
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
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RealTimeChatScreen(
                                userId: widget.currentUserId,
                                otherUserId: user['id'].toString(),
                                otherUserName: user['name'],
                                otherUserImage: user['profile_image_url'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

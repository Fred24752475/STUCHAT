import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  final String currentUserId;

  const LeaderboardScreen({super.key, required this.currentUserId});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    try {
      final data = await ApiService.getLeaderboard();
      setState(() {
        users = data['users'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? const Center(child: Text('No data yet'))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final rank = index + 1;

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: user['profile_image_url'] != null
                                ? NetworkImage(user['profile_image_url'])
                                : null,
                            child: user['profile_image_url'] == null
                                ? Text(user['name'][0].toUpperCase())
                                : null,
                          ),
                          if (rank <= 3)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? Colors.amber
                                      : rank == 2
                                          ? Colors.grey
                                          : Colors.brown,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  rank == 1
                                      ? '🥇'
                                      : rank == 2
                                          ? '🥈'
                                          : '🥉',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Text(
                            '#$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rank <= 3 ? Colors.orange : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(user['name'])),
                        ],
                      ),
                      subtitle:
                          Text('${user['achievement_count']} achievements'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${user['total_points'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Text(
                            'points',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () {
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
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import '../services/socket_service.dart';
import '../screens/feed_screen.dart';
import '../screens/search_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/groups_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/find_friends_screen.dart';
import '../screens/study_groups_list_screen.dart';
import '../screens/campus_map_screen.dart';
import '../screens/events_screen.dart';
import '../screens/courses_screen.dart';
import '../screens/anonymous_secrets_screen.dart';
import '../screens/study_reels_screen.dart';
import '../screens/tiktok_live_stream_screen.dart';
import '../screens/birthday_reminders_screen.dart';
import '../screens/call_history_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/analytics_dashboard_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/unified_ai_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/direct_messages_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, this.userId = '1'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Initialize Socket.IO connection
    try {
      if (!SocketService.isConnected) {
        SocketService.connect(widget.userId);
      }
    } catch (e) {
      LoggerService.error('Failed to connect to Socket.IO: $e');
    }

    // Initialize screens
    _screens = [
      FeedScreen(userId: widget.userId),
      SearchScreen(currentUserId: widget.userId),
      MarketplaceScreen(userId: widget.userId),
      GroupsScreen(userId: widget.userId),
      ProfileScreen(userId: widget.userId),
    ];
  }

  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade400],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Student User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'student@university.edu',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blue),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.search, color: Colors.green),
            title: const Text('Search'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SearchScreen(currentUserId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.purple),
            title: const Text('Find Friends'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FindFriendsScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups, color: Colors.orange),
            title: const Text('Study Groups'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      StudyGroupsListScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.brown),
            title: const Text('Campus Map'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampusMapScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event, color: Colors.purple),
            title: const Text('Events'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school, color: Colors.blue),
            title: const Text('Courses'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoursesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.purple),
            title: const Text('Anonymous Secrets'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnonymousSecretsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library, color: Colors.red),
            title: const Text('Study Reels'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudyReelsScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.red),
            title: const Text('STUCHAT Live'),
            subtitle: const Text('definately like Tiktok'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TikTokLiveStreamScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.pink),
            title: const Text('Birthday Reminders'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BirthdayRemindersScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.green),
            title: const Text('Call History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CallHistoryScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark, color: Colors.amber),
            title: const Text('Bookmarks'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookmarksScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.indigo),
            title: const Text('Analytics Dashboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AnalyticsDashboardScreen(userId: widget.userId),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.orange),
            title: const Text('Leaderboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LeaderboardScreen(currentUserId: widget.userId),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('𝓢𝓣𝓤𝓒𝓗𝓐𝓣'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'Create Post',
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UnifiedAIScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'AI Assistant',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NotificationsScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DirectMessagesScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'Messages',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

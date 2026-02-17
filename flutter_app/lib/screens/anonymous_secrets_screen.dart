import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import '../services/socket_service.dart';
import '../screens/feed_screen.dart';
import '../screens/search_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/groups_screen.dart';
import '../screens/profile_screen.dart';

class AnonymousSecretsScreen extends StatefulWidget {
  final String userId;

  const AnonymousSecretsScreen({super.key, this.userId = '1'});

  @override
  State<AnonymousSecretsScreen> createState() => _AnonymousSecretsScreenState();
}

class _AnonymousSecretsScreenState extends State<AnonymousSecretsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
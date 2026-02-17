import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/story_circle.dart';
import '../widgets/glass_background.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/empty_state.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import 'stories_screen.dart';
import 'story_viewer_screen.dart';

class FeedScreen extends StatefulWidget {
  final String userId;
  
  const FeedScreen({super.key, required this.userId});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> stories = [];
  int unreadNotifications = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      feedProvider.setToken(authProvider.token);
      feedProvider.fetchPosts(refresh: true);
      loadStories();
      loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      if (!feedProvider.isLoading && feedProvider.hasMore) {
        feedProvider.loadMore();
      }
    }
  }

  Future<void> loadStories() async {
    try {
      final data = await ApiService.getStories();
      if (mounted) {
        setState(() => stories = data);
      }
    } catch (e) {
      LoggerService.error('Failed to load stories', e);
    }
  }

  Future<void> loadUnreadCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      try {
        final data = await ApiService.getUnreadCount(
            authProvider.currentUser!.id.toString());
        if (mounted) {
          setState(() => unreadNotifications = data['count'] ?? 0);
        }
      } catch (e) {
        LoggerService.error('Failed to load unread count', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id.toString() ?? '1';

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Stories Section
            Container(
              height: 110,
              margin: const EdgeInsets.only(top: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (!mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StoriesScreen(userId: currentUserId),
                        ),
                      );
                      if (result == true && mounted) {
                        loadStories();
                      }
                    },
                    child: const StoryCircle(name: 'Your Story', isOwn: true),
                  ),
                  ...stories.map((story) => GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final storyIndex = stories.indexOf(story);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryViewerScreen(
                                stories: stories,
                                initialIndex: storyIndex,
                                currentUserId: currentUserId,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) loadStories();
                          });
                        },
                        child: StoryCircle(
                          name: story['user_name'] ?? 'User',
                          imageUrl: story['profile_image_url'],
                        ),
                      )),
                ],
              ),
            ),
            // Posts Feed
            Expanded(
              child: Consumer<FeedProvider>(
                builder: (context, feedProvider, child) {
                  if (feedProvider.isLoading && feedProvider.posts.isEmpty) {
                    return const LoadingSkeleton();
                  }

                  if (feedProvider.posts.isEmpty) {
                    return EmptyState(
                      title: 'No posts yet',
                      message: 'Be the first to share something!',
                      icon: Icons.post_add,
                      actionLabel: 'Create Post',
                      onAction: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pushNamed(context, '/create-post');
                      },
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      await Future.wait([
                        feedProvider.fetchPosts(refresh: true),
                        loadStories(),
                      ]);
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: feedProvider.posts.length +
                          (feedProvider.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == feedProvider.posts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return PostCard(
                          post: feedProvider.posts[index],
                          currentUserId: currentUserId,
                          onUpdate: () {
                            feedProvider.fetchPosts(refresh: true);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

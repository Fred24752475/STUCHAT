import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/post_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_scaffold.dart';

class HashtagPostsScreen extends StatefulWidget {
  final String hashtag;
  final String currentUserId;

  const HashtagPostsScreen({
    super.key,
    required this.hashtag,
    required this.currentUserId,
  });

  @override
  State<HashtagPostsScreen> createState() => _HashtagPostsScreenState();
}

class _HashtagPostsScreenState extends State<HashtagPostsScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await ApiService.getHashtagPosts(widget.hashtag);
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load hashtag posts', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load posts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '#${widget.hashtag}',
      body: _isLoading
          ? const LoadingSkeleton()
          : _posts.isEmpty
              ? EmptyState(
                  title: 'No posts found',
                  message: 'Be the first to post with #${widget.hashtag}',
                  icon: Icons.tag,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    await _loadPosts();
                  },
                  child: ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                        post: _posts[index],
                        currentUserId: widget.currentUserId,
                        onUpdate: _loadPosts,
                      );
                    },
                  ),
                ),
    );
  }
}

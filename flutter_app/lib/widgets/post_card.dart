import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class PostCard extends StatefulWidget {
  final dynamic post;
  final String currentUserId;
  final VoidCallback? onUpdate;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onUpdate,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  bool isBookmarked = false;
  int likeCount = 0;
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes'] ?? 0;
    commentCount = widget.post['comments'] ?? 0;
    checkLikeStatus();
    checkBookmarkStatus();
  }

  Future<void> checkLikeStatus() async {
    final liked = await ApiService.checkIfLiked(
      widget.post['id'].toString(),
      widget.currentUserId,
    );
    setState(() => isLiked = liked);
  }

  Future<void> checkBookmarkStatus() async {
    final bookmarked = await ApiService.checkIfBookmarked(
      widget.currentUserId,
      widget.post['id'].toString(),
    );
    setState(() => isBookmarked = bookmarked);
  }

  Future<void> toggleLike() async {
    try {
      if (isLiked) {
        // Currently liked - unlike it
        await ApiService.unlikePost(
          widget.post['id'].toString(),
          widget.currentUserId,
        );
        setState(() {
          isLiked = false;
          likeCount = (likeCount > 0) ? likeCount - 1 : 0;
        });
      } else {
        // Currently not liked - like it
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/posts/${widget.post['id']}/like'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': widget.currentUserId}),
        );
        
        if (response.statusCode == 201) {
          setState(() {
            isLiked = true;
            likeCount += 1;
          });
        } else if (response.statusCode == 200) {
          // Backend says already liked - this shouldn't happen if UI is correct
          final data = jsonDecode(response.body);
          if (data['alreadyLiked'] == true) {
            await ApiService.unlikePost(
              widget.post['id'].toString(),
              widget.currentUserId,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> toggleBookmark() async {
    try {
      final result = await ApiService.toggleBookmark(
        widget.currentUserId,
        widget.post['id'].toString(),
      );
      setState(() => isBookmarked = result['bookmarked']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isBookmarked ? 'Post saved' : 'Post removed from saved'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsSheet(
        postId: widget.post['id'].toString(),
        userId: widget.currentUserId,
        onCommentAdded: () {
          setState(() => commentCount++);
        },
      ),
    );
  }

  void showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ApiService.sharePost(
                    widget.post['id'].toString(),
                    widget.currentUserId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post shared!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  backgroundImage: widget.post['profile_image_url'] != null
                      ? NetworkImage(widget.post['profile_image_url'])
                      : null,
                  child: widget.post['profile_image_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post['user_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatTime(widget.post['created_at']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: isBookmarked
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54,
                  ),
                  onPressed: toggleBookmark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.post['content'] ?? ''),
          if (widget.post['image_url'] != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.post['image_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: '$likeCount',
                color: isLiked ? Colors.red : null,
                onTap: toggleLike,
              ),
              _buildActionButton(
                icon: Icons.comment_outlined,
                label: '$commentCount',
                onTap: showCommentsSheet,
              ),
              _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: showShareDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }
}

class CommentsSheet extends StatefulWidget {
  final String postId;
  final String userId;
  final VoidCallback onCommentAdded;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.userId,
    required this.onCommentAdded,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<dynamic> comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadComments();
  }

  Future<void> loadComments() async {
    try {
      final data = await ApiService.getComments(widget.postId);
      setState(() {
        comments = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await ApiService.commentOnPost(
        widget.postId,
        widget.userId,
        _commentController.text.trim(),
      );
      _commentController.clear();
      widget.onCommentAdded();
      loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await ApiService.deletePostComment(widget.postId, commentId, widget.userId);
      loadComments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Comment deleted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : comments.isEmpty
                        ? const Center(child: Text('No comments yet'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      comment['profile_image_url'] != null
                                          ? NetworkImage(
                                              comment['profile_image_url'])
                                          : null,
                                  child: comment['profile_image_url'] == null
                                      ? Text(
                                          comment['user_name'][0].toUpperCase())
                                      : null,
                                ),
                                title: Text(
                                  comment['user_name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(comment['content']),
                                trailing: comment['user_id']?.toString() == widget.userId
                                    ? IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => deleteComment(comment['id'].toString()),
                                      )
                                    : null,
                              );
                            },
                          ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: addComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

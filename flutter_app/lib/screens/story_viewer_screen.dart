import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<dynamic> stories;
  final int initialIndex;
  final String currentUserId;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.currentUserId,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int currentIndex;
  late AnimationController _progressController;
  Timer? _timer;
  final Duration _storyDuration = const Duration(seconds: 5);
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  List<dynamic> _reactions = [];
  bool _showComments = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    );

    _startStory();
    _markAsViewed();
    _loadComments();
    _loadReactions();
  }

  void _startStory() {
    _progressController.forward(from: 0.0);
    _timer = Timer(_storyDuration, _nextStory);
  }

  void _nextStory() {
    if (currentIndex < widget.stories.length - 1) {
      setState(() {
        currentIndex++;
        _comments = [];
        _reactions = [];
      });
      _progressController.reset();
      _startStory();
      _markAsViewed();
      _loadComments();
      _loadReactions();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _comments = [];
        _reactions = [];
      });
      _timer?.cancel();
      _progressController.reset();
      _startStory();
      _loadComments();
      _loadReactions();
    }
  }

  void _pauseStory() {
    if (!_isPaused) {
      _timer?.cancel();
      _progressController.stop();
      setState(() => _isPaused = true);
    }
  }

  void _resumeStory() {
    if (_isPaused) {
      _progressController.forward();
      final remaining = _storyDuration * (1 - _progressController.value);
      _timer = Timer(remaining, _nextStory);
      setState(() => _isPaused = false);
    }
  }

  Future<void> _markAsViewed() async {
    try {
      final story = widget.stories[currentIndex];
      await ApiService.viewStory(
        story['id'].toString(),
        widget.currentUserId,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadComments() async {
    try {
      final story = widget.stories[currentIndex];
      final comments =
          await ApiService.getStoryComments(story['id'].toString());
      setState(() => _comments = comments);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadReactions() async {
    try {
      final story = widget.stories[currentIndex];
      final reactions =
          await ApiService.getStoryReactions(story['id'].toString());
      setState(() => _reactions = reactions);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final story = widget.stories[currentIndex];
      await ApiService.addStoryComment(
        story['id'].toString(),
        widget.currentUserId,
        _commentController.text.trim(),
      );
      _commentController.clear();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addReaction(String reactionType) async {
    try {
      final story = widget.stories[currentIndex];
      await ApiService.addStoryReaction(
        story['id'].toString(),
        widget.currentUserId,
        reactionType,
      );
      _loadReactions();

      // Show reaction animation
      _showReactionAnimation(reactionType);
    } catch (e) {
      // Silently fail
    }
  }

  void _showReactionAnimation(String reactionType) {
    final emoji = _getReactionEmoji(reactionType);
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Center(
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 100),
                ),
              ),
            );
          },
          onEnd: () => Navigator.pop(context),
        ),
      ),
    );
  }

  String _getReactionEmoji(String reactionType) {
    switch (reactionType) {
      case 'love':
        return '❤️';
      case 'laugh':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'fire':
        return '🔥';
      default:
        return '👍';
    }
  }

  void _showReactionPicker() {
    _pauseStory();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'React to Story',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ReactionButton(
                  emoji: '❤️',
                  label: 'Love',
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction('love');
                    _resumeStory();
                  },
                ),
                _ReactionButton(
                  emoji: '😂',
                  label: 'Laugh',
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction('laugh');
                    _resumeStory();
                  },
                ),
                _ReactionButton(
                  emoji: '😮',
                  label: 'Wow',
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction('wow');
                    _resumeStory();
                  },
                ),
                _ReactionButton(
                  emoji: '😢',
                  label: 'Sad',
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction('sad');
                    _resumeStory();
                  },
                ),
                _ReactionButton(
                  emoji: '🔥',
                  label: 'Fire',
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction('fire');
                    _resumeStory();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((_) => _resumeStory());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          if (_showComments) return;
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        child: Stack(
          children: [
            // Story Content
            Center(
              child: story['image_url'] != null
                  ? Image.network(
                      story['image_url'],
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      color: Colors.blue,
                      child: Center(
                        child: Text(
                          story['content'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),

            // Progress Indicators
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  widget.stories.length,
                  (index) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: index < currentIndex
                          ? Container(color: Colors.white)
                          : index == currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (context, child) {
                                    return LinearProgressIndicator(
                                      value: _progressController.value,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.3),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
            ),

            // User Info
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: story['profile_image_url'] != null
                        ? NetworkImage(story['profile_image_url'])
                        : null,
                    child: story['profile_image_url'] == null
                        ? Text(story['user_name'][0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story['user_name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getTimeAgo(story['created_at']),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Reactions Display
            if (_reactions.isNotEmpty)
              Positioned(
                top: 120,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: _reactions.map((reaction) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getReactionEmoji(reaction['reaction_type']),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${reaction['count']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // View Count (if it's user's own story)
            if (story['user_id'].toString() == widget.currentUserId)
              Positioned(
                bottom: 100,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${story['views'] ?? 0} views',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

            // Comments Section
            if (_showComments)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Comments (${_comments.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _showComments = false);
                                _resumeStory();
                              },
                            ),
                          ],
                        ),
                      ),
                      // Comments List
                      Expanded(
                        child: _comments.isEmpty
                            ? const Center(
                                child: Text('No comments yet'),
                              )
                            : ListView.builder(
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final comment = _comments[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          comment['profile_image_url'] != null
                                              ? NetworkImage(
                                                  comment['profile_image_url'])
                                              : null,
                                      child:
                                          comment['profile_image_url'] == null
                                              ? Text(comment['user_name'][0]
                                                  .toUpperCase())
                                              : null,
                                    ),
                                    title: Text(
                                      comment['user_name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(comment['text']),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Actions
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _pauseStory();
                        setState(() => _showComments = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.comment,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _comments.isEmpty
                                  ? 'Add comment...'
                                  : '${_comments.length} comments',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.favorite_border,
                        color: Colors.white, size: 28),
                    onPressed: _showReactionPicker,
                  ),
                ],
              ),
            ),

            // Comment Input (when comments are shown)
            if (_showComments)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: _sendComment,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(String timestamp) {
    final time = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _ReactionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

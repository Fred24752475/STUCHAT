import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/live_stream.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class LiveStreamViewerScreen extends StatefulWidget {
  final int streamId;

  const LiveStreamViewerScreen({super.key, required this.streamId});

  @override
  State<LiveStreamViewerScreen> createState() => _LiveStreamViewerScreenState();
}

class _LiveStreamViewerScreenState extends State<LiveStreamViewerScreen> {
  LiveStream? _stream;
  final List<StreamComment> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  bool _showComments = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadStream();
  }

  Future<void> _loadStream() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final stream = await ApiService.getLiveStream(widget.streamId);

      setState(() {
        _stream = stream;
        _isLoading = false;
      });

      // Join stream
      await ApiService.joinLiveStream(authProvider.token!, widget.streamId);

      // Socket events
      SocketService.socket?.emit('join_stream', {
        'streamId': widget.streamId,
        'userId': authProvider.currentUser?.id,
        'username': authProvider.currentUser?.username,
      });

      // Listen for new comments
      SocketService.socket?.on('new_stream_comment', (data) {
        final comment = StreamComment.fromJson(data);
        setState(() {
          _comments.add(comment);
          if (_comments.length > 50) {
            _comments.removeAt(0);
          }
        });
      });

      // Listen for gifts
      SocketService.socket?.on('new_stream_gift', (data) {
        final gift = StreamGift.fromJson(data);
        _showGiftAnimation(gift);
      });

      // Listen for stream end
      SocketService.socket?.on('stream_ended', (_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Stream Ended'),
              content: const Text('This live stream has ended.'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      });

      // Load existing comments
      _loadComments();
      
      // Initialize video player for live stream
      _initializeVideoPlayer();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stream: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // For demo purposes, we'll use a placeholder video
      // In a real implementation, you'd use the stream URL from the backend
      const demoVideoUrl = 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4';
      
      _videoController = VideoPlayerController.networkUrl(Uri.parse(demoVideoUrl));
      await _videoController!.initialize();
      await _videoController!.play();
      await _videoController!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      // If video fails to load, continue without video
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ApiService.getLiveStreamComments(widget.streamId);
      setState(() {
        _comments.clear();
        _comments.addAll(comments.cast<StreamComment>());
      });
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final comment = await ApiService.sendLiveStreamComment(
        authProvider.token!,
        widget.streamId,
        text,
      );

      // Emit to socket
      SocketService.socket?.emit('stream_comment', {
        'streamId': widget.streamId,
        'comment': comment,
      });

      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send comment: $e')),
        );
      }
    }
  }

  Future<void> _sendGift(String giftType) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final gift = await ApiService.sendLiveStreamGift(
        authProvider.token!,
        widget.streamId,
        giftType,
      );

      // Emit to socket
      SocketService.socket?.emit('stream_gift', {
        'streamId': widget.streamId,
        'gift': gift,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send gift: $e')),
        );
      }
    }
  }

  void _showGiftAnimation(StreamGift gift) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Center(
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getGiftEmoji(gift.giftType),
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${gift.username} sent ${gift.amount}x ${gift.giftType}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          onEnd: () => Navigator.pop(context),
        ),
      ),
    );
  }

  String _getGiftEmoji(String giftType) {
    switch (giftType) {
      case 'heart':
        return '❤️';
      case 'star':
        return '⭐';
      case 'fire':
        return '🔥';
      case 'clap':
        return '👏';
      case 'gift':
        return '🎁';
      default:
        return '👍';
    }
  }

  void _showGiftPicker() {
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
              'Send a Gift',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GiftButton(
                  emoji: '❤️',
                  label: 'Heart',
                  onTap: () {
                    Navigator.pop(context);
                    _sendGift('heart');
                  },
                ),
                _GiftButton(
                  emoji: '⭐',
                  label: 'Star',
                  onTap: () {
                    Navigator.pop(context);
                    _sendGift('star');
                  },
                ),
                _GiftButton(
                  emoji: '🔥',
                  label: 'Fire',
                  onTap: () {
                    Navigator.pop(context);
                    _sendGift('fire');
                  },
                ),
                _GiftButton(
                  emoji: '👏',
                  label: 'Clap',
                  onTap: () {
                    Navigator.pop(context);
                    _sendGift('clap');
                  },
                ),
                _GiftButton(
                  emoji: '🎁',
                  label: 'Gift',
                  onTap: () {
                    Navigator.pop(context);
                    _sendGift('gift');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video stream or placeholder
            _isVideoInitialized && _videoController != null
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam,
                          size: 120,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Live Stream',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connecting to stream...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: _stream?.profilePicture != null
                          ? NetworkImage(_stream!.profilePicture!)
                          : null,
                      child: _stream?.profilePicture == null
                          ? Text(_stream?.username[0].toUpperCase() ?? 'U')
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stream?.username ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _stream?.title ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

            // Comments section
            if (_showComments)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Container(
                  height: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[_comments.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${comment.username}: ',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: comment.text,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendComment,
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.card_giftcard, color: Colors.white),
                      onPressed: _showGiftPicker,
                    ),
                    IconButton(
                      icon: Icon(
                        _showComments
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() => _showComments = !_showComments);
                      },
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

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Leave stream
    ApiService.leaveLiveStream(authProvider.token!, widget.streamId);
    SocketService.socket?.emit('leave_stream', {
      'streamId': widget.streamId,
      'userId': authProvider.currentUser?.id,
      'username':
          authProvider.currentUser?.username ?? authProvider.currentUser?.name,
    });

    _commentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}

class _GiftButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _GiftButton({
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../models/study_reel.dart';
import '../widgets/glass_button.dart';
import 'create_study_reel_screen.dart';

class StudyReelsScreen extends StatefulWidget {
  final String userId;
  
  const StudyReelsScreen({super.key, required this.userId});

  @override
  State<StudyReelsScreen> createState() => _StudyReelsScreenState();
}

class _StudyReelsScreenState extends State<StudyReelsScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  List<StudyReel> _reels = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 10;
  
  // Video controllers for each reel
  Map<int, VideoPlayerController> _videoControllers = {};
  Map<int, bool> _videoInitialized = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeAllVideoControllers();
    super.dispose();
  }

  void _disposeAllVideoControllers() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _videoInitialized.clear();
  }

  Future<void> _loadReels({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
      });
      _disposeAllVideoControllers();
      _reels.clear();
    }
    
    try {
      final response = await ApiService.getStudyReelsFeed(
        limit: _limit,
        offset: _offset,
        userId: widget.userId,
      );
      
      if (response['success'] != false) {
        final List<dynamic> reelsData = response['reels'] ?? response;
        final List<StudyReel> newReels = reelsData
            .map((json) => StudyReel.fromJson(json))
            .toList();
        
        setState(() {
          if (refresh) {
            _reels = newReels;
          } else {
            _reels.addAll(newReels);
          }
          _offset += newReels.length;
          _hasMore = newReels.length == _limit;
          _isLoading = false;
        });
        
        // Initialize video controllers for new reels
        _initializeVideoControllers();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      LoggerService.error('Failed to load reels', e);
      setState(() => _isLoading = false);
    }
  }

  void _initializeVideoControllers() {
    for (int i = 0; i < _reels.length; i++) {
      final reel = _reels[i];
      if (!_videoControllers.containsKey(reel.id) && reel.videoUrl.isNotEmpty) {
        try {
          final controller = VideoPlayerController.network(reel.videoUrl);
          _videoControllers[reel.id] = controller;
          _videoInitialized[reel.id] = false;
          
          controller.initialize().then((_) {
            setState(() {
              _videoInitialized[reel.id] = true;
            });
            
            // Auto-play current video
            if (i == _currentIndex) {
              controller.play();
              controller.setLooping(true);
            }
          }).catchError((error) {
            LoggerService.error('Failed to initialize video ${reel.id}', error);
          });
        } catch (e) {
          LoggerService.error('Error creating video controller for ${reel.id}', e);
        }
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    
    // Pause all videos
    for (var controller in _videoControllers.values) {
      controller.pause();
    }
    
    // Play current video
    if (index < _reels.length) {
      final currentReel = _reels[index];
      final controller = _videoControllers[currentReel.id];
      if (controller != null && _videoInitialized[currentReel.id] == true) {
        controller.play();
        controller.setLooping(true);
      }
      
      // Increment view count
      ApiService.incrementStudyReelView(currentReel.id.toString());
    }
    
    // Load more reels when near the end
    if (index >= _reels.length - 3 && _hasMore && !_isLoading) {
      _loadReels();
    }
  }

  Future<void> _toggleLike(StudyReel reel) async {
    try {
      HapticFeedback.lightImpact();
      
      final response = await ApiService.toggleStudyReelLike(
        reel.id.toString(),
        widget.userId,
      );
      
      if (response['success'] == true) {
        setState(() {
          final index = _reels.indexWhere((r) => r.id == reel.id);
          if (index != -1) {
            final isLiked = response['liked'] ?? !reel.userLiked!;
            final newLikes = isLiked ? reel.likes + 1 : reel.likes - 1;
            _reels[index] = reel.copyWith(
              userLiked: isLiked,
              likes: newLikes,
            );
          }
        });
      }
    } catch (e) {
      LoggerService.error('Failed to toggle like', e);
    }
  }

  Future<void> _shareReel(StudyReel reel) async {
    try {
      HapticFeedback.lightImpact();
      await ApiService.shareStudyReel(reel.id.toString(), widget.userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔗 Share link copied!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      LoggerService.error('Failed to share reel', e);
    }
  }

  void _showComments(StudyReel reel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildCommentsSheet(reel),
    );
  }

  Widget _buildCommentsSheet(StudyReel reel) {
    final commentController = TextEditingController();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${reel.commentsCount} Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Comments List
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: ApiService.getPostComments(reel.id.toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }
                
                final comments = snapshot.data ?? [];
                
                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet\nBe the first to comment!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.primaries[index % Colors.primaries.length],
                            child: Text(
                              (comment['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['name'] ?? 'Anonymous',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['content'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GlassButton(
                  text: '',
                  icon: Icons.send,
                  color: Colors.blue,
                  onPressed: () async {
                    if (commentController.text.trim().isNotEmpty) {
                      try {
                        await ApiService.addStudyReelComment(
                          reel.id.toString(),
                          widget.userId,
                          commentController.text.trim(),
                        );
                        commentController.clear();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comment added!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        LoggerService.error('Failed to add comment', e);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewReel() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStudyReelScreen(userId: widget.userId),
      ),
    );
    
    if (result == true) {
      // Refresh the feed
      _loadReels(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading && _reels.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : _reels.isEmpty
              ? _buildEmptyState()
              : Stack(
                  children: [
                    // Reels PageView
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      onPageChanged: _onPageChanged,
                      itemCount: _reels.length,
                      itemBuilder: (context, index) {
                        return _buildReelPlayer(_reels[index]);
                      },
                    ),
                    
                    // Top Bar
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const Text(
                              'Study Reels',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _createNewReel,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.white54,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'No Study Reels Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to create one!',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          GlassButton(
            text: 'Create Reel',
            icon: Icons.add,
            color: Colors.blue,
            onPressed: _createNewReel,
          ),
        ],
      ),
    );
  }

  Widget _buildReelPlayer(StudyReel reel) {
    final controller = _videoControllers[reel.id];
    final isInitialized = _videoInitialized[reel.id] ?? false;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (controller != null && isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
          ),
          
          // Right Side Actions
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Like Button
                _buildActionButton(
                  icon: reel.userLiked == true ? Icons.favorite : Icons.favorite_border,
                  color: reel.userLiked == true ? Colors.red : Colors.white,
                  count: reel.likes,
                  onTap: () => _toggleLike(reel),
                ),
                const SizedBox(height: 20),
                
                // Comment Button
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.white,
                  count: reel.commentsCount,
                  onTap: () => _showComments(reel),
                ),
                const SizedBox(height: 20),
                
                // Share Button
                _buildActionButton(
                  icon: Icons.share,
                  color: Colors.white,
                  count: reel.shares,
                  onTap: () => _shareReel(reel),
                ),
              ],
            ),
          ),
          
          // Bottom Content
          Positioned(
            left: 16,
            right: 80,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue,
                      child: Text(
                        (reel.userName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reel.userName ?? 'Anonymous',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            reel.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Description
                if (reel.description.isNotEmpty)
                  Text(
                    reel.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                // Hashtags
                if (reel.hashtags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: reel.hashtags.map((tag) => Text(
                        '#$tag',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}K' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

class FeedProvider with ChangeNotifier {
  List<dynamic> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 10;
  String? _token;

  List<dynamic> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  void setToken(String? token) {
    _token = token;
  }

  Future<void> fetchPosts({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _page = 1;
      _posts = [];
      _hasMore = true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.getPosts(_token ?? '');

      if (refresh) {
        _posts = data;
      } else {
        _posts.addAll(data);
      }

      _hasMore = data.length >= _pageSize;
      _page++;

      LoggerService.info('Fetched ${data.length} posts');
    } catch (e) {
      LoggerService.error('Failed to fetch posts', e);
      if (_posts.isEmpty) {
        _posts = [];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;
    await fetchPosts();
  }

  Future<void> createPost(String content,
      {String? imageUrl, String? videoUrl}) async {
    try {
      final newPost = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'user_id': 1,
        'user_name': 'You',
        'content': content,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'created_at': DateTime.now().toIso8601String(),
        'likes': 0,
        'comments': 0,
        'profile_image_url': null,
      };

      _posts.insert(0, newPost);
      notifyListeners();

      LoggerService.info('Post created successfully');
    } catch (e) {
      LoggerService.error('Failed to create post', e);
      rethrow;
    }
  }

  void updatePost(int postId, Map<String, dynamic> updates) {
    final index = _posts.indexWhere((post) => post['id'] == postId);
    if (index != -1) {
      _posts[index] = {..._posts[index], ...updates};
      notifyListeners();
    }
  }

  void deletePost(int postId) {
    _posts.removeWhere((post) => post['id'] == postId);
    notifyListeners();
    LoggerService.info('Post deleted');
  }
}

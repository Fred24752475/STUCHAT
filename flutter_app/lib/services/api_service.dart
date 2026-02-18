import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/live_stream.dart';
import 'logger_service.dart';
import 'supabase_service.dart';

class ApiService {
  // Backend URL configuration
  // Android Emulator: Use 10.0.2.2:3000
  // iOS Simulator: Use localhost:3000
  // Physical Device: Use your computer's IP address (e.g., 192.168.1.100:3000)
  // Web/Desktop: Use localhost:3000
  // Production: Use Railway URL

  // Set this to true when deploying to production
  static const bool useProduction = true;
  static const String productionUrl = 'https://stuchat-production.up.railway.app/api';
  static const String productionBaseUrl = 'https://stuchat-production.up.railway.app';

  static String get baseUrl {
    // Automatically detect platform and return appropriate URL
    if (useProduction) {
      return productionUrl;
    }
    try {
      if (kIsWeb) {
        // Web - use localhost
        return 'http://localhost:3000/api';
      } else if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      } else if (Platform.isIOS) {
        return 'http://localhost:3000/api';
      } else {
        // Desktop - use localhost
        return 'http://localhost:3000/api';
      }
    } catch (e) {
      // Fallback for web or platform detection issues
      return 'http://localhost:3000/api';
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      LoggerService.info('Connecting to: $baseUrl/auth/login');
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      LoggerService.info('Auth response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Invalid email or password.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      LoggerService.error('Login error: $e');
      throw Exception(
          'Unable to reach STUCHAT. Check your internet and try again.');
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String course,
    required int year,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'course': course,
          'year': year,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<List<dynamic>> getPosts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load posts');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required String token,
    required String userId,
    required String content,
    String? imageUrl,
    String? videoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'content': content,
          'imageUrl': imageUrl,
          'videoUrl': videoUrl,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Comments
  static Future<List<dynamic>> getComments(String postId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/comments/post/$postId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load comments');
  }

  static Future<Map<String, dynamic>> createComment(
      String postId, String userId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/comments'),
      headers: {'Content-Type': 'application/json'},
      body:
          jsonEncode({'postId': postId, 'userId': userId, 'content': content}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create comment');
  }

  // Likes
  static Future<Map<String, dynamic>> toggleLike(
      String postId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 201) {
        return {'liked': true};
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['alreadyLiked'] == true) {
          // User already liked, unlike it
          await unlikePost(postId, userId);
          return {'liked': false};
        }
        return {'liked': true};
      }
      throw Exception('Failed to toggle like');
    } catch (e) {
      // If there's an error, try to unlike
      await unlikePost(postId, userId);
      return {'liked': false};
    }
  }

  static Future<bool> checkIfLiked(String postId, String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/likes/post/$postId/user/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body)['liked'];
    return false;
  }

  static Future<List<dynamic>> getLikeUsers(String postId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/likes/post/$postId/users'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Followers
  static Future<void> followUser(String followerId, String followingId) async {
    await http.post(
      Uri.parse('$baseUrl/followers/follow'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'followerId': followerId, 'followingId': followingId}),
    );
  }

  static Future<void> unfollowUser(
      String followerId, String followingId) async {
    await http.delete(
      Uri.parse('$baseUrl/followers/unfollow'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'followerId': followerId, 'followingId': followingId}),
    );
  }

  static Future<List<dynamic>> getFollowers(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/followers/$userId/followers'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getFollowing(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/followers/$userId/following'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<bool> checkIfFollowing(
      String followerId, String followingId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/followers/check/$followerId/$followingId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['isFollowing'];
    }
    return false;
  }

  static Future<Map<String, dynamic>> getFollowerCounts(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/followers/$userId/counts'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {'followers': 0, 'following': 0};
  }

  // Stories
  static Future<List<dynamic>> getStories() async {
    final response = await http.get(Uri.parse('$baseUrl/stories'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getUserStories(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/stories/user/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> createStory(String userId,
      {String? imageUrl, String? videoUrl, String? content}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'content': content
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create story');
  }

  static Future<void> viewStory(String storyId, String userId) async {
    await http.post(
      Uri.parse('$baseUrl/stories/$storyId/view'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  static Future<List<dynamic>> getStoryViewers(String storyId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/stories/$storyId/viewers'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Story Comments
  static Future<Map<String, dynamic>> addStoryComment(
      String storyId, String userId, String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'text': text}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to add comment');
  }

  static Future<List<dynamic>> getStoryComments(String storyId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/stories/$storyId/comments'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Story Reactions
  static Future<void> addStoryReaction(
      String storyId, String userId, String reactionType) async {
    await http.post(
      Uri.parse('$baseUrl/stories/$storyId/reactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'reactionType': reactionType}),
    );
  }

  static Future<List<dynamic>> getStoryReactions(String storyId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/stories/$storyId/reactions'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Delete Story
  static Future<void> deleteStory(String storyId) async {
    await http.delete(Uri.parse('$baseUrl/stories/$storyId'));
  }

  // AI Assistant Methods
  static Future<Map<String, dynamic>> chatWithAI({
    required String userId,
    required String message,
    String mode = 'general',
    String? conversationId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'message': message,
              'mode': mode,
              'conversationId': conversationId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'error':
              'AI service rate limit reached. Please try again in a few moments.'
        };
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorBody['error'] ?? 'Failed to chat with AI'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> generateFlashcards(String text,
      {int count = 10}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/flashcards'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'count': count}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to generate flashcards');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> summarizeText(String text,
      {String length = 'medium'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'length': length}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to summarize text');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> solveHomework(String problem,
      {String subject = 'General'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/homework'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'problem': problem, 'subject': subject}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to solve homework');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> generateQuestions(String topic,
      {int count = 5, String difficulty = 'medium'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/questions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': topic,
          'count': count,
          'difficulty': difficulty,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to generate questions');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> explainConcept(String concept,
      {String level = 'college'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/explain'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'concept': concept, 'level': level}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to explain concept');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // AI Conversation History
  static Future<List<dynamic>> getAIConversations(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai/conversations/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getAIConversation(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai/conversation/$conversationId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load conversation');
      }
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteAIConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/ai/conversation/$conversationId'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Direct Messages
  static Future<List<dynamic>> getConversations(String userId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/direct-messages/conversations/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getDirectMessages(
      String userId1, String userId2) async {
    final response =
        await http.get(Uri.parse('$baseUrl/direct-messages/$userId1/$userId2'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> sendDirectMessage(
      String senderId, String receiverId, String content,
      {String? fileUrl,
      String messageType = 'text',
      String? fileName,
      int? audioDuration}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/direct-messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
        'fileUrl': fileUrl,
        'messageType': messageType,
        'fileName': fileName,
        'audioDuration': audioDuration,
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to send message');
  }

  static Future<void> markMessagesAsRead(String userId1, String userId2) async {
    await http
        .put(Uri.parse('$baseUrl/direct-messages/read/$userId1/$userId2'));
  }

  // Notifications
  static Future<List<dynamic>> getNotifications(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/notifications/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> getUnreadCount(String userId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/notifications/$userId/unread-count'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {'count': 0};
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await http.put(Uri.parse('$baseUrl/notifications/$notificationId/read'));
  }

  static Future<void> markAllNotificationsAsRead(String userId) async {
    await http.put(Uri.parse('$baseUrl/notifications/$userId/read-all'));
  }

  // Bookmarks
  static Future<List<dynamic>> getBookmarks(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/bookmarks/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> toggleBookmark(
      String userId, String postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookmarks/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'postId': postId}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to toggle bookmark');
  }

  static Future<bool> checkIfBookmarked(String userId, String postId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/bookmarks/check/$userId/$postId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['bookmarked'];
    }
    return false;
  }

  // Shares
  static Future<Map<String, dynamic>> sharePost(
      String originalPostId, String userId,
      {String? caption}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shares'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'originalPostId': originalPostId,
        'userId': userId,
        'caption': caption
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to share post');
  }

  static Future<List<dynamic>> getPostShares(String postId) async {
    final response = await http.get(Uri.parse('$baseUrl/shares/post/$postId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Event RSVPs
  static Future<void> rsvpEvent(
      String eventId, String userId, String status) async {
    await http.post(
      Uri.parse('$baseUrl/events/$eventId/rsvp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'status': status}),
    );
  }

  static Future<List<dynamic>> getEventRsvps(String eventId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/events/$eventId/rsvps'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<String?> getUserRsvpStatus(
      String eventId, String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/events/$eventId/rsvp/$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'];
    }
    return null;
  }

  // Search
  static Future<List<dynamic>> searchUsers(String query,
      {String? course, String? year}) async {
    var url = '$baseUrl/search/users?q=$query';
    if (course != null) url += '&course=$course';
    if (year != null) url += '&year=$year';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> searchPosts(String query) async {
    final response =
        await http.get(Uri.parse('$baseUrl/search/posts?q=$query'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> discoverUsers(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/search/discover?userId=$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Hashtags
  static Future<List<dynamic>> getTrendingHashtags() async {
    final response = await http.get(Uri.parse('$baseUrl/hashtags/trending'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getHashtagPosts(String hashtag) async {
    final response =
        await http.get(Uri.parse('$baseUrl/hashtags/$hashtag/posts'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getTrendingHashtagsFromStudyReels() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/study-reels/trending-hashtags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hashtags'] ?? [];
      }
      return [];
    } catch (e) {
      LoggerService.error('Failed to get trending hashtags', e);
      return [];
    }
  }

  // Profiles
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/profiles/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load profile');
  }

  static Future<void> updateProfile(String userId,
      {String? name,
      String? bio,
      String? interests,
      String? major,
      String? phone,
      String? website,
      String? location}) async {
    await http.put(
      Uri.parse('$baseUrl/profiles/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'bio': bio,
        'interests': interests,
        'major': major,
        'phone': phone,
        'website': website,
        'location': location,
      }),
    );
  }

  // Update profile image
  static Future<void> updateProfileImage(
      String userId, String? imageUrl) async {
    await http.put(
      Uri.parse('$baseUrl/profiles/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'profileImageUrl': imageUrl,
      }),
    );
  }

  static Future<List<dynamic>> getUserPosts(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/profiles/$userId/posts'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Reactions
  static Future<Map<String, dynamic>> toggleReaction(
      String postId, String userId, String reactionType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reactions/post/$postId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'reactionType': reactionType}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to react');
  }

  static Future<List<dynamic>> getReactions(String postId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/reactions/post/$postId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Marketplace
  static Future<List<dynamic>> getMarketplaceItems(
      {String? category, String? search}) async {
    var url = '$baseUrl/marketplace?status=available';
    if (category != null) url += '&category=$category';
    if (search != null) url += '&search=$search';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Achievements
  static Future<List<dynamic>> getUserAchievements(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/achievements/user/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> getLeaderboard() async {
    final response =
        await http.get(Uri.parse('$baseUrl/achievements/leaderboard'));
    if (response.statusCode == 200) return {'users': jsonDecode(response.body)};
    return {'users': []};
  }

  // Preferences
  static Future<Map<String, dynamic>> getPreferences(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/preferences/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  static Future<void> updatePreferences(String userId,
      {String? theme, bool? notificationsEnabled}) async {
    await http.put(
      Uri.parse('$baseUrl/preferences/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'theme': theme,
        'notificationsEnabled': notificationsEnabled,
      }),
    );
  }

  // Study Groups
  static Future<List<dynamic>> getStudyGroups(
      {String? course, String? search}) async {
    var url = '$baseUrl/study-groups';
    final params = <String>[];
    if (course != null) params.add('course=$course');
    if (search != null) params.add('search=$search');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> joinStudyGroup(String groupId, String userId) async {
    await http.post(
      Uri.parse('$baseUrl/study-groups/$groupId/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  // Media Upload
  static Future<String> uploadMedia(dynamic file, String userId) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/media/upload'));
      request.fields['userId'] = userId;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        final baseFileUrl = useProduction ? productionBaseUrl : 'http://localhost:3000';
        return '$baseFileUrl${jsonResponse['file']['url']}';
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // Marketplace - Create Item
  static Future<Map<String, dynamic>> createMarketplaceItem({
    required String userId,
    required String title,
    required String description,
    required double price,
    required String category,
    required String condition,
    required String location,
    String? imageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/marketplace'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'condition': condition,
        'location': location,
        'imageUrl': imageUrl,
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create item');
  }

  // Marketplace - Get Item Details
  static Future<Map<String, dynamic>> getMarketplaceItem(String itemId) async {
    final response = await http.get(Uri.parse('$baseUrl/marketplace/$itemId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load item');
  }

  // Marketplace - Update Item Status
  static Future<void> updateMarketplaceItemStatus(
      String itemId, String status) async {
    await http.put(
      Uri.parse('$baseUrl/marketplace/$itemId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
  }

  // Marketplace - Delete Item
  static Future<void> deleteMarketplaceItem(String itemId) async {
    await http.delete(Uri.parse('$baseUrl/marketplace/$itemId'));
  }

  // Marketplace - Get User Items
  static Future<List<dynamic>> getUserMarketplaceItems(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/marketplace/user/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Media Upload for Web (using XFile)
  static Future<String> uploadMediaWeb(XFile xFile, String userId) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/media/upload'));
      request.fields['userId'] = userId;

      // Read bytes from XFile for web compatibility
      final bytes = await xFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: xFile.name,
      ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        final baseFileUrl = useProduction ? productionBaseUrl : 'http://localhost:3000';
        return '$baseFileUrl${jsonResponse['file']['url']}';
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // Upload media from file path (for audio recordings, etc.)
  static Future<String> uploadMediaFromPath(
      String filePath, String userId) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/media/upload'));
      request.fields['userId'] = userId;

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      request.files.add(
        http.MultipartFile(
          'file',
          file.openRead(),
          await file.length(),
          filename: file.path.split('/').last,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        final baseFileUrl = useProduction ? productionBaseUrl : 'http://localhost:3000';
        return '$baseFileUrl${jsonResponse['file']['url']}';
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // Video/Voice Calls
  static Future<Map<String, dynamic>> initiateCall(
      String callerId, String receiverId, String callType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/calls/initiate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'callerId': callerId,
        'receiverId': receiverId,
        'callType': callType,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to initiate call');
  }

  static Future<Map<String, dynamic>> answerCall(String callId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/calls/$callId/answer'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to answer call');
  }

  static Future<Map<String, dynamic>> rejectCall(String callId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/calls/$callId/reject'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to reject call');
  }

  static Future<Map<String, dynamic>> endCall(
      String callId, int duration) async {
    final response = await http.put(
      Uri.parse('$baseUrl/calls/$callId/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'duration': duration}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to end call');
  }

  // Live Streaming
  static Future<Map<String, dynamic>> createLiveStream(
      String token, String title, String description, String category) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to create live stream');
  }

  static Future<List<dynamic>> getActiveLiveStreams() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/live-streams/active'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LiveStream.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching live streams: $e');
      return [];
    }
  }

  static Future<dynamic> getLiveStream(int streamId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/live-streams/$streamId'));
    if (response.statusCode == 200) {
      return LiveStream.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load stream');
  }

  static Future<void> endLiveStream(String token, int streamId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/$streamId/end'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to end stream');
    }
  }

  static Future<void> joinLiveStream(String token, int streamId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/$streamId/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to join stream');
    }
  }

  static Future<void> leaveLiveStream(String token, int streamId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/$streamId/leave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to leave stream');
    }
  }

  static Future<List<dynamic>> getLiveStreamComments(int streamId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/live-streams/$streamId/comments'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StreamComment.fromJson(json)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> sendLiveStreamComment(
      String token, int streamId, String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/$streamId/comments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to send comment');
  }

  static Future<Map<String, dynamic>> sendLiveStreamGift(
      String token, int streamId, String giftType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/$streamId/gifts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'giftType': giftType, 'amount': 1}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to send gift');
  }

  static Future<List<dynamic>> getLiveStreamViewers(int streamId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/live-streams/$streamId/viewers'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getUserLiveStreamHistory(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/live-streams/user/$userId/history'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Email Verification
  static Future<Map<String, dynamic>> sendVerificationCode(
      String email, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verification/send-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'name': name}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to send verification code');
  }

  static Future<Map<String, dynamic>> verifyCode(
      String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verification/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Verification failed');
  }

  static Future<Map<String, dynamic>> resendVerificationCode(
      String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verification/resend-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to resend code');
  }

  // Referral System
  static Future<Map<String, dynamic>> applyReferralCode(
      String userId, String referralCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/referrals/apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'referralCode': referralCode}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to apply referral code');
  }

  static Future<Map<String, dynamic>> getReferralStats(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/referrals/stats/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get referral stats');
  }

  static Future<List<dynamic>> getReferralLeaderboard() async {
    final response =
        await http.get(Uri.parse('$baseUrl/referrals/leaderboard'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Analytics
  static Future<void> trackAction(
      String userId, String actionType, Map<String, dynamic>? metadata) async {
    await http.post(
      Uri.parse('$baseUrl/analytics/track'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'actionType': actionType,
        'metadata': metadata ?? {}
      }),
    );
  }

  static Future<Map<String, dynamic>> getAnalyticsDashboard(String userId,
      {int period = 7}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/dashboard/$userId?period=$period'),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get analytics');
  }

  static Future<Map<String, dynamic>> getAnalyticsTrends(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/analytics/trends/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get trends');
  }

  // Push Notifications
  static Future<void> registerPushToken(
      String userId, String token, String deviceType) async {
    await http.post(
      Uri.parse('$baseUrl/push-notifications/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'userId': userId, 'token': token, 'deviceType': deviceType}),
    );
  }

  static Future<void> removePushToken(String userId, String token) async {
    await http.delete(
      Uri.parse('$baseUrl/push-notifications/remove-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'token': token}),
    );
  }

  // Study Resources
  static Future<List<dynamic>> getStudyResources(
      {String? course, String? search}) async {
    var url = '$baseUrl/study-resources';
    final params = <String>[];
    if (course != null) params.add('course=$course');
    if (search != null) params.add('search=$search');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> createStudyResource({
    required String userId,
    required String title,
    required String description,
    required String fileUrl,
    required String course,
    required String resourceType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/study-resources'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'course': course,
        'resourceType': resourceType,
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create resource');
  }

  static Future<void> deleteStudyResource(String resourceId) async {
    await http.delete(Uri.parse('$baseUrl/study-resources/$resourceId'));
  }

  // ===== NEW FEATURES =====

  // Emoji Reactions
  static Future<void> addEmojiReaction(
      String postId, String userId, String emoji) async {
    await http.post(
      Uri.parse('$baseUrl/emoji-reactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'postId': postId, 'userId': userId, 'emoji': emoji}),
    );
  }

  static Future<List<dynamic>> getEmojiReactions(String postId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/emoji-reactions/post/$postId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Search History
  static Future<void> addToSearchHistory(String userId, String query,
      {String searchType = 'general'}) async {
    await http.post(
      Uri.parse('$baseUrl/search/history'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'userId': userId, 'query': query, 'searchType': searchType}),
    );
  }

  static Future<List<dynamic>> getSearchHistory(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/search/history/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> clearSearchHistory(String userId) async {
    await http.delete(Uri.parse('$baseUrl/search/history/$userId'));
  }

  // Saved Searches
  static Future<void> saveSearch(String userId, String query,
      {String? name}) async {
    await http.post(
      Uri.parse('$baseUrl/search/saved'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'query': query, 'name': name}),
    );
  }

  static Future<List<dynamic>> getSavedSearches(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/search/saved/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> deleteSavedSearch(String searchId) async {
    await http.delete(Uri.parse('$baseUrl/search/saved/$searchId'));
  }

  // User Mentions
  static Future<void> mentionUser(
      String mentionedUserId, String mentioningUserId, String postId) async {
    await http.post(
      Uri.parse('$baseUrl/mentions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mentionedUserId': mentionedUserId,
        'mentioningUserId': mentioningUserId,
        'postId': postId,
      }),
    );
  }

  static Future<List<dynamic>> getUserMentions(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/mentions/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Hashtag Following
  static Future<void> followHashtag(String userId, String hashtagId) async {
    await http.post(
      Uri.parse('$baseUrl/hashtag-followers/follow'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'hashtagId': hashtagId}),
    );
  }

  static Future<void> unfollowHashtag(String userId, String hashtagId) async {
    await http.post(
      Uri.parse('$baseUrl/hashtag-followers/unfollow'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'hashtagId': hashtagId}),
    );
  }

  static Future<List<dynamic>> getFollowedHashtags(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/hashtag-followers/user/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Content Filters
  static Future<void> addContentFilter(String userId, String filterType,
      {String? filterValue}) async {
    await http.post(
      Uri.parse('$baseUrl/content-filters'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'filterType': filterType,
        'filterValue': filterValue
      }),
    );
  }

  static Future<List<dynamic>> getContentFilters(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/content-filters/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getFilteredFeed(String userId,
      {String? filterType,
      String? filterValue,
      String sortBy = 'recent'}) async {
    var url = '$baseUrl/content-filters/feed/$userId?sortBy=$sortBy';
    if (filterType != null) url += '&filterType=$filterType';
    if (filterValue != null) url += '&filterValue=$filterValue';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Birthdays
  static Future<void> setBirthday(String userId, String birthDate,
      {bool showOnProfile = true}) async {
    await http.post(
      Uri.parse('$baseUrl/birthdays'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'birthDate': birthDate,
        'showOnProfile': showOnProfile
      }),
    );
  }

  static Future<Map<String, dynamic>> getBirthday(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/birthdays/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  static Future<List<dynamic>> getTodayBirthdays() async {
    final response = await http.get(Uri.parse('$baseUrl/birthdays/today/list'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> sendBirthdayMessage(String userId, String celebratorId,
      {String? message}) async {
    await http.post(
      Uri.parse('$baseUrl/birthdays/celebrate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'userId': userId, 'celebratorId': celebratorId, 'message': message}),
    );
  }

  // User Statistics
  static Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/statistics/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  static Future<void> updateUserStatistics(String userId) async {
    await http.put(
      Uri.parse('$baseUrl/statistics/$userId'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<List<dynamic>> getEngagementLeaderboard() async {
    final response =
        await http.get(Uri.parse('$baseUrl/statistics/leaderboard/engagement'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Anonymous Secrets
  static Future<Map<String, dynamic>> createAnonymousSecret(
      String userId, String content,
      {String? imageUrl}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/anonymous-secrets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'userId': userId, 'content': content, 'imageUrl': imageUrl}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create secret');
  }

  static Future<List<dynamic>> getAnonymousSecrets(
      {int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse(
        '$baseUrl/anonymous-secrets/feed?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getTrendingSecrets({int limit = 20}) async {
    final response = await http
        .get(Uri.parse('$baseUrl/anonymous-secrets/trending?limit=$limit'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> likeAnonymousSecret(
      String secretId, String userId) async {
    await http.post(
      Uri.parse('$baseUrl/anonymous-secrets/$secretId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  static Future<void> unlikeAnonymousSecret(
      String secretId, String userId) async {
    await http.delete(
      Uri.parse('$baseUrl/anonymous-secrets/$secretId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  // Post like/unlike functionality
  static Future<Map<String, dynamic>> likePost(
      String postId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode == 201) {
      return {'success': true};
    } else if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to like post');
  }

  static Future<void> unlikePost(String postId, String userId) async {
    await http.delete(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  static Future<void> commentOnPost(
      String postId, String userId, String content) async {
    await http.post(
      Uri.parse('$baseUrl/posts/$postId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'content': content}),
    );
  }

  static Future<List<dynamic>> getPostComments(String postId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/posts/$postId/comments'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<void> deletePostComment(
      String postId, String commentId, String userId) async {
    await http.delete(
      Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  static Future<void> deleteSecretComment(
      String secretId, String commentId, String userId) async {
    await http.delete(
      Uri.parse('$baseUrl/anonymous-secrets/$secretId/comments/$commentId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  // Study Reels API methods
  static Future<Map<String, dynamic>> getStudyReelsFeed({
    int limit = 20,
    int offset = 0,
    String? userId,
    String? hashtags,
    bool trending = false,
  }) async {
    try {
      var url = '$baseUrl/study-reels/feed?limit=$limit&offset=$offset';
      if (userId != null) url += '&userId=$userId';
      if (hashtags != null) url += '&hashtags=$hashtags';
      if (trending) url += '&trending=true';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'reels': []};
    } catch (e) {
      LoggerService.error('Failed to get study reels feed', e);
      return {'success': false, 'reels': []};
    }
  }

  static Future<Map<String, dynamic>> getStudyReel(String reelId,
      {String? userId}) async {
    try {
      var url = '$baseUrl/study-reels/$reelId';
      if (userId != null) url += '?userId=$userId';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load reel');
    } catch (e) {
      LoggerService.error('Failed to get study reel', e);
      throw Exception('Failed to load reel');
    }
  }

  static Future<List<dynamic>> getUserStudyReels(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/study-reels/user/$userId?limit=$limit&offset=$offset'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reels'] ?? [];
      }
      return [];
    } catch (e) {
      LoggerService.error('Failed to get user study reels', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createStudyReelWithVideo({
    required String userId,
    required File videoFile,
    required String title,
    String? description,
    String? hashtags,
    bool isPublic = true,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/study-reels/create'),
      );

      request.fields['userId'] = userId;
      request.fields['title'] = title;
      request.fields['description'] = description ?? '';
      request.fields['hashtags'] = hashtags ?? '';
      request.fields['isPublic'] = isPublic.toString();

      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 201) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['error'] ?? 'Failed to create study reel');
      }
    } catch (e) {
      LoggerService.error('Failed to create study reel', e);
      throw Exception('Upload error: $e');
    }
  }

  static Future<Map<String, dynamic>> toggleStudyReelLike(
      String reelId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/study-reels/$reelId/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to toggle like');
    } catch (e) {
      LoggerService.error('Failed to toggle study reel like', e);
      throw Exception('Failed to toggle like');
    }
  }

  static Future<Map<String, dynamic>> addStudyReelComment(
      String reelId, String userId, String comment) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/study-reels/$reelId/comments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'comment': comment}),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to add comment');
    } catch (e) {
      LoggerService.error('Failed to add study reel comment', e);
      throw Exception('Failed to add comment');
    }
  }

  static Future<Map<String, dynamic>> shareStudyReel(
      String reelId, String userId,
      {String? platform}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/study-reels/$reelId/share'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'platform': platform}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to share reel');
    } catch (e) {
      LoggerService.error('Failed to share study reel', e);
      throw Exception('Failed to share reel');
    }
  }

  static Future<void> incrementStudyReelView(String reelId) async {
    try {
      await http.post(Uri.parse('$baseUrl/study-reels/$reelId/view'));
    } catch (e) {
      LoggerService.error('Failed to increment view', e);
    }
  }

  static Future<bool> deleteStudyReel(String reelId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/study-reels/$reelId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      LoggerService.error('Failed to delete study reel', e);
      return false;
    }
  }

  // Get all study reels
  static Future<List<dynamic>> getStudyReels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/study-reels'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        return data['reels'] ?? data['data'] ?? [];
      }
      return [];
    } catch (e) {
      LoggerService.error('Failed to get study reels', e);
      return [];
    }
  }

  // Unlike a study reel
  static Future<bool> unlikeStudyReel(String reelId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/study-reels/$reelId/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      LoggerService.error('Failed to unlike study reel', e);
      return false;
    }
  }

  static Future<void> commentOnSecret(
      String secretId, String userId, String content) async {
    await http.post(
      Uri.parse('$baseUrl/anonymous-secrets/$secretId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'content': content}),
    );
  }

  static Future<List<dynamic>> getSecretComments(String secretId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/anonymous-secrets/$secretId/comments'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // Enhanced Live Streams
  static Future<Map<String, dynamic>> createLiveStreamEnhanced(
      String broadcasterId, String title,
      {String? description, String? category}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/live-streams/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer $broadcasterId', // Using broadcasterId as token for now
      },
      body: jsonEncode(
          {'title': title, 'description': description, 'category': category}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to create live stream');
  }

  static Future<List<dynamic>> getActiveLiveStreamsEnhanced() async {
    final response =
        await http.get(Uri.parse('$baseUrl/live-streams-enhanced/active'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> joinLiveStreamEnhanced(
      String streamId, String userId) async {
    await http.post(
      Uri.parse('$baseUrl/live-streams-enhanced/$streamId/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  static Future<void> leaveLiveStreamEnhanced(String streamId, String userId,
      {int watchDuration = 0}) async {
    await http.post(
      Uri.parse('$baseUrl/live-streams-enhanced/$streamId/leave'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'watchDuration': watchDuration}),
    );
  }

  static Future<void> sendLiveStreamCommentEnhanced(
      String streamId, String userId, String content) async {
    await http.post(
      Uri.parse('$baseUrl/live-streams-enhanced/$streamId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'content': content}),
    );
  }

  static Future<List<dynamic>> getLiveStreamCommentsEnhanced(
      String streamId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/live-streams-enhanced/$streamId/comments'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> sendLiveStreamGiftEnhanced(
      String streamId, String senderId, String giftType) async {
    await http.post(
      Uri.parse('$baseUrl/live-streams-enhanced/$streamId/gifts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'senderId': senderId, 'giftType': giftType}),
    );
  }

  static Future<void> endLiveStreamEnhanced(String streamId,
      {bool isRecorded = false, String? recordingUrl}) async {
    await http.post(
      Uri.parse('$baseUrl/live-streams-enhanced/$streamId/end'),
      headers: {'Content-Type': 'application/json'},
      body:
          jsonEncode({'isRecorded': isRecorded, 'recordingUrl': recordingUrl}),
    );
  }

  // Call Logs
  static Future<Map<String, dynamic>> initiateCallLog(
      String callerId, String receiverId, String callType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/call-logs/initiate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'callerId': callerId,
        'receiverId': receiverId,
        'callType': callType
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to initiate call');
  }

  static Future<void> answerCallLog(String callId) async {
    await http.put(
      Uri.parse('$baseUrl/call-logs/$callId/answer'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<void> endCallLog(String callId, {int duration = 0}) async {
    await http.put(
      Uri.parse('$baseUrl/call-logs/$callId/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'duration': duration}),
    );
  }

  static Future<List<dynamic>> getCallHistory(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/call-logs/history/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getMissedCalls(String userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/call-logs/missed/$userId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // QR Codes
  static Future<Map<String, dynamic>> generateProfileQRCode(
      String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/qr-codes/profile/$userId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to generate QR code');
  }

  static Future<Map<String, dynamic>> generateGroupQRCode(
      String groupId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/qr-codes/group/$groupId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to generate QR code');
  }

  static Future<Map<String, dynamic>> scanQRCode(String qrId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/qr-codes/scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'qrId': qrId}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to scan QR code');
  }

  // AI Study Buddy Pro Methods
  static Future<Map<String, dynamic>> solveHomeworkProblem({
    required String userId,
    required String problemText,
    String mode = 'scan',
    String? conversationId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/homework-problem'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'problemText': problemText,
              'mode': mode,
              'conversationId': conversationId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorBody['error'] ?? 'Failed to solve homework problem'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> generateStudySchedule(
      String userId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/study-schedule'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorBody['error'] ?? 'Failed to generate study schedule'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  // Study Progress Tracking Methods
  static Future<Map<String, dynamic>> trackStudySession({
    required String userId,
    required int duration,
    String? subject,
    List<String>? topics,
    double? score,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/study-progress/track-session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'duration': duration,
              'subject': subject,
              'topics': topics ?? [],
              'score': score,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorBody['error'] ?? 'Failed to track study session'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> getStudyStatistics(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/study-progress/statistics/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to load statistics'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> getStudyLeaderboard(
      {String type = 'weekly', int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/study-progress/leaderboard?type=$type&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to load leaderboard'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> checkAchievements(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/study-progress/check-achievements/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to check achievements'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> getStudyGoals(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/study-progress/goals/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to load study goals'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> setStudyGoal({
    required String userId,
    required String type,
    required int target,
    required String timeframe,
    String? subject,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/study-progress/goals'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'type': type,
              'target': target,
              'timeframe': timeframe,
              'subject': subject,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorBody['error'] ?? 'Failed to set study goal'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet and try again.'
      };
    }
  }

  // Friend system methods
  static Future<List<dynamic>> getFriends(String userId) async {
    try {
      // Query followers table directly from Supabase
      final response = await SupabaseService.client
          .from('followers')
          .select('users!inner(id, name, email, profile_image_url, course, year)')
          .eq('follower_id', userId);
      
      // Transform the response to get user data
      List<Map<String, dynamic>> friends = [];
      for (var item in response) {
        if (item['users'] != null) {
          friends.add(item['users']);
        }
      }
      return friends;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<List<dynamic>> getAvailableUsers(String currentUserId) async {
    try {
      print('Fetching users, current user: $currentUserId');
      
      // Query users table directly from Supabase (UUID)
      final response = await SupabaseService.client
          .from('users')
          .select('id, name, email, profile_image_url, course, year')
          .neq('id', currentUserId)
          .limit(50);
      
      print('Supabase response for users: ${response.length} users found');
      if (response.isNotEmpty) {
        print('First user: ${response.first}');
      }
      return response;
    } catch (e) {
      print('Error fetching users from Supabase: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getFriendRequests(String userId) async {
    try {
      // Query friend_requests table from Supabase - where user is receiver
      final response = await SupabaseService.client
          .from('friend_requests')
          .select('users!sender_id(id, name, email, profile_image_url, course, year)')
          .eq('receiver_id', userId)
          .eq('status', 'pending');
      
      // Transform the response
      List<Map<String, dynamic>> requests = [];
      for (var item in response) {
        if (item['users'] != null) {
          requests.add({
            'id': item['id'],
            'sender_id': item['users']['id'],
            'name': item['users']['name'],
            'email': item['users']['email'],
            'profile_image_url': item['users']['profile_image_url'],
            'course': item['users']['course'],
            'year': item['users']['year'],
          });
        }
      }
      return requests;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<List<dynamic>> getSentFriendRequests(String userId) async {
    try {
      // Query friend_requests table from Supabase - where user is sender
      final response = await SupabaseService.client
          .from('friend_requests')
          .select('users!receiver_id(id, name, email, profile_image_url, course, year)')
          .eq('sender_id', userId)
          .eq('status', 'pending');
      
      // Transform the response
      List<Map<String, dynamic>> requests = [];
      for (var item in response) {
        if (item['users'] != null) {
          requests.add({
            'id': item['id'],
            'receiver_id': item['users']['id'],
            'name': item['users']['name'],
            'email': item['users']['email'],
            'profile_image_url': item['users']['profile_image_url'],
            'course': item['users']['course'],
            'year': item['users']['year'],
          });
        }
      }
      return requests;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<bool> sendFriendRequest(
      String senderId, String receiverId) async {
    try {
      // Check if already friends
      final existingFriends = await SupabaseService.client
          .from('followers')
          .select()
          .eq('follower_id', senderId)
          .eq('following_id', receiverId);
      
      if (existingFriends.isNotEmpty) {
        return false; // Already friends
      }
      
      // Check if request already exists
      final existingRequest = await SupabaseService.client
          .from('friend_requests')
          .select()
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId);
      
      if (existingRequest.isNotEmpty) {
        return false; // Request already exists
      }
      
      // Insert new friend request
      await SupabaseService.client.from('friend_requests').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> acceptFriendRequest(
      String requestId, String userId, String requesterId) async {
    try {
      // Update request status to accepted
      await SupabaseService.client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);
      
      // Add to followers (both ways)
      await SupabaseService.client.from('followers').insert({
        'follower_id': userId,
        'following_id': requesterId,
      });
      
      await SupabaseService.client.from('followers').insert({
        'follower_id': requesterId,
        'following_id': userId,
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rejectFriendRequest(
      String requestId, String userId) async {
    try {
      await SupabaseService.client
          .from('friend_requests')
          .delete()
          .eq('id', requestId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateUserLocation(
    String userId, {
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/location/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? '',
        }),
      );

      if (response.statusCode == 200) {
        LoggerService.info('Location updated successfully');
      } else {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      LoggerService.error('Error updating location: $e');
      throw Exception('Connection error: $e');
    }
  }

  static Future<List<dynamic>> getFriendsLocations(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/locations/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      LoggerService.error('Error loading friends locations: $e');
      return [];
    }
  }
}

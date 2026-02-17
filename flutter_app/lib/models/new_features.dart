class AnonymousSecret {
  final int id;
  final String content;
  final String? imageUrl;
  final int likes;
  final int comments;
  final DateTime createdAt;
  final DateTime? expiresAt;

  AnonymousSecret({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.likes,
    required this.comments,
    required this.createdAt,
    this.expiresAt,
  });

  factory AnonymousSecret.fromJson(Map<String, dynamic> json) {
    return AnonymousSecret(
      id: json['id'],
      content: json['content'],
      imageUrl: json['image_url'],
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
    );
  }
}

class UserStatistics {
  final int userId;
  final int totalPosts;
  final int totalFollowers;
  final int totalFollowing;
  final int totalLikesReceived;
  final int totalCommentsReceived;
  final double engagementScore;

  UserStatistics({
    required this.userId,
    required this.totalPosts,
    required this.totalFollowers,
    required this.totalFollowing,
    required this.totalLikesReceived,
    required this.totalCommentsReceived,
    required this.engagementScore,
  });

  factory UserStatistics.fromJson(Map<String, dynamic> json) {
    return UserStatistics(
      userId: json['userId'] ?? json['user_id'],
      totalPosts: json['totalPosts'] ?? json['total_posts'] ?? 0,
      totalFollowers: json['totalFollowers'] ?? json['total_followers'] ?? 0,
      totalFollowing: json['totalFollowing'] ?? json['total_following'] ?? 0,
      totalLikesReceived: json['totalLikesReceived'] ?? json['total_likes_received'] ?? 0,
      totalCommentsReceived: json['totalCommentsReceived'] ?? json['total_comments_received'] ?? 0,
      engagementScore: (json['engagementScore'] ?? json['engagement_score'] ?? 0).toDouble(),
    );
  }
}

class LiveStreamEnhanced {
  final int id;
  final int broadcasterId;
  final String broadcasterName;
  final String? broadcasterImage;
  final String title;
  final String? description;
  final String? category;
  final String? thumbnailUrl;
  final String? streamUrl;
  final String status;
  final int viewerCount;
  final int likes;
  final DateTime startTime;
  final DateTime? endTime;
  final int duration;
  final bool isRecorded;
  final String? recordingUrl;

  LiveStreamEnhanced({
    required this.id,
    required this.broadcasterId,
    required this.broadcasterName,
    this.broadcasterImage,
    required this.title,
    this.description,
    this.category,
    this.thumbnailUrl,
    this.streamUrl,
    required this.status,
    required this.viewerCount,
    required this.likes,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.isRecorded,
    this.recordingUrl,
  });

  factory LiveStreamEnhanced.fromJson(Map<String, dynamic> json) {
    return LiveStreamEnhanced(
      id: json['id'],
      broadcasterId: json['broadcaster_id'],
      broadcasterName: json['name'] ?? 'Unknown',
      broadcasterImage: json['profile_image_url'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      thumbnailUrl: json['thumbnail_url'],
      streamUrl: json['stream_url'],
      status: json['status'] ?? 'active',
      viewerCount: json['viewer_count'] ?? 0,
      likes: json['likes'] ?? 0,
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      duration: json['duration'] ?? 0,
      isRecorded: (json['is_recorded'] ?? 0) == 1,
      recordingUrl: json['recording_url'],
    );
  }
}

class CallLog {
  final int id;
  final int callerId;
  final int receiverId;
  final String callType;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int duration;
  final bool isMissed;

  CallLog({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.duration,
    required this.isMissed,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'],
      callerId: json['caller_id'],
      receiverId: json['receiver_id'],
      callType: json['call_type'],
      status: json['status'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      duration: json['duration'] ?? 0,
      isMissed: (json['is_missed'] ?? 0) == 1,
    );
  }
}

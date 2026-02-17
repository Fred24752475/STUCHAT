class StudyReel {
  final int id;
  final String userId;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<String> hashtags;
  final int views;
  final int likes;
  final int shares;
  final int commentsCount;
  final Map<String, dynamic>? aiAnalysis;
  final bool isPublic;
  final int? duration;
  final DateTime createdAt;
  final DateTime updatedAt;

  // User info
  final String? userName;
  final String? profileImageUrl;
  final bool? userLiked;
  final bool? userFollowing;

  StudyReel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.hashtags,
    required this.views,
    required this.likes,
    required this.shares,
    required this.commentsCount,
    this.aiAnalysis,
    required this.isPublic,
    this.duration,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.profileImageUrl,
    this.userLiked,
    this.userFollowing,
  });

  factory StudyReel.fromJson(Map<String, dynamic> json) {
    return StudyReel(
      id: json['id'] ?? 0,
      userId: json['user_id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      hashtags: json['hashtags'] != null
          ? (json['hashtags'] is List
              ? List<String>.from(json['hashtags'])
              : [])
          : [],
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      shares: json['shares'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      aiAnalysis: json['ai_analysis'],
      isPublic: json['is_public'] ?? true,
      duration: json['duration'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      userName: json['name'],
      profileImageUrl: json['profile_image_url'],
      userLiked: json['user_liked'],
      userFollowing: json['user_following'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'hashtags': hashtags,
      'views': views,
      'likes': likes,
      'shares': shares,
      'comments_count': commentsCount,
      'ai_analysis': aiAnalysis,
      'is_public': isPublic,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'name': userName,
      'profile_image_url': profileImageUrl,
      'user_liked': userLiked,
      'user_following': userFollowing,
    };
  }

  StudyReel copyWith({
    int? id,
    String? userId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    List<String>? hashtags,
    int? views,
    int? likes,
    int? shares,
    int? commentsCount,
    Map<String, dynamic>? aiAnalysis,
    bool? isPublic,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? profileImageUrl,
    bool? userLiked,
    bool? userFollowing,
  }) {
    return StudyReel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      hashtags: hashtags ?? this.hashtags,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      commentsCount: commentsCount ?? this.commentsCount,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      isPublic: isPublic ?? this.isPublic,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      userLiked: userLiked ?? this.userLiked,
      userFollowing: userFollowing ?? this.userFollowing,
    );
  }
}

class ReelComment {
  final int id;
  final int reelId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final String? userName;
  final String? profileImageUrl;

  ReelComment({
    required this.id,
    required this.reelId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.userName,
    this.profileImageUrl,
  });

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    return ReelComment(
      id: json['id'] ?? 0,
      reelId: json['reel_id'] ?? 0,
      userId: json['user_id']?.toString() ?? '',
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      userName: json['name'],
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reel_id': reelId,
      'user_id': userId,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'name': userName,
      'profile_image_url': profileImageUrl,
    };
  }
}

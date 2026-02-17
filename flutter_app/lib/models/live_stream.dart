class LiveStream {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final String? category;
  final String streamKey;
  final String status;
  final int viewerCount;
  final String username;
  final String fullName;
  final String? profilePicture;
  final String createdAt;
  final String? endedAt;

  LiveStream({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.category,
    required this.streamKey,
    required this.status,
    required this.viewerCount,
    required this.username,
    required this.fullName,
    this.profilePicture,
    required this.createdAt,
    this.endedAt,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      streamKey: json['stream_key'],
      status: json['status'],
      viewerCount: json['viewer_count'] ?? 0,
      username: json['username'],
      fullName: json['full_name'],
      profilePicture: json['profile_picture'],
      createdAt: json['created_at'],
      endedAt: json['ended_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'stream_key': streamKey,
      'status': status,
      'viewer_count': viewerCount,
      'username': username,
      'full_name': fullName,
      'profile_picture': profilePicture,
      'created_at': createdAt,
      'ended_at': endedAt,
    };
  }
}

class StreamComment {
  final int id;
  final int userId;
  final String username;
  final String fullName;
  final String? profilePicture;
  final String text;
  final String createdAt;

  StreamComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    this.profilePicture,
    required this.text,
    required this.createdAt,
  });

  factory StreamComment.fromJson(Map<String, dynamic> json) {
    return StreamComment(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'],
      username: json['username'],
      fullName: json['fullName'] ?? json['full_name'],
      profilePicture: json['profilePicture'] ?? json['profile_picture'],
      text: json['text'],
      createdAt: json['createdAt'] ?? json['created_at'],
    );
  }
}

class StreamGift {
  final String giftType;
  final int amount;
  final int userId;
  final String username;
  final String? profilePicture;

  StreamGift({
    required this.giftType,
    required this.amount,
    required this.userId,
    required this.username,
    this.profilePicture,
  });

  factory StreamGift.fromJson(Map<String, dynamic> json) {
    return StreamGift(
      giftType: json['giftType'] ?? json['gift_type'],
      amount: json['amount'] ?? 1,
      userId: json['userId'] ?? json['user_id'],
      username: json['username'],
      profilePicture: json['profilePicture'] ?? json['profile_picture'],
    );
  }
}

class Post {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime createdAt;
  final int likes;
  final int comments;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    this.imageUrl,
    this.videoUrl,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      content: json['content'],
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      createdAt: DateTime.parse(json['created_at']),
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
    );
  }
}

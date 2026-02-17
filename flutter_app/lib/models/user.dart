class User {
  final String id;
  final String name;
  final String email;
  final String course;
  final int year;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.course,
    required this.year,
    this.profileImageUrl,
  });

  // Add username getter that returns name as fallback
  String get username => name;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'].toString(),
      email: json['email'].toString(),
      course: json['course'].toString(),
      year: json['year'] is int
          ? json['year']
          : int.parse(json['year'].toString()),
      profileImageUrl: json['profile_image_url']?.toString(),
    );
  }
}

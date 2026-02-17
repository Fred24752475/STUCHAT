import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileTemplate extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String subtitle;
  final String? bio;
  final int postsCount;
  final int friendsCount;
  final int followingCount;
  final VoidCallback? onEditProfile;
  final VoidCallback? onImageTap;
  final VoidCallback? onFriendsTap;
  final VoidCallback? onFollowingTap;
  final List<ProfileAction> actions;

  const ProfileTemplate({
    super.key,
    this.imageUrl,
    required this.name,
    required this.subtitle,
    this.bio,
    required this.postsCount,
    required this.friendsCount,
    required this.followingCount,
    this.onEditProfile,
    this.onImageTap,
    this.onFriendsTap,
    this.onFollowingTap,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 100),
        // Profile Picture
        GestureDetector(
          onTap: onImageTap,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
                  child: imageUrl == null ? const Icon(Icons.person, size: 60) : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 4),
        // Subtitle
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
        ),
        if (bio != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat(postsCount.toString(), 'Posts', null),
                    Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
                    _buildStat(friendsCount.toString(), 'Friends', onFriendsTap),
                    Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
                    _buildStat(followingCount.toString(), 'Following', onFollowingTap),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onEditProfile != null) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.6),
                        Theme.of(context).primaryColor.withOpacity(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEditProfile,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: actions.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActionCard(context, action),
              )).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStat(String value, String label, VoidCallback? onTap) {
    final widget = Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8.0), child: widget),
      );
    }
    return widget;
  }

  Widget _buildActionCard(BuildContext context, ProfileAction action) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(15),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon, color: Theme.of(context).primaryColor),
                ),
                title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAction {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ProfileAction({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

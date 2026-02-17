import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/theme_provider.dart';
import '../utils/translations.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/profile_template.dart';
import 'login_screen.dart';
import 'events_screen.dart';
import 'followers_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userProfile;
  List<dynamic> userPosts = [];
  List<dynamic> friends = [];
  List<dynamic> groups = [];
  List<dynamic> following = [];
  bool isLoading = true;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id.toString() ?? '1';

    try {
      final profile = await ApiService.getUserProfile(userId);
      final posts = await ApiService.getUserPosts(userId);
      final followersList = await ApiService.getFollowers(userId);
      final followingList = await ApiService.getFollowing(userId);

      setState(() {
        userProfile = profile;
        userPosts = posts;
        friends = followersList;
        following = followingList;
        profileImageUrl = profile['profile_image_url'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> uploadProfilePicture() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id.toString() ?? '1';

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading...')),
          );
        }

        final imageUrl = await ApiService.uploadMediaWeb(image, userId);
        await ApiService.updateProfileImage(userId, imageUrl);

        setState(() {
          profileImageUrl = imageUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e')),
        );
      }
    }
  }

  Future<void> removeProfilePicture() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id.toString() ?? '1';

    try {
      await ApiService.updateProfileImage(userId, null);

      setState(() {
        profileImageUrl = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void showProfilePictureOptions() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final lang = themeProvider.currentLanguage;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(Translations.get('upload_photo', lang)),
              onTap: () {
                Navigator.pop(context);
                uploadProfilePicture();
              },
            ),
            if (profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(Translations.get('remove_photo', lang)),
                onTap: () {
                  Navigator.pop(context);
                  removeProfilePicture();
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void showSettingsDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final lang = themeProvider.currentLanguage;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(Translations.get('dark_mode', lang)),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
            ),
            const Divider(),
            ListTile(
              title: Text(Translations.get('language', lang)),
              trailing: DropdownButton<String>(
                value: themeProvider.currentLanguage,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.changeLanguage(value);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.currentUser;
    final lang = themeProvider.currentLanguage;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Translations.get('profile', lang),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: GlassBackground(
        child: RefreshIndicator(
          onRefresh: loadProfileData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ProfileTemplate(
              imageUrl: profileImageUrl,
              name: user?.name ?? userProfile?['name'] ?? 'Student Name',
              subtitle: '${user?.course ?? userProfile?['course'] ?? 'Course'} • Year ${user?.year ?? userProfile?['year'] ?? 0}',
              bio: userProfile?['bio'],
              postsCount: userPosts.length,
              friendsCount: friends.length,
              followingCount: following.length,
              onImageTap: showProfilePictureOptions,
              onEditProfile: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit profile coming soon!')),
                );
              },
              onFriendsTap: () async {
                final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
                if (currentUserId != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FollowersListScreen(
                        userId: currentUserId,
                        userName: userProfile?['name'] ?? 'User',
                        showFollowers: true,
                      ),
                    ),
                  );
                  loadProfileData();
                }
              },
              onFollowingTap: () async {
                final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
                if (currentUserId != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FollowersListScreen(
                        userId: currentUserId,
                        userName: userProfile?['name'] ?? 'User',
                        showFollowers: false,
                      ),
                    ),
                  );
                  loadProfileData();
                }
              },
              actions: [
                ProfileAction(
                  title: 'My ${Translations.get('posts', lang)}',
                  icon: Icons.article_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('My posts coming soon!')),
                    );
                  },
                ),
                ProfileAction(
                  title: 'Saved Notes',
                  icon: Icons.bookmark_outline,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved Notes coming soon!')),
                    );
                  },
                ),
                ProfileAction(
                  title: 'My ${Translations.get('groups', lang)}',
                  icon: Icons.groups_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('My groups coming soon!')),
                    );
                  },
                ),
                ProfileAction(
                  title: 'Events',
                  icon: Icons.event_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EventsScreen()),
                    );
                  },
                ),
                ProfileAction(
                  title: 'AI Assistant',
                  icon: Icons.smart_toy_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Assistant coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';

class BookmarksScreen extends StatefulWidget {
  final String userId;

  const BookmarksScreen({super.key, required this.userId});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<dynamic> bookmarks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBookmarks();
  }

  Future<void> loadBookmarks() async {
    try {
      final data = await ApiService.getBookmarks(widget.userId);
      setState(() {
        bookmarks = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookmarks: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookmarks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No saved posts yet'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadBookmarks,
                  child: ListView.builder(
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final post = bookmarks[index];
                      return PostCard(
                        post: post,
                        currentUserId: widget.userId,
                        onUpdate: loadBookmarks,
                      );
                    },
                  ),
                ),
    );
  }
}

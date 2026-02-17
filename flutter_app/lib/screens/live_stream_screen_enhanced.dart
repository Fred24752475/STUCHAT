import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/new_features.dart';

class LiveStreamScreenEnhanced extends StatefulWidget {
  final String userId;

  const LiveStreamScreenEnhanced({super.key, required this.userId});

  @override
  State<LiveStreamScreenEnhanced> createState() =>
      _LiveStreamScreenEnhancedState();
}

class _LiveStreamScreenEnhancedState extends State<LiveStreamScreenEnhanced> {
  List<LiveStreamEnhanced> streams = [];
  bool isLoading = true;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadStreams();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStreams() async {
    try {
      final data = await ApiService.getActiveLiveStreamsEnhanced();
      setState(() {
        streams = (data as List)
            .map((json) => LiveStreamEnhanced.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading streams: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _startStream() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    try {
      await ApiService.createLiveStreamEnhanced(
        widget.userId,
        _titleController.text,
        description: _descriptionController.text,
        category: 'General',
      );

      _titleController.clear();
      _descriptionController.clear();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream started! 🎥')),
      );

      _loadStreams();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting stream: $e')),
      );
    }
  }

  void _showStartStreamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Live Stream'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Stream title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Stream description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _startStream,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Go Live'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streams 🎥'),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStartStreamDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.videocam),
        label: const Text('Go Live'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : streams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No active streams',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStreams,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: streams.length,
                    itemBuilder: (context, index) {
                      final stream = streams[index];
                      return _StreamCard(
                        stream: stream,
                        userId: widget.userId,
                        onRefresh: _loadStreams,
                      );
                    },
                  ),
                ),
    );
  }
}

class _StreamCard extends StatefulWidget {
  final LiveStreamEnhanced stream;
  final String userId;
  final VoidCallback onRefresh;

  const _StreamCard({
    required this.stream,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  late TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      await ApiService.sendLiveStreamCommentEnhanced(
        widget.stream.id.toString(),
        widget.userId,
        _commentController.text,
      );
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendGift() async {
    try {
      await ApiService.sendLiveStreamGiftEnhanced(
        widget.stream.id.toString(),
        widget.userId,
        'heart',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gift sent! 🎁')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stream Header
          Container(
            color: Colors.red.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.stream.broadcasterImage != null
                      ? NetworkImage(widget.stream.broadcasterImage!)
                      : null,
                  child: widget.stream.broadcasterImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stream.broadcasterName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.stream.title,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stream Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.stream.description != null)
                  Text(
                    widget.stream.description!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.stream.viewerCount} watching',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.favorite, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      widget.stream.likes.toString(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Comment Input
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendComment,
                  icon: const Icon(Icons.send, color: Colors.red),
                ),
                IconButton(
                  onPressed: _sendGift,
                  icon: const Icon(Icons.card_giftcard, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

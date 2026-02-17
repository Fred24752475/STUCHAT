import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/live_stream.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'live_stream_broadcaster_screen.dart';
import 'live_stream_viewer_screen.dart';

class LiveStreamsListScreen extends StatefulWidget {
  const LiveStreamsListScreen({super.key});

  @override
  State<LiveStreamsListScreen> createState() => _LiveStreamsListScreenState();
}

class _LiveStreamsListScreenState extends State<LiveStreamsListScreen> {
  List<LiveStream> _liveStreams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLiveStreams();
  }

  Future<void> _loadLiveStreams() async {
    setState(() => _isLoading = true);
    try {
      final streams = await ApiService.getActiveLiveStreams();
      setState(() {
        _liveStreams = streams.cast<LiveStream>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load live streams: $e')),
        );
      }
    }
  }

  void _startLiveStream() {
    showDialog(
      context: context,
      builder: (context) => _CreateStreamDialog(
        onStreamCreated: () {
          Navigator.pop(context);
          _loadLiveStreams();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLiveStreams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _liveStreams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No live streams right now',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startLiveStream,
                        icon: const Icon(Icons.videocam),
                        label: const Text('Go Live'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLiveStreams,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _liveStreams.length,
                    itemBuilder: (context, index) {
                      final stream = _liveStreams[index];
                      return _LiveStreamCard(
                        stream: stream,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveStreamViewerScreen(
                                streamId: stream.id,
                              ),
                            ),
                          ).then((_) => _loadLiveStreams());
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startLiveStream,
        icon: const Icon(Icons.videocam),
        label: const Text('Go Live'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _LiveStreamCard extends StatelessWidget {
  final LiveStream stream;
  final VoidCallback onTap;

  const _LiveStreamCard({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Thumbnail placeholder
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.videocam, size: 64, color: Colors.white54),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Live badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Viewer count
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${stream.viewerCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Stream info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stream.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: stream.profilePicture != null
                              ? NetworkImage(stream.profilePicture!)
                              : null,
                          child: stream.profilePicture == null
                              ? Text(
                                  stream.username[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stream.username,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateStreamDialog extends StatefulWidget {
  final VoidCallback onStreamCreated;

  const _CreateStreamDialog({required this.onStreamCreated});

  @override
  State<_CreateStreamDialog> createState() => _CreateStreamDialogState();
}

class _CreateStreamDialogState extends State<_CreateStreamDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'education';
  bool _isCreating = false;

  final List<String> _categories = [
    'education',
    'entertainment',
    'gaming',
    'music',
    'other',
  ];

  Future<void> _createStream() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await ApiService.createLiveStream(
        authProvider.token!,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _selectedCategory,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LiveStreamBroadcasterScreen(
              streamId: response['streamId'],
              streamKey: response['streamKey'],
              title: _titleController.text.trim(),
            ),
          ),
        );
        widget.onStreamCreated();
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create stream: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Live Stream'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What are you streaming?',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child:
                      Text(category[0].toUpperCase() + category.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createStream,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Go Live'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

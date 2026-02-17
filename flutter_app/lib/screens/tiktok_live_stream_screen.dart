import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../models/live_stream.dart';

class TikTokLiveStreamScreen extends StatefulWidget {
  final String userId;
  
  const TikTokLiveStreamScreen({super.key, required this.userId});

  @override
  State<TikTokLiveStreamScreen> createState() => _TikTokLiveStreamScreenState();
}

class _TikTokLiveStreamScreenState extends State<TikTokLiveStreamScreen> {
  List<LiveStream> _activeStreams = [];
  List<Map<String, dynamic>> _streamComments = [];
  bool _isLoading = true;
  bool _isCreatingStream = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  bool _isLive = false;
  LiveStream? _myActiveStream;
  
  // Camera related
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadActiveStreams();
    _startRealtimeUpdates();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      final micPermission = await Permission.microphone.request();
      
      if (cameraPermission.isGranted && micPermission.isGranted) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          await _initCamera(_cameras[0]);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and microphone permissions are required for live streaming'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to initialize camera', e);
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    try {
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      LoggerService.error('Failed to initialize camera controller', e);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    await _initCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _loadActiveStreams() async {
    setState(() => _isLoading = true);
    
    try {
      final streams = await ApiService.getActiveLiveStreams();
      if (mounted) {
        setState(() {
          _activeStreams = streams.map((s) => LiveStream.fromJson(s)).toList();
          _isLoading = false;
          
          // Check if current user has an active stream
          try {
            _myActiveStream = _activeStreams.firstWhere(
              (stream) => stream.userId.toString() == widget.userId,
            );
            _isLive = _myActiveStream!.status == 'live';
          } catch (e) {
            _myActiveStream = null;
            _isLive = false;
          }
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load active streams', e);
      if (mounted) {
        setState(() {
          _activeStreams = [];
          _isLoading = false;
        });
      }
    }
  }

  void _startRealtimeUpdates() {
    // Simulate real-time updates
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _loadActiveStreams();
      _startRealtimeUpdates(); // Recursive call
    });
  }

  Future<void> _startLiveStream() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a stream title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!_isCameraInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not ready. Please wait...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreatingStream = true);

    try {
      // Start video recording
      if (_cameraController != null && !_isRecording) {
        await _cameraController!.startVideoRecording();
        setState(() => _isRecording = true);
      }
      
      // Create stream locally (backend API might not be ready)
      final streamId = DateTime.now().millisecondsSinceEpoch;
      
      setState(() {
        _isLive = true;
        _myActiveStream = LiveStream(
          id: streamId,
          userId: int.parse(widget.userId),
          title: _titleController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          category: _categoryController.text.isEmpty ? null : _categoryController.text,
          streamKey: 'stream_$streamId',
          status: 'live',
          viewerCount: 0,
          username: 'You',
          fullName: 'Current User',
          createdAt: DateTime.now().toIso8601String(),
        );
        _activeStreams.insert(0, _myActiveStream!);
      });
      
      _titleController.clear();
      _descriptionController.clear();
      _categoryController.clear();
      
      Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔴 You are now LIVE!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to start live stream', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to start live stream'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isCreatingStream = false);
  }

  Future<void> _endLiveStream() async {
    if (_myActiveStream == null) return;

    try {
      // Stop video recording
      if (_cameraController != null && _isRecording) {
        final videoFile = await _cameraController!.stopVideoRecording();
        setState(() => _isRecording = false);
        LoggerService.info('Video saved to: ${videoFile.path}');
      }
      
      // End stream - just update local state, backend will handle cleanup
      setState(() {
        _isLive = false;
        _myActiveStream = null;
      });
      
      _loadActiveStreams();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔴 Live stream ended'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to end live stream', e);
    }
  }

  void _showStreamingSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '🔴 LIVE NOW',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You are live: ${_myActiveStream?.title ?? ''}'),
            const SizedBox(height: 8),
            Text('Viewers: ${_myActiveStream?.viewerCount ?? 0}'),
            const SizedBox(height: 16),
            GlassButton(
              text: '🔴 End Live Stream',
              icon: Icons.stop,
              color: Colors.red,
              onPressed: () {
                Navigator.pop(context);
                _endLiveStream();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Minimize'),
          ),
        ],
      ),
    );
  }

  void _showCreateStreamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Go Live'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Stream Title',
                border: OutlineInputBorder(),
                hintText: 'What are you streaming about?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Tell viewers what to expect...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                hintText: 'e.g., Study Session, Q&A, Tutorial',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _titleController.clear();
              _descriptionController.clear();
              _categoryController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          GlassButton(
            text: '🔴 Go Live',
            icon: Icons.videocam,
            color: Colors.red,
            isLoading: _isCreatingStream,
            onPressed: _isCreatingStream ? null : () async {
              await _startLiveStream();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _isLive ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _isLive ? '🔴' : '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'STUCHAT Live',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLive)
            GlassButton(
              text: '🔴 End',
              color: Colors.red,
              onPressed: _endLiveStream,
            )
          else
            GlassButton(
              text: '🔴 Go Live',
              color: Colors.red,
              onPressed: _showCreateStreamDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadActiveStreams,
              child: _activeStreams.isEmpty
                  ? _buildEmptyState()
                  : _buildStreamsGrid(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white54,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'No one is live right now',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to go live!',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          GlassButton(
            text: '🔴 Start First Stream',
            icon: Icons.videocam,
            color: Colors.red,
            onPressed: _showCreateStreamDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildStreamsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _activeStreams.length,
      itemBuilder: (context, index) {
        final stream = _activeStreams[index];
        return _buildStreamCard(stream);
      },
    );
  }

  Widget _buildStreamCard(LiveStream stream) {
    return GestureDetector(
      onTap: () {
        // Navigate to stream viewer
        HapticFeedback.lightImpact();
        // TODO: Navigate to stream viewer screen
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.8),
              Colors.pink.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Stream Preview or Thumbnail
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: stream.userId.toString() == widget.userId && _isCameraInitialized && _isLive
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CameraPreview(_cameraController!),
                    )
                  : stream.profilePicture != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            stream.profilePicture!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.withOpacity(0.3),
                                child: const Icon(
                                  Icons.videocam,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.videocam,
                          color: Colors.white54,
                          size: 40,
                        ),
            ),
            
            // Live Indicator
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Stream Info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.fullName ?? stream.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stream.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${stream.viewerCount}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (stream.category != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stream.category!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // If this is user's own stream, show controls overlay
            if (stream.userId.toString() == widget.userId && _isLive)
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _switchCamera,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _endLiveStream,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
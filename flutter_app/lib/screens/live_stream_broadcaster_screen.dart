import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/live_stream.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class LiveStreamBroadcasterScreen extends StatefulWidget {
  final int streamId;
  final String streamKey;
  final String title;

  const LiveStreamBroadcasterScreen({
    super.key,
    required this.streamId,
    required this.streamKey,
    required this.title,
  });

  @override
  State<LiveStreamBroadcasterScreen> createState() =>
      _LiveStreamBroadcasterScreenState();
}

class _LiveStreamBroadcasterScreenState
    extends State<LiveStreamBroadcasterScreen> {
  final List<StreamComment> _comments = [];
  final List<StreamGift> _recentGifts = [];
  final TextEditingController _commentController = TextEditingController();
  int _viewerCount = 0;
  
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
    _initializeStream();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraPermission = await Permission.camera.request();
      final micPermission = await Permission.microphone.request();
      
      if (cameraPermission.isGranted && micPermission.isGranted) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          await _initCamera(_cameras[0]);
        }
      }
    } catch (e) {
      print('Failed to initialize camera: $e');
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
        
        // Start recording for live stream
        await _cameraController!.startVideoRecording();
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print('Failed to initialize camera controller: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    await _initCamera(_cameras[_currentCameraIndex]);
  }

  void _initializeStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Join stream room
    SocketService.socket?.emit('start_stream', {
      'streamId': widget.streamId,
      'userId': authProvider.currentUser?.id,
      'title': widget.title,
    });

    // Listen for viewers joining
    SocketService.socket?.on('viewer_joined', (data) {
      setState(() => _viewerCount++);
      _showNotification('${data['username']} joined');
    });

    // Listen for viewers leaving
    SocketService.socket?.on('viewer_left', (data) {
      setState(() => _viewerCount = _viewerCount > 0 ? _viewerCount - 1 : 0);
    });

    // Listen for comments
    SocketService.socket?.on('new_stream_comment', (data) {
      final comment = StreamComment.fromJson(data);
      setState(() {
        _comments.add(comment);
        if (_comments.length > 50) {
          _comments.removeAt(0);
        }
      });
    });

    // Listen for gifts
    SocketService.socket?.on('new_stream_gift', (data) {
      final gift = StreamGift.fromJson(data);
      setState(() {
        _recentGifts.add(gift);
        if (_recentGifts.length > 5) {
          _recentGifts.removeAt(0);
        }
      });
      _showGiftAnimation(gift);
    });
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }

  void _showGiftAnimation(StreamGift gift) {
    // Show gift animation overlay
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Center(
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getGiftEmoji(gift.giftType),
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${gift.username} sent ${gift.amount}x ${gift.giftType}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          onEnd: () => Navigator.pop(context),
        ),
      ),
    );
  }

  String _getGiftEmoji(String giftType) {
    switch (giftType) {
      case 'heart':
        return '❤️';
      case 'star':
        return '⭐';
      case 'fire':
        return '🔥';
      case 'clap':
        return '👏';
      case 'gift':
        return '🎁';
      default:
        return '👍';
    }
  }

  Future<void> _endStream() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Stream?'),
        content: const Text('Are you sure you want to end this live stream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await ApiService.endLiveStream(authProvider.token!, widget.streamId);

        // Notify viewers
        SocketService.socket?.emit('end_stream', {'streamId': widget.streamId});

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to end stream: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview or placeholder
            _isCameraInitialized && _cameraController != null
                ? CameraPreview(_cameraController!)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam,
                          size: 120,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Camera Preview',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stream Key: ${widget.streamKey}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '$_viewerCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _endStream,
                    ),
                  ],
                ),
              ),
            ),

            // Comments section
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  reverse: true,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[_comments.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${comment.username}: ',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: comment.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Gift animations
            if (_recentGifts.isNotEmpty)
              Positioned(
                right: 16,
                bottom: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _recentGifts.map((gift) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _getGiftEmoji(gift.giftType),
                        style: const TextStyle(fontSize: 32),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios,
                          color: Colors.white),
                      onPressed: _switchCamera,
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic, color: Colors.white),
                      onPressed: () {
                        // Toggle microphone
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        // Stream settings
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _endStream,
                      icon: const Icon(Icons.stop),
                      label: const Text('End Stream'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
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

  @override
  void dispose() {
    _commentController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }
}

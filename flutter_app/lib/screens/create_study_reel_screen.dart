import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';

class CreateStudyReelScreen extends StatefulWidget {
  final String userId;
  
  const CreateStudyReelScreen({super.key, required this.userId});

  @override
  State<CreateStudyReelScreen> createState() => _CreateStudyReelScreenState();
}

class _CreateStudyReelScreenState extends State<CreateStudyReelScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hashtagsController = TextEditingController();
  
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isPublic = true;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagsController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        setState(() {
          _videoFile = File(video.path);
        });
        
        _initializeVideoPlayer();
      }
    } catch (e) {
      LoggerService.error('Error picking video', e);
      _showError('Failed to pick video');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        setState(() {
          _videoFile = File(video.path);
        });
        
        _initializeVideoPlayer();
      }
    } catch (e) {
      LoggerService.error('Error recording video', e);
      _showError('Failed to record video');
    }
  }

  void _initializeVideoPlayer() {
    if (_videoFile != null) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  Future<void> _createReel() async {
    if (_videoFile == null || _titleController.text.trim().isEmpty) {
      _showError('Please select a video and enter a title');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final result = await ApiService.createStudyReelWithVideo(
        userId: widget.userId,
        videoFile: _videoFile!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        hashtags: _hashtagsController.text.trim(),
        isPublic: _isPublic,
      );

      if (result['success'] == true) {
        HapticFeedback.lightImpact();
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Study reel created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError(result['error'] ?? 'Failed to create reel');
      }
    } catch (e) {
      LoggerService.error('Error creating reel', e);
      _showError('Failed to create reel: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
        title: const Text(
          'Create Study Reel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _isUploading ? null : _createReel,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _videoFile == null ? _buildVideoSelection() : _buildVideoEditor(),
    );
  }

  Widget _buildVideoSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.white54,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'Create Your Study Reel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share your knowledge with the community',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GlassButton(
                text: 'Record',
                icon: Icons.videocam,
                color: Colors.red,
                onPressed: _recordVideo,
              ),
              GlassButton(
                text: 'Gallery',
                icon: Icons.photo_library,
                color: Colors.blue,
                onPressed: _pickVideo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoEditor() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Video Preview
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            color: Colors.black,
            child: _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'Enter a catchy title...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                
                // Description
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'Describe what you\'re teaching...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                
                // Hashtags
                TextField(
                  controller: _hashtagsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Hashtags',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: '#math #physics #studytips',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Privacy Toggle
                GlassCard(
                  child: SwitchListTile(
                    title: const Text(
                      'Public',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _isPublic ? 'Everyone can see this reel' : 'Only you can see this reel',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                    activeColor: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        text: 'Change Video',
                        icon: Icons.swap_horiz,
                        color: Colors.grey,
                        onPressed: () {
                          setState(() {
                            _videoFile = null;
                            _videoController?.dispose();
                            _videoController = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: GlassButton(
                        text: _isUploading ? 'Uploading...' : 'Create Reel',
                        icon: _isUploading ? Icons.upload : Icons.publish,
                        color: Colors.blue,
                        onPressed: _isUploading ? null : _createReel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
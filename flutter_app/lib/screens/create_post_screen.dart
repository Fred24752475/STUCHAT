import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_card.dart';

class CreatePostScreen extends StatefulWidget {
  final String userId;

  const CreatePostScreen({super.key, required this.userId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isVideoInitialized = false;

  @override
  void dispose() {
    _contentController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedVideo = null;
          _videoController?.dispose();
          _videoController = null;
          _isVideoInitialized = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      
      if (video != null) {
        final videoFile = File(video.path);
        final controller = VideoPlayerController.file(videoFile);
        
        await controller.initialize();
        
        setState(() {
          _selectedVideo = videoFile;
          _selectedImage = null;
          _videoController = controller;
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      LoggerService.error('Error picking video: $e');
      _showErrorSnackBar('Failed to pick video: $e');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _selectedVideo = null;
          _videoController?.dispose();
          _videoController = null;
          _isVideoInitialized = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error capturing photo: $e');
      _showErrorSnackBar('Failed to capture photo: $e');
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && 
        _selectedImage == null && 
        _selectedVideo == null) {
      _showErrorSnackBar('Please add content, image, or video to create a post');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl;
      String? videoUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        imageUrl = await ApiService.uploadMedia(_selectedImage!, widget.userId);
      }

      // Upload video if selected
      if (_selectedVideo != null) {
        videoUrl = await ApiService.uploadMedia(_selectedVideo!, widget.userId);
      }

      // Create post with all content - matches database schema exactly
      final postResult = await ApiService.createPost(
        token: 'dummy_token', // You may need to get actual token
        userId: widget.userId,
        content: _contentController.text.trim(),
        imageUrl: imageUrl,
        videoUrl: videoUrl,
      );
      
      if (postResult['id'] != null) {
        _showSuccessSnackBar('Post created successfully!');
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to create post');
      }

    } catch (e) {
      LoggerService.error('Error creating post: $e');
      _showErrorSnackBar('Failed to create post: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _createPost,
              child: const Text(
                'POST',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'student@university.edu',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Content input field
            GlassTextField(
              controller: _contentController,
              hintText: 'What\'s on your mind?',
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            
            const SizedBox(height: 16),
            
            // Media preview section
            if (_selectedImage != null || _selectedVideo != null) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (_selectedVideo != null && _isVideoInitialized)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    // Remove media button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeMedia,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description field for media
              GlassTextField(
                controller: _descriptionController,
                hintText: 'Add a description to your media...',
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Media selection buttons
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    text: 'Gallery',
                    onPressed: _pickImage,
                    icon: Icons.photo_library,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    text: 'Video',
                    onPressed: _pickVideo,
                    icon: Icons.videocam,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                GlassButton(
                  text: 'Camera',
                  onPressed: _capturePhoto,
                  icon: Icons.camera_alt,
                  color: Colors.green,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Tips section
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Tips:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Add text content for better engagement\n'
                    '• High-quality images get more likes\n'
                    '• Videos should be under 60 seconds\n'
                    '• Add descriptions to explain your media',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
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
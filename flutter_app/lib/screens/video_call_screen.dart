import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final bool isIncoming;
  final String? callId;
  final String callType; // 'video' or 'audio'

  const VideoCallScreen({
    super.key,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
    this.isIncoming = false,
    this.callId,
    this.callType = 'video',
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  
  bool isMuted = false;
  bool isVideoOff = false;
  bool isSpeakerOn = true;
  bool isCallActive = false;
  bool isInitializing = true;
  Timer? _callTimer;
  int _callDuration = 0;
  String? _currentCallId;

  @override
  void initState() {
    super.initState();
    _currentCallId = widget.callId;
    _initializeWebRTC();
    _setupCallListeners();
  }

  Future<void> _initializeWebRTC() async {
    try {
      final isAudioOnly = widget.callType == 'audio';
      await _webrtcService.initialize(widget.userId, audioOnly: isAudioOnly);
      
      if (widget.isIncoming) {
        isCallActive = false;
      } else {
        await _webrtcService.getUserMedia(video: !isAudioOnly);
        await _webrtcService.createPeerConnection(widget.otherUserId, isCaller: true);
      }
      
      setState(() {
        isInitializing = false;
        if (isAudioOnly) {
          isVideoOff = true;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _setupCallListeners() {
    SocketService.onCallAnswered((data) {
      setState(() {
        isCallActive = true;
      });
      _startCallTimer();
    });

    SocketService.onCallRejected(() {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call was rejected')),
        );
        _cleanupAndPop();
      }
    });

    SocketService.onCallEnded(() {
      _cleanupAndPop();
    });

    _webrtcService.remoteStreamStream.listen((stream) {
      if (mounted) {
        setState(() {
          isCallActive = true;
        });
        _startCallTimer();
      }
    });
  }

  Future<void> _answerCall() async {
    try {
      final isAudioOnly = widget.callType == 'audio';
      await _webrtcService.getUserMedia(video: !isAudioOnly);
      await _webrtcService.createPeerConnection(widget.otherUserId, isCaller: false);
      
      setState(() {
        isCallActive = true;
        if (isAudioOnly) {
          isVideoOff = true;
        }
      });

      if (_currentCallId != null) {
        SocketService.answerCall(widget.otherUserId);
      }

      _startCallTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to answer call: $e')),
        );
      }
    }
  }

  void _rejectCall() {
    if (_currentCallId != null) {
      SocketService.rejectCall(widget.otherUserId);
    }
    _cleanupAndPop();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();

    if (_currentCallId != null) {
      SocketService.endCall(widget.otherUserId);
    }

    await _webrtcService.endCall();
    _cleanupAndPop();
  }

  void _cleanupAndPop() {
    _callTimer?.cancel();
    _webrtcService.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    setState(() {
      isMuted = !isMuted;
    });
    _webrtcService.toggleAudio(!isMuted);
  }

  void _toggleVideo() {
    setState(() {
      isVideoOff = !isVideoOff;
    });
    _webrtcService.toggleVideo(!isVideoOff);
  }

  void _switchCamera() {
    _webrtcService.switchCamera();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isAudioOnly = widget.callType == 'audio';
    
    return Scaffold(
      backgroundColor: isAudioOnly ? Colors.grey[900] : Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen) - only show if not audio-only
            if (!isAudioOnly && _webrtcService.remoteRenderer.textureId != null)
              RTCVideoView(_webrtcService.remoteRenderer)
            else
              _buildPlaceholder(isAudioOnly: isAudioOnly),

            // Local video (picture-in-picture) - only show if not audio-only
            if (!isAudioOnly && !isVideoOff && _webrtcService.localRenderer.textureId != null)
              Positioned(
                top: 80,
                right: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(_webrtcService.localRenderer),
                ),
              ),

            // Top info bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Video Call', style: TextStyle(color: Colors.white)),
                  ),
                  if (isCallActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, color: Colors.white, size: 8),
                          const SizedBox(width: 8),
                          Text(_formatDuration(_callDuration), style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // User info at bottom left
            Positioned(
              bottom: 120,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: widget.otherUserImage != null
                        ? NetworkImage(widget.otherUserImage!)
                        : null,
                    child: widget.otherUserImage == null
                        ? Text(widget.otherUserName[0].toUpperCase(), style: const TextStyle(fontSize: 24))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isCallActive
                        ? _formatDuration(_callDuration)
                        : widget.isIncoming
                            ? 'Incoming call...'
                            : 'Calling...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: widget.isIncoming && !isCallActive && !isInitializing
                  ? _buildIncomingCallControls()
                  : _buildActiveCallControls(),
            ),

            // Loading indicator
            if (isInitializing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder({bool isAudioOnly = false}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isAudioOnly 
              ? [Colors.grey[900]!, Colors.black]
              : [Colors.blue.shade900, Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.otherUserImage != null
                  ? NetworkImage(widget.otherUserImage!)
                  : null,
              child: widget.otherUserImage == null
                  ? Text(widget.otherUserName[0].toUpperCase(), style: const TextStyle(fontSize: 40))
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              widget.otherUserName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isCallActive
                  ? _formatDuration(_callDuration)
                  : widget.isIncoming
                      ? 'Incoming call...'
                      : 'Connecting...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            FloatingActionButton(
              onPressed: _rejectCall,
              backgroundColor: Colors.red,
              heroTag: 'reject',
              child: const Icon(Icons.call_end, size: 32),
            ),
            const SizedBox(height: 8),
            const Text('Decline', style: TextStyle(color: Colors.white)),
          ],
        ),
        Column(
          children: [
            FloatingActionButton(
              onPressed: _answerCall,
              backgroundColor: Colors.green,
              heroTag: 'answer',
              child: const Icon(Icons.call, size: 32),
            ),
            const SizedBox(height: 8),
            const Text('Answer', style: TextStyle(color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveCallControls() {
    final isAudioOnly = widget.callType == 'audio';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Unmute' : 'Mute',
          onPressed: _toggleMute,
          isActive: isMuted,
        ),
        if (!isAudioOnly) ...[
          _buildControlButton(
            icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: isVideoOff ? 'Video On' : 'Video Off',
            onPressed: _toggleVideo,
            isActive: isVideoOff,
          ),
          _buildControlButton(
            icon: Icons.cameraswitch,
            label: 'Flip',
            onPressed: _switchCamera,
          ),
        ],
        _buildControlButton(
          icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          label: isSpeakerOn ? 'Speaker' : 'Earpiece',
          onPressed: () {
            setState(() {
              isSpeakerOn = !isSpeakerOn;
            });
          },
          isActive: isSpeakerOn,
        ),
        FloatingActionButton(
          onPressed: _endCall,
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, size: 32),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            iconSize: 32,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    try {
      _webrtcService.dispose();
    } catch (e) {
      debugPrint('Error disposing WebRTC service: $e');
    }
    super.dispose();
  }
}

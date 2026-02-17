import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import '../services/logger_service.dart';

class GroupCallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String roomId;
  final List<Map<String, dynamic>> participants;
  final bool isHost;

  const GroupCallScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.roomId,
    required this.participants,
    this.isHost = false,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isInitialized = false;
  Timer? _callTimer;
  int _callDuration = 0;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _participants = List.from(widget.participants);
    _participants.add({
      'id': widget.userId,
      'name': widget.userName,
      'isLocal': true,
    });
    _initializeCall();
    _setupSocketListeners();
  }

  Future<void> _initializeCall() async {
    try {
      await _localRenderer.initialize();
      
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': true,
      });
      
      _localRenderer.srcObject = _localStream;
      
      // Create peer connections for each participant
      for (var participant in widget.participants) {
        if (participant['id'] != widget.userId) {
          await _createPeerConnection(participant['id'], isCaller: true);
        }
      }
      
      setState(() {
        _isInitialized = true;
      });
      
      _startCallTimer();
    } catch (e) {
      LoggerService.error('Error initializing group call', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call: $e')),
        );
      }
    }
  }

  void _setupSocketListeners() {
    SocketService.onGroupCallOffer(_handleOffer);
    SocketService.onGroupCallAnswer(_handleAnswer);
    SocketService.onGroupCallICECandidate(_handleICECandidate);
    SocketService.onUserJoinedGroupCall(_handleUserJoined);
    SocketService.onUserLeftGroupCall(_handleUserLeft);
  }

  Future<void> _createPeerConnection(String peerId, {bool isCaller = true}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    
    final pc = await createPeerConnection(config);
    _peerConnections[peerId] = pc;
    
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _remoteRenderers[peerId] = renderer;
    
    pc.onIceCandidate = (candidate) {
      SocketService.sendGroupCallICECandidate(widget.roomId, peerId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteStreams[peerId] = event.streams[0];
          _remoteRenderers[peerId]!.srcObject = event.streams[0];
        });
      }
    };
    
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }
    
    if (isCaller) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      SocketService.sendGroupCallOffer(widget.roomId, peerId, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    final from = data['from'];
    final roomId = data['roomId'];
    
    if (roomId != widget.roomId) return;
    
    if (!_peerConnections.containsKey(from)) {
      await _createPeerConnection(from, isCaller: false);
    }
    
    final pc = _peerConnections[from]!;
    final desc = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
    await pc.setRemoteDescription(desc);
    
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    
    SocketService.sendGroupCallAnswer(widget.roomId, from, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    final from = data['from'];
    final roomId = data['roomId'];
    
    if (roomId != widget.roomId) return;
    
    final pc = _peerConnections[from];
    if (pc == null) return;
    
    final desc = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
    await pc.setRemoteDescription(desc);
  }

  Future<void> _handleICECandidate(Map<String, dynamic> data) async {
    final from = data['from'];
    final roomId = data['roomId'];
    
    if (roomId != widget.roomId) return;
    
    final pc = _peerConnections[from];
    if (pc == null) return;
    
    final candidate = data['candidate'];
    await pc.addCandidate(RTCIceCandidate(
      candidate['candidate'],
      candidate['sdpMid'],
      candidate['sdpMLineIndex'],
    ));
  }

  void _handleUserJoined(Map<String, dynamic> data) {
    final roomId = data['roomId'];
    if (roomId != widget.roomId) return;
    
    final userId = data['userId'];
    final userName = data['userName'];
    
    setState(() {
      _participants.add({
        'id': userId,
        'name': userName,
      });
    });
    
    _createPeerConnection(userId, isCaller: true);
  }

  void _handleUserLeft(Map<String, dynamic> data) {
    final roomId = data['roomId'];
    if (roomId != widget.roomId) return;
    
    final userId = data['userId'];
    
    setState(() {
      _participants.removeWhere((p) => p['id'] == userId);
    });
    
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _remoteRenderers[userId]?.dispose();
    _remoteRenderers.remove(userId);
    _remoteStreams.remove(userId);
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isVideoOff;
    });
  }

  void _leaveCall() {
    SocketService.leaveGroupCall(widget.roomId, widget.userId);
    _cleanup();
    Navigator.pop(context);
  }

  void _cleanup() {
    _callTimer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localRenderer.dispose();
    
    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    
    for (var renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    _remoteRenderers.clear();
    _remoteStreams.clear();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Group Call (${_participants.length})'),
        actions: [
          Text(_formatDuration(_callDuration)),
          const SizedBox(width: 16),
        ],
      ),
      body: _isInitialized ? _buildGrid() : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _buildControls(),
    );
  }

  Widget _buildGrid() {
    final participantCount = _remoteStreams.length + 1; // +1 for local
    final crossAxisCount = participantCount <= 2 ? 2 : (participantCount <= 4 ? 2 : 3);
    
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 3 / 4,
      ),
      itemCount: _remoteStreams.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildLocalVideo();
        }
        final peerId = _remoteStreams.keys.elementAt(index - 1);
        return _buildRemoteVideo(peerId);
      },
    );
  }

  Widget _buildLocalVideo() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isVideoOff 
          ? Container(color: Colors.grey[800], child: const Icon(Icons.videocam_off, size: 48, color: Colors.white))
          : RTCVideoView(_localRenderer),
    );
  }

  Widget _buildRemoteVideo(String peerId) {
    final renderer = _remoteRenderers[peerId];
    if (renderer == null || renderer.srcObject == null) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: RTCVideoView(renderer),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Unmute' : 'Mute',
            onPressed: _toggleMute,
            isActive: _isMuted,
          ),
          _buildControlButton(
            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: _isVideoOff ? 'Video On' : 'Video Off',
            onPressed: _toggleVideo,
            isActive: _isVideoOff,
          ),
          FloatingActionButton(
            onPressed: _leaveCall,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.3) : Colors.grey[700],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            iconSize: 28,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

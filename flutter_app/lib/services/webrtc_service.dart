import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';
import 'logger_service.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;

  bool _isInitialized = false;
  bool _isRendererInitialized = false;
  bool _isAudioOnly = false;
  String? _currentUserId;
  String? _remoteUserId;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  MediaStreamTrack? _localVideoTrack;

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStreamStream => _remoteStreamController.stream;

  WebRTCService() {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
  }

  bool get isAudioOnly => _isAudioOnly;

  Future<void> initialize(String userId, {bool audioOnly = false}) async {
    _isAudioOnly = audioOnly;
    _currentUserId = userId;

    if (!audioOnly) {
      try {
        await _localRenderer.initialize();
        await _remoteRenderer.initialize();
        _isRendererInitialized = true;
      } catch (e) {
        LoggerService.error('Error initializing renderers', e);
        _isRendererInitialized = false;
      }
    }

    _setupSocketListeners();

    _isInitialized = true;
    LoggerService.info('WebRTC Service initialized - AudioOnly: $audioOnly');
  }

  void _setupSocketListeners() {
    SocketService.onWebRTCOffer(_handleOffer);
    SocketService.onWebRTCAnswer(_handleAnswer);
    SocketService.onWebRTCICECandidate(_handleICECandidate);
  }

  Future<MediaStream> getUserMedia({bool video = true, bool audio = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
    
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      _localVideoTrack = _localStream!.getVideoTracks().first;
    }
    
    return _localStream!;
  }

  Future<void> createPeerConnection(String remoteUserId, {bool isCaller = true}) async {
    _remoteUserId = remoteUserId;

    try {
      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };
      
      _peerConnection = await _createPeerConnection(config);
    } catch(e) {
      LoggerService.error('Error creating peer connection', e);
      return;
    }

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      LoggerService.info('Sending ICE candidate to $_remoteUserId');
      SocketService.sendICECandidate(_remoteUserId!, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      LoggerService.info('ICE Connection State: $state');
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      LoggerService.info('Received remote track');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        _remoteStreamController.add(_remoteStream!);
      }
    };

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }
    }

    if (isCaller) {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      LoggerService.info('Sending offer to $_remoteUserId');
      SocketService.sendOffer(_remoteUserId!, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(Map<String, dynamic> config) async {
    // This is a workaround for the API signature issue
    // ignore: avoid_dynamic_calls
    return await (createPeerConnection as dynamic)(config);
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    final from = data['from'];
    final offer = data['offer'];

    LoggerService.info('Received offer from $from');

    if (_peerConnection == null) {
      await createPeerConnection(from, isCaller: false);
    }

    RTCSessionDescription desc = RTCSessionDescription(offer['sdp'], offer['type']);
    await _peerConnection!.setRemoteDescription(desc);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    LoggerService.info('Sending answer to $from');
    SocketService.sendAnswer(from, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    final answer = data['answer'];
    LoggerService.info('Received answer');

    RTCSessionDescription desc = RTCSessionDescription(answer['sdp'], answer['type']);
    await _peerConnection!.setRemoteDescription(desc);
  }

  Future<void> _handleICECandidate(Map<String, dynamic> data) async {
    final candidate = data['candidate'];
    LoggerService.info('Received ICE candidate');

    RTCIceCandidate iceCandidate = RTCIceCandidate(
      candidate['candidate'],
      candidate['sdpMid'],
      candidate['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(iceCandidate);
  }

  void toggleAudio(bool enabled) {
    _isAudioEnabled = enabled;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
    }
  }

  void toggleVideo(bool enabled) {
    _isVideoEnabled = enabled;
    if (_localVideoTrack != null) {
      _localVideoTrack!.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localVideoTrack != null) {
      await Helper.switchCamera(_localVideoTrack!);
    }
  }

  Future<void> endCall() async {
    LoggerService.info('Ending WebRTC call');

    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      _remoteStream?.getTracks().forEach((track) => track.stop());
    } catch (e) {
      LoggerService.error('Error stopping tracks', e);
    }

    try {
      await _peerConnection?.close();
    } catch (e) {
      LoggerService.error('Error closing peer connection', e);
    }
    _peerConnection = null;

    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (e) {
      LoggerService.error('Error clearing renderers', e);
    }

    _localStream = null;
    _remoteStream = null;
    _remoteUserId = null;
  }

  Future<void> dispose() async {
    await endCall();
    
    if (_isRendererInitialized) {
      try {
        if (_localRenderer != null) {
          await _localRenderer.dispose();
        }
      } catch (e) {
        LoggerService.error('Error disposing local renderer', e);
      }
      try {
        if (_remoteRenderer != null) {
          await _remoteRenderer.dispose();
        }
      } catch (e) {
        LoggerService.error('Error disposing remote renderer', e);
      }
    }
    try {
      if (!_remoteStreamController.isClosed) {
        await _remoteStreamController.close();
      }
    } catch (e) {
      LoggerService.error('Error closing stream controller', e);
    }
    _isInitialized = false;
    _isRendererInitialized = false;
    LoggerService.info('WebRTC Service disposed');
  }
}

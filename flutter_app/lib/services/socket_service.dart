import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'logger_service.dart';

class SocketService {
  static io.Socket? _socket;
  static bool _isConnected = false;
  static String? _currentUserId;
  static Timer? _reconnectTimer;
  static int _reconnectAttempts = 0;
  static final int _maxReconnectAttempts = 5;
  static final List<Map<String, dynamic>> _offlineMessageQueue = [];
  
  static io.Socket? get socket => _socket;

  static bool get isConnected => _isConnected;

  // Set this to true when deploying to production
  static const bool useProduction = true;
  static const String productionUrl = 'https://stuchat-1-exlv.onrender.com';

  static String get socketUrl {
    if (useProduction) {
      return productionUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://localhost:3000';
    }
  }

  static void connect(String userId) {
// ... (rest of the file is unchanged)
    if (_socket != null && _isConnected) {
      LoggerService.info('Socket already connected');
      return;
    }

    _currentUserId = userId;
    LoggerService.info('Connecting socket to: $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'userId': userId})
          .enableReconnection()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      LoggerService.info('Socket connected successfully');
      _isConnected = true;
      _reconnectAttempts = 0;
      _socket!.emit('user_online', {'userId': userId});
      _processOfflineQueue();
    });

    _socket!.onDisconnect((_) {
      LoggerService.warning('Socket disconnected');
      _isConnected = false;
      _attemptReconnect();
    });

    _socket!.onError((error) {
      LoggerService.error('Socket error', error);
    });

    _socket!.onReconnect((_) {
      LoggerService.info('Socket reconnected');
      _reconnectAttempts = 0;
    });

    _socket!.onReconnectAttempt((attempt) {
      LoggerService.info('Reconnection attempt: $attempt');
    });

    _socket!.onReconnectError((error) {
      LoggerService.error('Reconnection error', error);
    });

    _socket!.onReconnectFailed((_) {
      LoggerService.error(
          'Reconnection failed after $_maxReconnectAttempts attempts');
    });
  }

  static void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      LoggerService.error('Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _calculateBackoff(_reconnectAttempts));

    LoggerService.info(
        'Attempting reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentUserId != null && !_isConnected) {
        connect(_currentUserId!);
      }
    });
  }

  static int _calculateBackoff(int attempt) {
    return (2 ^ attempt).clamp(1, 30);
  }

  static void _processOfflineQueue() {
    if (_offlineMessageQueue.isEmpty) return;

    LoggerService.info(
        'Processing ${_offlineMessageQueue.length} offline messages');

    for (final message in _offlineMessageQueue) {
      final event = message['event'] as String;
      final data = message['data'];
      _socket!.emit(event, data);
    }

    _offlineMessageQueue.clear();
  }

  static void _queueMessage(String event, dynamic data) {
    _offlineMessageQueue.add({'event': event, 'data': data});
    LoggerService.info('Message queued for offline delivery');
  }

  static void disconnect() {
    _reconnectTimer?.cancel();
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      _currentUserId = null;
      LoggerService.info('Socket disconnected');
    }
  }

  // Real-time chat events
  static void sendMessage(Map<String, dynamic> message) {
    if (_isConnected) {
      _socket!.emit('send_message', message);
    } else {
      _queueMessage('send_message', message);
    }
  }

  static void onNewMessage(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_message', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onTyping(Function(Map<String, dynamic>) callback) {
    _socket!.on('user_typing', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void emitTyping(String receiverId, bool isTyping) {
    if (_isConnected) {
      _socket!.emit('typing', {
        'receiverId': receiverId,
        'isTyping': isTyping,
      });
    }
  }

  // Online status
  static void onUserStatusChange(Function(Map<String, dynamic>) callback) {
    _socket!.on('user_status', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  // Notifications
  static void onNotification(Function(Map<String, dynamic>) callback) {
    _socket!.on('notification', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  // Post reactions
  static void onPostReaction(Function(Map<String, dynamic>) callback) {
    _socket!.on('post_reaction', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  // Read receipts
  static void markMessageAsRead(String messageId, String senderId) {
    if (_isConnected) {
      _socket!.emit('message_read', {
        'messageId': messageId,
        'senderId': senderId,
      });
    }
  }

  static void onMessageRead(Function(Map<String, dynamic>) callback) {
    _socket!.on('message_read', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  // Video/Voice Call Events
  static void callUser(
      String receiverId, String callerId, String callType, String callId) {
    if (_isConnected) {
      _socket!.emit('call_user', {
        'to': receiverId,
        'from': callerId,
        'callType': callType,
        'callId': callId,
      });
    }
  }

  static void onIncomingCall(Function(Map<String, dynamic>) callback) {
    _socket!.on('incoming_call', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void answerCall(String callerId) {
    if (_isConnected) {
      _socket!.emit('answer_call', {
        'to': callerId,
      });
    }
  }

  static void onCallAnswered(Function(Map<String, dynamic>) callback) {
    _socket!.on('call_answered', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void rejectCall(String callerId) {
    if (_isConnected) {
      _socket!.emit('reject_call', {
        'to': callerId,
      });
    }
  }

  static void onCallRejected(Function() callback) {
    _socket!.on('call_rejected', (_) {
      callback();
    });
  }

  static void endCall(String otherUserId) {
    if (_isConnected) {
      _socket!.emit('end_call', {
        'to': otherUserId,
      });
    }
  }

  static void onCallEnded(Function() callback) {
    _socket!.on('call_ended', (_) {
      callback();
    });
  }

  // WebRTC Signaling Events
  static void sendOffer(String targetUserId, Map<String, dynamic> offer) {
    if (_isConnected) {
      _socket!.emit('webrtc_offer', {
        'to': targetUserId,
        'offer': offer,
      });
    }
  }

  static void onWebRTCOffer(Function(Map<String, dynamic>) callback) {
    _socket!.on('webrtc_offer', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void sendAnswer(String targetUserId, Map<String, dynamic> answer) {
    if (_isConnected) {
      _socket!.emit('webrtc_answer', {
        'to': targetUserId,
        'answer': answer,
      });
    }
  }

  static void onWebRTCAnswer(Function(Map<String, dynamic>) callback) {
    _socket!.on('webrtc_answer', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void sendICECandidate(String targetUserId, Map<String, dynamic> candidate) {
    if (_isConnected) {
      _socket!.emit('webrtc_ice_candidate', {
        'to': targetUserId,
        'candidate': candidate,
      });
    }
  }

  static void onWebRTCICECandidate(Function(Map<String, dynamic>) callback) {
    _socket!.on('webrtc_ice_candidate', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  // Live streaming events
  static void startStream(int streamId, int userId, String title) {
    if (_isConnected) {
      _socket!.emit('start_stream', {
        'streamId': streamId,
        'userId': userId,
        'title': title,
      });
    }
  }

  static void joinStream(int streamId, int userId, String username) {
    if (_isConnected) {
      _socket!.emit('join_stream', {
        'streamId': streamId,
        'userId': userId,
        'username': username,
      });
    }
  }

  static void leaveStream(int streamId, int userId, String username) {
    if (_isConnected) {
      _socket!.emit('leave_stream', {
        'streamId': streamId,
        'userId': userId,
        'username': username,
      });
    }
  }

  static void sendStreamComment(int streamId, Map<String, dynamic> comment) {
    if (_isConnected) {
      _socket!.emit('stream_comment', {
        'streamId': streamId,
        'comment': comment,
      });
    }
  }

  static void sendStreamGift(int streamId, Map<String, dynamic> gift) {
    if (_isConnected) {
      _socket!.emit('stream_gift', {
        'streamId': streamId,
        'gift': gift,
      });
    }
  }

  static void endStream(int streamId) {
    if (_isConnected) {
      _socket!.emit('end_stream', {
        'streamId': streamId,
      });
    }
  }

  static void onNewStream(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_stream', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onViewerJoined(Function(Map<String, dynamic>) callback) {
    _socket!.on('viewer_joined', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onViewerLeft(Function(Map<String, dynamic>) callback) {
    _socket!.on('viewer_left', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onNewStreamComment(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_stream_comment', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onNewStreamGift(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_stream_gift', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onStreamEnded(Function() callback) {
    _socket!.on('stream_ended', (_) {
      callback();
    });
  }

  // Group Call Events
  static void createGroupCallRoom(String roomId, String userId, String userName, List<Map<String, dynamic>> participants) {
    if (_isConnected) {
      _socket!.emit('create_group_call', {
        'roomId': roomId,
        'userId': userId,
        'userName': userName,
        'participants': participants,
      });
    }
  }

  static void joinGroupCall(String roomId, String userId, String userName) {
    if (_isConnected) {
      _socket!.emit('join_group_call', {
        'roomId': roomId,
        'userId': userId,
        'userName': userName,
      });
    }
  }

  static void leaveGroupCall(String roomId, String userId) {
    if (_isConnected) {
      _socket!.emit('leave_group_call', {
        'roomId': roomId,
        'userId': userId,
      });
    }
  }

  static void sendGroupCallOffer(String roomId, String targetUserId, Map<String, dynamic> offer) {
    if (_isConnected) {
      _socket!.emit('group_call_offer', {
        'roomId': roomId,
        'to': targetUserId,
        'offer': offer,
      });
    }
  }

  static void sendGroupCallAnswer(String roomId, String targetUserId, Map<String, dynamic> answer) {
    if (_isConnected) {
      _socket!.emit('group_call_answer', {
        'roomId': roomId,
        'to': targetUserId,
        'answer': answer,
      });
    }
  }

  static void sendGroupCallICECandidate(String roomId, String targetUserId, Map<String, dynamic> candidate) {
    if (_isConnected) {
      _socket!.emit('group_call_ice_candidate', {
        'roomId': roomId,
        'to': targetUserId,
        'candidate': candidate,
      });
    }
  }

  static void onGroupCallOffer(Function(Map<String, dynamic>) callback) {
    _socket!.on('group_call_offer', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onGroupCallAnswer(Function(Map<String, dynamic>) callback) {
    _socket!.on('group_call_answer', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onGroupCallICECandidate(Function(Map<String, dynamic>) callback) {
    _socket!.on('group_call_ice_candidate', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onUserJoinedGroupCall(Function(Map<String, dynamic>) callback) {
    _socket!.on('user_joined_group_call', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onUserLeftGroupCall(Function(Map<String, dynamic>) callback) {
    _socket!.on('user_left_group_call', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onGroupCallCreated(Function(Map<String, dynamic>) callback) {
    _socket!.on('group_call_created', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onGroupCallEnded(Function(Map<String, dynamic>) callback) {
    _socket!.on('group_call_ended', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  // Notifications
  static void requestNotifications(String userId) {
    if (_isConnected) {
      _socket!.emit('get_notifications', {'userId': userId});
    }
  }

  static void onNewNotification(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_notification', (data) {
      callback(data as Map<String, dynamic>);
    });
  }

  static void onNotificationsList(Function(List<dynamic>) callback) {
    _socket!.on('notifications_list', (data) {
      callback(data as List<dynamic>);
    });
  }

  // Friend request notifications
  static void onFriendRequestReceived(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_notification', (data) {
      if (data['type'] == 'friend_request') {
        callback(data as Map<String, dynamic>);
      }
    });
  }

  static void onFriendRequestAccepted(Function(Map<String, dynamic>) callback) {
    _socket!.on('new_notification', (data) {
      if (data['type'] == 'friend_accepted') {
        callback(data as Map<String, dynamic>);
      }
    });
  }
}

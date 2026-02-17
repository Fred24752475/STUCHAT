import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'video_call_screen.dart';

class RealTimeChatScreen extends StatefulWidget {
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const RealTimeChatScreen({
    super.key,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<RealTimeChatScreen> createState() => _RealTimeChatScreenState();
}

class _RealTimeChatScreenState extends State<RealTimeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isTyping = false;
  bool isOnline = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    loadMessages();
    setupSocketListeners();
  }

  void setupSocketListeners() {
    SocketService.onNewMessage((data) {
      if (data['senderId'] == widget.otherUserId ||
          data['receiverId'] == widget.otherUserId) {
        setState(() {
          messages.add(data);
        });
        _scrollToBottom();

        if (data['senderId'] == widget.otherUserId) {
          SocketService.markMessageAsRead(
            data['id'].toString(),
            widget.otherUserId,
          );
        }
      }
    });

    SocketService.onTyping((data) {
      if (data['userId'] == widget.otherUserId) {
        setState(() {
          isTyping = data['isTyping'] ?? false;
        });
      }
    });

    SocketService.onUserStatusChange((data) {
      if (data['userId'] == widget.otherUserId) {
        setState(() {
          isOnline = data['isOnline'] ?? false;
        });
      }
    });

    SocketService.onMessageRead((data) {
      if (data['senderId'] == widget.userId) {
        setState(() {
          final index = messages.indexWhere(
            (msg) => msg['id'].toString() == data['messageId'],
          );
          if (index != -1) {
            messages[index]['is_read'] = 1;
          }
        });
      }
    });

    SocketService.onIncomingCall((data) {
      if (data['from'] == widget.otherUserId) {
        _showIncomingCallDialog(data);
      }
    });
  }

  void _showIncomingCallDialog(Map<String, dynamic> callData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Incoming ${callData['callType']} call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.otherUserImage != null
                  ? NetworkImage(widget.otherUserImage!)
                  : null,
              child: widget.otherUserImage == null
                  ? Text(widget.otherUserName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('is calling you...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SocketService.rejectCall(widget.otherUserId);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    userId: widget.userId,
                    otherUserId: widget.otherUserId,
                    otherUserName: widget.otherUserName,
                    otherUserImage: widget.otherUserImage,
                    isIncoming: true,
                    callId: callData['callId'],
                    callType: callData['callType'] ?? 'video',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Answer'),
          ),
        ],
      ),
    );
  }

  Future<void> loadMessages() async {
    try {
      final data = await ApiService.getDirectMessages(
        widget.userId,
        widget.otherUserId,
      );
      setState(() {
        messages = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTyping() {
    SocketService.emitTyping(widget.otherUserId, true);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      SocketService.emitTyping(widget.otherUserId, false);
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    SocketService.emitTyping(widget.otherUserId, false);

    try {
      final message = await ApiService.sendDirectMessage(
        widget.userId,
        widget.otherUserId,
        messageText,
      );

      SocketService.sendMessage({
        'id': message['id'],
        'senderId': widget.userId,
        'receiverId': widget.otherUserId,
        'content': messageText,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': 0,
      });

      setState(() {
        messages.add(message);
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send File?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${file.name}'),
                const SizedBox(height: 8),
                Text('Size: ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final fileUrl = await ApiService.uploadMedia(
            File(filePath),
            widget.userId,
          );

          final message = await ApiService.sendDirectMessage(
            widget.userId,
            widget.otherUserId,
            '📎 ${file.name}',
            fileUrl: fileUrl,
          );

          SocketService.sendMessage({
            'id': message['id'],
            'senderId': widget.userId,
            'receiverId': widget.otherUserId,
            'content': '📎 ${file.name}',
            'fileUrl': fileUrl,
            'created_at': DateTime.now().toIso8601String(),
            'is_read': 0,
          });

          setState(() {
            messages.add(message);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.otherUserImage != null
                      ? NetworkImage(widget.otherUserImage!)
                      : null,
                  child: widget.otherUserImage == null
                      ? Text(widget.otherUserName[0].toUpperCase())
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    userId: widget.userId,
                    otherUserId: widget.otherUserId,
                    otherUserName: widget.otherUserName,
                    otherUserImage: widget.otherUserImage,
                    isIncoming: false,
                  ),
                ),
              );
            },
            tooltip: 'Video Call',
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    userId: widget.userId,
                    otherUserId: widget.otherUserId,
                    otherUserName: widget.otherUserName,
                    otherUserImage: widget.otherUserImage,
                    isIncoming: false,
                    callType: 'audio',
                  ),
                ),
              );
            },
            tooltip: 'Voice Call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id'].toString() == widget.userId;
                      final showTime = index == 0 ||
                          _shouldShowTime(
                            messages[index - 1]['created_at'],
                            msg['created_at'],
                          );

                      return Column(
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _formatTime(msg['created_at']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          _buildMessageBubble(msg, isMe),
                        ],
                      );
                    },
                  ),
          ),
          if (isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    '${widget.otherUserName} is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickAndSendFile,
                  tooltip: 'Send File',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _onTyping(),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg['content'],
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(msg['created_at']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg['is_read'] == 1 ? Icons.done_all : Icons.done,
                    size: 14,
                    color:
                        msg['is_read'] == 1 ? Colors.blue[200] : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowTime(String prev, String current) {
    final prevTime = DateTime.parse(prev);
    final currentTime = DateTime.parse(current);
    return currentTime.difference(prevTime).inMinutes > 5;
  }

  String _formatTime(String timestamp) {
    final time = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${time.day}/${time.month}/${time.year}';
  }

  String _formatMessageTime(String timestamp) {
    final time = DateTime.parse(timestamp);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

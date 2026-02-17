const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const postsRoutes = require('./routes/posts');
const groupsRoutes = require('./routes/groups');
const eventsRoutes = require('./routes/events');
const commentsRoutes = require('./routes/comments');
const likesRoutes = require('./routes/likes');
const followersRoutes = require('./routes/followers');
const storiesRoutes = require('./routes/stories');
const directMessagesRoutes = require('./routes/directMessages');
const notificationsRoutes = require('./routes/notifications');
const bookmarksRoutes = require('./routes/bookmarks');
const sharesRoutes = require('./routes/shares');
const searchRoutes = require('./routes/search');
const hashtagsRoutes = require('./routes/hashtags');
const profilesRoutes = require('./routes/profiles');
const reactionsRoutes = require('./routes/reactions');
const pollsRoutes = require('./routes/polls');
const marketplaceRoutes = require('./routes/marketplace');
const moderationRoutes = require('./routes/moderation');
const achievementsRoutes = require('./routes/achievements');
const preferencesRoutes = require('./routes/preferences');
const studyGroupsRoutes = require('./routes/studyGroups');
const mediaRoutes = require('./routes/media');
const callsRoutes = require('./routes/calls');
const liveStreamsRoutes = require('./routes/liveStreams');
const verificationRoutes = require('./routes/verification');
const referralsRoutes = require('./routes/referrals');
const analyticsRoutes = require('./routes/analytics');
const pushNotificationsRoutes = require('./routes/pushNotifications');
const aiRoutes = require('./routes/ai');
const emojiReactionsRoutes = require('./routes/emojiReactions');
const mentionsRoutes = require('./routes/mentions');
const hashtagFollowersRoutes = require('./routes/hashtagFollowers');
const contentFiltersRoutes = require('./routes/contentFilters');
const birthdaysRoutes = require('./routes/birthdays');
const statisticsRoutes = require('./routes/statistics');
const anonymousSecretsRoutes = require('./routes/anonymousSecrets');
const liveStreamsEnhancedRoutes = require('./routes/liveStreamsEnhanced');
const callLogsRoutes = require('./routes/callLogs');
const qrCodesRoutes = require('./routes/qrCodes');
const studyProgressRoutes = require('./routes/studyProgress');
const studyResourcesRoutes = require('./routes/studyResources');
const studyReelsRoutes = require('./routes/study_reels');
const usersRoutes = require('./routes/users');
const friendsRoutes = require('./routes/friends');

const locationRoutes = require('./routes/location');
const locationSharingRoutes = require('./routes/locationSharing');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: { origin: '*' }
});

app.set('trust proxy', 1);

// Rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: 'Too many login attempts, please try again later.',
  trustProxy: true,
});

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests, please try again later.',
  trustProxy: true,
});

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  credentials: false
}));

app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/api/', limiter);

// LOCATION TRACKING ROUTES
app.use('/location', locationRoutes);
app.use('/location/sharing', locationSharingRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// API health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'API is running' });
});

// Routes
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/posts', postsRoutes);
app.use('/api/groups', groupsRoutes);
app.use('/api/events', eventsRoutes);
app.use('/api/comments', commentsRoutes);
app.use('/api/likes', likesRoutes);
app.use('/api/followers', followersRoutes);
app.use('/api/stories', storiesRoutes);
app.use('/api/direct-messages', directMessagesRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/bookmarks', bookmarksRoutes);
app.use('/api/shares', sharesRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/hashtags', hashtagsRoutes);
app.use('/api/profiles', profilesRoutes);
app.use('/api/reactions', reactionsRoutes);
app.use('/api/polls', pollsRoutes);
app.use('/api/marketplace', marketplaceRoutes);
app.use('/api/moderation', moderationRoutes);
app.use('/api/achievements', achievementsRoutes);
app.use('/api/preferences', preferencesRoutes);
app.use('/api/study-groups', studyGroupsRoutes);
app.use('/api/study-resources', studyResourcesRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/calls', callsRoutes);
app.use('/api/live-streams', liveStreamsRoutes);
app.use('/api/verification', verificationRoutes);
app.use('/api/referrals', referralsRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/push-notifications', pushNotificationsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/emoji-reactions', emojiReactionsRoutes);
app.use('/api/mentions', mentionsRoutes);
app.use('/api/hashtag-followers', hashtagFollowersRoutes);
app.use('/api/content-filters', contentFiltersRoutes);
app.use('/api/birthdays', birthdaysRoutes);
app.use('/api/statistics', statisticsRoutes);
app.use('/api/anonymous-secrets', anonymousSecretsRoutes);
app.use('/api/live-streams-enhanced', liveStreamsEnhancedRoutes);
app.use('/api/call-logs', callLogsRoutes);
app.use('/api/qr-codes', qrCodesRoutes);
app.use('/api/study-progress', studyProgressRoutes);
app.use('/api/study-reels', studyReelsRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/friends', friendsRoutes);

// Socket.io for real-time features
const onlineUsers = new Map(); // Track online users

io.on('connection', (socket) => {
  console.log('✅ User connected:', socket.id);

  // User comes online
  socket.on('user_online', (data) => {
    const { userId } = data;
    onlineUsers.set(userId, socket.id);
    console.log(`👤 User ${userId} is online`);
    
    // Broadcast online status to all users
    io.emit('user_status', { userId, isOnline: true });
  });

  // Join a group chat room
  socket.on('join_group', (groupId) => {
    socket.join(`group_${groupId}`);
    console.log(`👥 User joined group ${groupId}`);
  });

  // Join a direct message room
  socket.on('join_dm', (userId) => {
    socket.join(`user_${userId}`);
    console.log(`💬 User joined DM room ${userId}`);
  });

  // Send real-time message
  socket.on('send_message', (data) => {
    console.log('📨 New message:', data);
    const receiverSocketId = onlineUsers.get(data.receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('new_message', data);
    }
  });

  // Typing indicator
  socket.on('typing', (data) => {
    const receiverSocketId = onlineUsers.get(data.receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('user_typing', {
        userId: data.senderId || socket.handshake.headers.userid,
        isTyping: data.isTyping,
      });
    }
  });

  // Read receipts
  socket.on('message_read', (data) => {
    const senderSocketId = onlineUsers.get(data.senderId);
    if (senderSocketId) {
      io.to(senderSocketId).emit('message_read', {
        messageId: data.messageId,
        senderId: data.senderId,
      });
    }
  });

  // Send group message
  socket.on('send_group_message', (data) => {
    io.to(`group_${data.groupId}`).emit('receive_message', data);
  });

  // Send notification
  socket.on('send_notification', (data) => {
    const userSocketId = onlineUsers.get(data.userId);
    if (userSocketId) {
      io.to(userSocketId).emit('notification', data);
    }
  });

  // Post reactions
  socket.on('post_reaction', (data) => {
    io.emit('post_reaction', data);
  });

  // Story views
  socket.on('story_view', (data) => {
    const userSocketId = onlineUsers.get(data.storyOwnerId);
    if (userSocketId) {
      io.to(userSocketId).emit('story_viewed', data);
    }
  });

  // Video/Voice call signaling
  socket.on('call_user', (data) => {
    const receiverSocketId = onlineUsers.get(data.to);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('incoming_call', {
        from: data.from,
        callType: data.callType,
        signal: data.signal,
        callId: data.callId,
      });
    }
  });

  socket.on('answer_call', (data) => {
    const callerSocketId = onlineUsers.get(data.to);
    if (callerSocketId) {
      io.to(callerSocketId).emit('call_answered', {
        signal: data.signal,
      });
    }
  });

  socket.on('reject_call', (data) => {
    const callerSocketId = onlineUsers.get(data.to);
    if (callerSocketId) {
      io.to(callerSocketId).emit('call_rejected');
    }
  });

  socket.on('end_call', (data) => {
    const otherUserSocketId = onlineUsers.get(data.to);
    if (otherUserSocketId) {
      io.to(otherUserSocketId).emit('call_ended');
    }
  });

  // WebRTC Signaling for Video Calls
  socket.on('webrtc_offer', (data) => {
    const receiverSocketId = onlineUsers.get(data.to);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('webrtc_offer', {
        from: socket.handshake.headers.userid,
        offer: data.offer,
      });
      console.log(`📞 WebRTC offer sent to user ${data.to}`);
    }
  });

  socket.on('webrtc_answer', (data) => {
    const receiverSocketId = onlineUsers.get(data.to);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('webrtc_answer', {
        from: socket.handshake.headers.userid,
        answer: data.answer,
      });
      console.log(`📞 WebRTC answer sent to user ${data.to}`);
    }
  });

  socket.on('webrtc_ice_candidate', (data) => {
    const receiverSocketId = onlineUsers.get(data.to);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('webrtc_ice_candidate', {
        from: socket.handshake.headers.userid,
        candidate: data.candidate,
      });
      console.log(`📞 WebRTC ICE candidate sent to user ${data.to}`);
    }
  });

  // Group Call Events
  const groupCallRooms = new Map();

  socket.on('create_group_call', (data) => {
    const { roomId, userId, userName, participants } = data;
    groupCallRooms.set(roomId, {
      host: userId,
      participants: [{ userId, userName, socketId: socket.id }],
      createdAt: new Date(),
    });
    socket.join(`group_call_${roomId}`);
    io.emit('group_call_created', { roomId, userId });
    console.log(`👥 Group call created: ${roomId} by ${userName}`);
  });

  socket.on('join_group_call', (data) => {
    const { roomId, userId, userName } = data;
    const room = groupCallRooms.get(roomId);
    if (room) {
      room.participants.push({ userId, userName, socketId: socket.id });
      socket.join(`group_call_${roomId}`);
      socket.to(`group_call_${roomId}`).emit('user_joined_group_call', {
        roomId,
        userId,
        userName,
      });
      console.log(`👥 User ${userName} joined group call ${roomId}`);
    }
  });

  socket.on('leave_group_call', (data) => {
    const { roomId, userId } = data;
    const room = groupCallRooms.get(roomId);
    if (room) {
      room.participants = room.participants.filter(p => p.userId !== userId);
      socket.to(`group_call_${roomId}`).emit('user_left_group_call', {
        roomId,
        userId,
      });
      if (room.participants.length === 0) {
        groupCallRooms.delete(roomId);
        io.emit('group_call_ended', { roomId });
      }
      console.log(`👥 User ${userId} left group call ${roomId}`);
    }
  });

  socket.on('group_call_offer', (data) => {
    const { roomId, to, offer } = data;
    const room = groupCallRooms.get(roomId);
    if (room) {
      const participant = room.participants.find(p => p.userId === to);
      if (participant) {
        io.to(participant.socketId).emit('group_call_offer', {
          roomId,
          from: socket.handshake.headers.userid,
          offer,
        });
      }
    }
  });

  socket.on('group_call_answer', (data) => {
    const { roomId, to, answer } = data;
    const room = groupCallRooms.get(roomId);
    if (room) {
      const participant = room.participants.find(p => p.userId === to);
      if (participant) {
        io.to(participant.socketId).emit('group_call_answer', {
          roomId,
          from: socket.handshake.headers.userid,
          answer,
        });
      }
    }
  });

  socket.on('group_call_ice_candidate', (data) => {
    const { roomId, to, candidate } = data;
    const room = groupCallRooms.get(roomId);
    if (room) {
      const participant = room.participants.find(p => p.userId === to);
      if (participant) {
        io.to(participant.socketId).emit('group_call_ice_candidate', {
          roomId,
          from: socket.handshake.headers.userid,
          candidate,
        });
      }
    }
  });

  // Live streaming events
  socket.on('start_stream', (data) => {
    const { streamId, userId, title } = data;
    socket.join(`stream_${streamId}`);
    console.log(`📹 User ${userId} started stream ${streamId}`);
    
    // Notify followers about new stream
    io.emit('new_stream', { streamId, userId, title });
  });

  socket.on('join_stream', (data) => {
    const { streamId, userId, username } = data;
    socket.join(`stream_${streamId}`);
    console.log(`👁️ User ${userId} joined stream ${streamId}`);
    
    // Notify broadcaster and viewers
    io.to(`stream_${streamId}`).emit('viewer_joined', { userId, username });
  });

  socket.on('leave_stream', (data) => {
    const { streamId, userId, username } = data;
    socket.leave(`stream_${streamId}`);
    console.log(`👋 User ${userId} left stream ${streamId}`);
    
    // Notify broadcaster and viewers
    io.to(`stream_${streamId}`).emit('viewer_left', { userId, username });
  });

  socket.on('stream_comment', (data) => {
    const { streamId, comment } = data;
    console.log(`💬 Comment on stream ${streamId}:`, comment);
    
    // Broadcast comment to all viewers
    io.to(`stream_${streamId}`).emit('new_stream_comment', comment);
  });

  socket.on('stream_gift', (data) => {
    const { streamId, gift } = data;
    console.log(`🎁 Gift sent on stream ${streamId}:`, gift);
    
    // Broadcast gift to all viewers
    io.to(`stream_${streamId}`).emit('new_stream_gift', gift);
  });

  socket.on('end_stream', (data) => {
    const { streamId } = data;
    console.log(`🛑 Stream ${streamId} ended`);
    
    // Notify all viewers
    io.to(`stream_${streamId}`).emit('stream_ended');
  });

  // Helper function to send notification to a user
  function sendNotificationToUser(userId, notification) {
    const socketId = onlineUsers.get(userId.toString());
    if (socketId) {
      io.to(socketId).emit('new_notification', notification);
      console.log(`🔔 Notification sent to user ${userId}`);
    }
  }

  // Request notification (when app opens, get any missed notifications)
  socket.on('get_notifications', async (data) => {
    const { userId } = data;
    try {
      const db = require('./db');
      const result = await db.query(`
        SELECT n.*, u.name as from_user_name, u.profile_image_url as from_user_image
        FROM notifications n
        LEFT JOIN users u ON n.from_user_id = u.id
        WHERE n.user_id = ?
        ORDER BY n.created_at DESC
        LIMIT 20
      `, [userId]);
      
      socket.emit('notifications_list', result.rows);
    } catch (err) {
      console.error('Error getting notifications:', err);
    }
  });

  // User goes offline
  socket.on('disconnect', () => {
    console.log('❌ User disconnected:', socket.id);
    
    // Find and remove user from online users
    for (const [userId, socketId] of onlineUsers.entries()) {
      if (socketId === socket.id) {
        onlineUsers.delete(userId);
        console.log(`👤 User ${userId} went offline`);
        
        // Broadcast offline status
        io.emit('user_status', { userId, isOnline: false });
        break;
      }
    }
  });
});

// Endpoint to check online users
app.get('/api/online-users', (req, res) => {
  const onlineUserIds = Array.from(onlineUsers.keys());
  res.json({ onlineUsers: onlineUserIds, count: onlineUserIds.length });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 STUCHAT Server running on port ${PORT}`);
});

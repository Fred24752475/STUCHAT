const express = require('express');
const router = express.Router();
const db = require('../db');
const jwt = require('jsonwebtoken');

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token' });
    req.user = user;
    next();
  });
};

// Create a new live stream
router.post('/create', authenticateToken, (req, res) => {
  const { title, description, category } = req.body;
  const userId = req.user.userId;
  const streamKey = `stream_${userId}_${Date.now()}`;
  const streamUrl = `rtmp://localhost:1935/live/${streamKey}`; // RTMP URL for streaming
  const createdAt = new Date().toISOString();

  const query = `
    INSERT INTO live_streams (user_id, title, description, category, stream_key, stream_url, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, 'live', ?)
  `;

  db.db.run(query, [userId, title, description, category, streamKey, streamUrl, createdAt], function(err) {
    if (err) {
      console.error('Error creating live stream:', err);
      return res.status(500).json({ error: 'Failed to create live stream' });
    }

    res.json({
      success: true,
      streamId: this.lastID,
      streamKey,
      streamUrl,
      title,
      description,
      category,
      status: 'live',
      message: 'Live stream created successfully'
    });
  });
});

// Get all active live streams
router.get('/active', (req, res) => {
  const query = `
    SELECT 
      ls.*,
      u.name as username,
      u.name as full_name,
      u.profile_image_url as profile_picture,
      COUNT(DISTINCT lsv.id) as viewer_count
    FROM live_streams ls
    JOIN users u ON ls.user_id = u.id
    LEFT JOIN live_stream_viewers lsv ON ls.id = lsv.stream_id AND lsv.left_at IS NULL
    WHERE ls.status = 'live'
    GROUP BY ls.id
    ORDER BY ls.created_at DESC
  `;

  db.db.all(query, [], (err, streams) => {
    if (err) {
      console.error('Error fetching active streams:', err);
      return res.status(500).json({ error: 'Failed to fetch streams' });
    }
    res.json(streams);
  });
});

// Get live stream by ID
router.get('/:streamId', (req, res) => {
  const { streamId } = req.params;

  const query = `
    SELECT 
      ls.*,
      u.name as username,
      u.name as full_name,
      u.profile_image_url as profile_picture,
      COUNT(DISTINCT lsv.id) as viewer_count
    FROM live_streams ls
    JOIN users u ON ls.user_id = u.id
    LEFT JOIN live_stream_viewers lsv ON ls.id = lsv.stream_id AND lsv.left_at IS NULL
    WHERE ls.id = ?
    GROUP BY ls.id
  `;

  db.db.get(query, [streamId], (err, stream) => {
    if (err) {
      console.error('Error fetching stream:', err);
      return res.status(500).json({ error: 'Failed to fetch stream' });
    }
    if (!stream) {
      return res.status(404).json({ error: 'Stream not found' });
    }
    res.json(stream);
  });
});

// End live stream
router.post('/:streamId/end', authenticateToken, (req, res) => {
  const { streamId } = req.params;
  const userId = req.user.userId;
  const endedAt = new Date().toISOString();

  const query = `
    UPDATE live_streams 
    SET status = 'ended', ended_at = ?
    WHERE id = ? AND user_id = ?
  `;

  db.db.run(query, [endedAt, streamId, userId], function(err) {
    if (err) {
      console.error('Error ending stream:', err);
      return res.status(500).json({ error: 'Failed to end stream' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Stream not found or unauthorized' });
    }
    res.json({ message: 'Stream ended successfully' });
  });
});

// Join live stream as viewer
router.post('/:streamId/join', authenticateToken, (req, res) => {
  const { streamId } = req.params;
  const userId = req.user.userId;
  const joinedAt = new Date().toISOString();

  const query = `
    INSERT INTO live_stream_viewers (stream_id, user_id, joined_at)
    VALUES (?, ?, ?)
  `;

  db.db.run(query, [streamId, userId, joinedAt], function(err) {
    if (err) {
      console.error('Error joining stream:', err);
      return res.status(500).json({ error: 'Failed to join stream' });
    }
    res.json({ message: 'Joined stream successfully', viewerId: this.lastID });
  });
});

// Leave live stream
router.post('/:streamId/leave', authenticateToken, (req, res) => {
  const { streamId } = req.params;
  const userId = req.user.userId;
  const leftAt = new Date().toISOString();

  const query = `
    UPDATE live_stream_viewers 
    SET left_at = ?
    WHERE stream_id = ? AND user_id = ? AND left_at IS NULL
  `;

  db.db.run(query, [leftAt, streamId, userId], function(err) {
    if (err) {
      console.error('Error leaving stream:', err);
      return res.status(500).json({ error: 'Failed to leave stream' });
    }
    res.json({ message: 'Left stream successfully' });
  });
});

// Get stream viewers
router.get('/:streamId/viewers', (req, res) => {
  const { streamId } = req.params;

  const query = `
    SELECT 
      u.id,
      u.name as username,
      u.name as full_name,
      u.profile_image_url as profile_picture,
      lsv.joined_at
    FROM live_stream_viewers lsv
    JOIN users u ON lsv.user_id = u.id
    WHERE lsv.stream_id = ? AND lsv.left_at IS NULL
    ORDER BY lsv.joined_at DESC
  `;

  db.db.all(query, [streamId], (err, viewers) => {
    if (err) {
      console.error('Error fetching viewers:', err);
      return res.status(500).json({ error: 'Failed to fetch viewers' });
    }
    res.json(viewers);
  });
});

// Send live stream comment
router.post('/:streamId/comments', authenticateToken, (req, res) => {
  const { streamId } = req.params;
  const { text } = req.body;
  const userId = req.user.userId;
  const createdAt = new Date().toISOString();

  const query = `
    INSERT INTO live_stream_comments (stream_id, user_id, text, created_at)
    VALUES (?, ?, ?, ?)
  `;

  db.db.run(query, [streamId, userId, text, createdAt], function(err) {
    if (err) {
      console.error('Error posting comment:', err);
      return res.status(500).json({ error: 'Failed to post comment' });
    }

    // Get user info for the comment
    db.db.get('SELECT name as username, name as full_name, profile_image_url as profile_picture FROM users WHERE id = ?', [userId], (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Failed to fetch user info' });
      }
      res.json({
        id: this.lastID,
        text,
        userId,
        username: user.username,
        fullName: user.full_name,
        profilePicture: user.profile_picture,
        createdAt
      });
    });
  });
});

// Get live stream comments
router.get('/:streamId/comments', (req, res) => {
  const { streamId } = req.params;
  const limit = parseInt(req.query.limit) || 50;

  const query = `
    SELECT 
      lsc.*,
      u.name as username,
      u.name as full_name,
      u.profile_image_url as profile_picture
    FROM live_stream_comments lsc
    JOIN users u ON lsc.user_id = u.id
    WHERE lsc.stream_id = ?
    ORDER BY lsc.created_at DESC
    LIMIT ?
  `;

  db.db.all(query, [streamId, limit], (err, comments) => {
    if (err) {
      console.error('Error fetching comments:', err);
      return res.status(500).json({ error: 'Failed to fetch comments' });
    }
    res.json(comments.reverse());
  });
});

// Send gift/reaction
router.post('/:streamId/gifts', authenticateToken, (req, res) => {
  const { streamId } = req.params;
  const { giftType, amount } = req.body;
  const userId = req.user.userId;
  const createdAt = new Date().toISOString();

  const query = `
    INSERT INTO live_stream_gifts (stream_id, user_id, gift_type, amount, created_at)
    VALUES (?, ?, ?, ?, ?)
  `;

  db.db.run(query, [streamId, userId, giftType, amount || 1, createdAt], function(err) {
    if (err) {
      console.error('Error sending gift:', err);
      return res.status(500).json({ error: 'Failed to send gift' });
    }

    db.db.get('SELECT name as username, name as full_name, profile_image_url as profile_picture FROM users WHERE id = ?', [userId], (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Failed to fetch user info' });
      }
      res.json({
        id: this.lastID,
        giftType,
        amount: amount || 1,
        userId,
        username: user.username,
        fullName: user.full_name,
        profilePicture: user.profile_picture,
        createdAt
      });
    });
  });
});

// Get user's live streams history
router.get('/user/:userId/history', (req, res) => {
  const { userId } = req.params;

  const query = `
    SELECT 
      ls.*,
      COUNT(DISTINCT lsv.id) as total_viewers,
      COUNT(DISTINCT lsc.id) as total_comments
    FROM live_streams ls
    LEFT JOIN live_stream_viewers lsv ON ls.id = lsv.stream_id
    LEFT JOIN live_stream_comments lsc ON ls.id = lsc.stream_id
    WHERE ls.user_id = ?
    GROUP BY ls.id
    ORDER BY ls.created_at DESC
  `;

  db.db.all(query, [userId], (err, streams) => {
    if (err) {
      console.error('Error fetching stream history:', err);
      return res.status(500).json({ error: 'Failed to fetch stream history' });
    }
    res.json(streams);
  });
});

module.exports = router;

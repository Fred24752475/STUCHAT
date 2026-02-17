const express = require('express');
const router = express.Router();
const db = require('../db');

// Create live stream
router.post('/', async (req, res) => {
  try {
    const { broadcasterId, title, description, category, thumbnailUrl, streamUrl } = req.body;

    if (!broadcasterId || !title) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO live_streams_enhanced (broadcaster_id, title, description, category, thumbnail_url, stream_url, status) 
       VALUES (?, ?, ?, ?, ?, ?, 'active')`,
      [broadcasterId, title, description || null, category || null, thumbnailUrl || null, streamUrl || null]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error creating live stream:', error);
    res.status(500).json({ error: 'Failed to create live stream' });
  }
});

// Get active live streams
router.get('/active', async (req, res) => {
  try {
    const limit = req.query.limit || 50;

    const result = await db.query(
      `SELECT lse.*, u.name, u.profile_image_url FROM live_streams_enhanced lse
       JOIN users u ON lse.broadcaster_id = u.id
       WHERE lse.status = 'active'
       ORDER BY lse.viewer_count DESC LIMIT ?`,
      [limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching active streams:', error);
    res.status(500).json({ error: 'Failed to fetch active streams' });
  }
});

// Get live stream details
router.get('/:streamId', async (req, res) => {
  try {
    const { streamId } = req.params;

    const result = await db.query(
      `SELECT lse.*, u.name, u.profile_image_url FROM live_streams_enhanced lse
       JOIN users u ON lse.broadcaster_id = u.id
       WHERE lse.id = ?`,
      [streamId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Stream not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching stream:', error);
    res.status(500).json({ error: 'Failed to fetch stream' });
  }
});

// Join live stream
router.post('/:streamId/join', async (req, res) => {
  try {
    const { streamId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    await db.query(
      `INSERT INTO live_stream_viewers (stream_id, user_id) VALUES (?, ?)`,
      [streamId, userId]
    );

    // Update viewer count
    await db.query(
      `UPDATE live_streams_enhanced SET viewer_count = viewer_count + 1 WHERE id = ?`,
      [streamId]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error joining stream:', error);
    res.status(500).json({ error: 'Failed to join stream' });
  }
});

// Leave live stream
router.post('/:streamId/leave', async (req, res) => {
  try {
    const { streamId } = req.params;
    const { userId, watchDuration = 0 } = req.body;

    await db.query(
      `UPDATE live_stream_viewers SET left_at = CURRENT_TIMESTAMP, watch_duration = ? 
       WHERE stream_id = ? AND user_id = ?`,
      [watchDuration, streamId, userId]
    );

    // Update viewer count
    await db.query(
      `UPDATE live_streams_enhanced SET viewer_count = viewer_count - 1 WHERE id = ? AND viewer_count > 0`,
      [streamId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error leaving stream:', error);
    res.status(500).json({ error: 'Failed to leave stream' });
  }
});

// Send comment on live stream
router.post('/:streamId/comments', async (req, res) => {
  try {
    const { streamId } = req.params;
    const { userId, content } = req.body;

    if (!userId || !content) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO live_stream_comments (stream_id, user_id, content) VALUES (?, ?, ?)`,
      [streamId, userId, content]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error sending comment:', error);
    res.status(500).json({ error: 'Failed to send comment' });
  }
});

// Get live stream comments
router.get('/:streamId/comments', async (req, res) => {
  try {
    const { streamId } = req.params;
    const limit = req.query.limit || 50;

    const result = await db.query(
      `SELECT lsc.*, u.name, u.profile_image_url FROM live_stream_comments lsc
       JOIN users u ON lsc.user_id = u.id
       WHERE lsc.stream_id = ?
       ORDER BY lsc.created_at DESC LIMIT ?`,
      [streamId, limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
});

// Send gift on live stream
router.post('/:streamId/gifts', async (req, res) => {
  try {
    const { streamId } = req.params;
    const { senderId, giftType, amount = 1, value = 0 } = req.body;

    if (!senderId || !giftType) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO live_stream_gifts (stream_id, sender_id, gift_type, amount, value) 
       VALUES (?, ?, ?, ?, ?)`,
      [streamId, senderId, giftType, amount, value]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error sending gift:', error);
    res.status(500).json({ error: 'Failed to send gift' });
  }
});

// Get live stream gifts
router.get('/:streamId/gifts', async (req, res) => {
  try {
    const { streamId } = req.params;

    const result = await db.query(
      `SELECT lsg.*, u.name FROM live_stream_gifts lsg
       JOIN users u ON lsg.sender_id = u.id
       WHERE lsg.stream_id = ?
       ORDER BY lsg.created_at DESC`,
      [streamId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching gifts:', error);
    res.status(500).json({ error: 'Failed to fetch gifts' });
  }
});

// Like live stream
router.post('/:streamId/like', async (req, res) => {
  try {
    const { streamId } = req.params;

    await db.query(
      `UPDATE live_streams_enhanced SET likes = likes + 1 WHERE id = ?`,
      [streamId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error liking stream:', error);
    res.status(500).json({ error: 'Failed to like stream' });
  }
});

// End live stream
router.post('/:streamId/end', async (req, res) => {
  try {
    const { streamId } = req.params;
    const { recordingUrl, isRecorded = false } = req.body;

    const duration = await db.query(
      `SELECT CAST((julianday('now') - julianday(start_time)) * 24 * 60 AS INTEGER) as duration 
       FROM live_streams_enhanced WHERE id = ?`,
      [streamId]
    );

    await db.query(
      `UPDATE live_streams_enhanced SET status = 'ended', end_time = CURRENT_TIMESTAMP, 
       duration = ?, is_recorded = ?, recording_url = ? WHERE id = ?`,
      [duration.rows[0]?.duration || 0, isRecorded ? 1 : 0, recordingUrl || null, streamId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error ending stream:', error);
    res.status(500).json({ error: 'Failed to end stream' });
  }
});

// Get live stream viewers
router.get('/:streamId/viewers', async (req, res) => {
  try {
    const { streamId } = req.params;

    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url, lsv.watch_duration FROM live_stream_viewers lsv
       JOIN users u ON lsv.user_id = u.id
       WHERE lsv.stream_id = ? AND lsv.left_at IS NULL`,
      [streamId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching viewers:', error);
    res.status(500).json({ error: 'Failed to fetch viewers' });
  }
});

// Get user's live stream history
router.get('/user/:userId/history', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = req.query.limit || 20;

    const result = await db.query(
      `SELECT * FROM live_streams_enhanced 
       WHERE broadcaster_id = ? 
       ORDER BY created_at DESC LIMIT ?`,
      [userId, limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching stream history:', error);
    res.status(500).json({ error: 'Failed to fetch stream history' });
  }
});

module.exports = router;

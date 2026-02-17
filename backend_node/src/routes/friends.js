const express = require('express');
const router = express.Router();
const db = require('../db');

// Helper to create notification
async function createNotification(userId, type, title, message, fromUserId, referenceId) {
  await db.query(
    `INSERT INTO notifications (user_id, type, title, message, from_user_id, reference_id) 
     VALUES (?, ?, ?, ?, ?, ?)`,
    [userId, type, title, message, fromUserId, referenceId]
  );
}

// Get friend requests (received)
router.get('/requests/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(`
      SELECT fr.id, fr.sender_id, fr.receiver_id, fr.status, fr.created_at,
             u.name, u.email, u.profile_image_url, u.course, u.year
      FROM friend_requests fr
      JOIN users u ON fr.sender_id = u.id
      WHERE fr.receiver_id = ? AND fr.status = 'pending'
      ORDER BY fr.created_at DESC
    `, [userId]);
    
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get sent friend requests
router.get('/sent/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(`
      SELECT fr.id, fr.sender_id, fr.receiver_id, fr.status, fr.created_at,
             u.name, u.email, u.profile_image_url, u.course, u.year
      FROM friend_requests fr
      JOIN users u ON fr.receiver_id = u.id
      WHERE fr.sender_id = ? AND fr.status = 'pending'
      ORDER BY fr.created_at DESC
    `, [userId]);
    
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Send friend request
router.post('/request', async (req, res) => {
  try {
    const { senderId, receiverId } = req.body;
    
    // Get sender info
    const sender = await db.query('SELECT name FROM users WHERE id = ?', [senderId]);
    
    // Check if already friends
    const friends = await db.query(
      'SELECT * FROM followers WHERE follower_id = ? AND following_id = ?',
      [senderId, receiverId]
    );
    
    if (friends.rows.length > 0) {
      return res.status(400).json({ error: 'You are already friends' });
    }
    
    // Check if request already exists
    const existing = await db.query(
      'SELECT id FROM friend_requests WHERE sender_id = ? AND receiver_id = ?',
      [senderId, receiverId]
    );
    
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Friend request already exists' });
    }
    
    // Create friend request
    const result = await db.query(
      'INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, ?)',
      [senderId, receiverId, 'pending']
    );
    
    // Create notification for receiver
    const senderName = sender.rows[0]?.name || 'Someone';
    await createNotification(
      receiverId,
      'friend_request',
      'New Friend Request',
      `${senderName} sent you a friend request`,
      senderId,
      result.lastId
    );
    
    res.status(201).json({ success: true, message: 'Friend request sent', requestId: result.lastId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Accept friend request
router.post('/accept', async (req, res) => {
  try {
    const { requestId, userId, requesterId } = req.body;
    
    const request = await db.query('SELECT * FROM friend_requests WHERE id = ?', [requestId]);
    
    if (request.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }
    
    const { sender_id, receiver_id } = request.rows[0];
    
    // Update request status
    await db.query('UPDATE friend_requests SET status = ? WHERE id = ?', ['accepted', requestId]);
    
    // Add to followers (both ways for friends)
    await db.query('INSERT OR IGNORE INTO followers (follower_id, following_id) VALUES (?, ?)', [receiver_id, sender_id]);
    await db.query('INSERT OR IGNORE INTO followers (follower_id, following_id) VALUES (?, ?)', [sender_id, receiver_id]);
    
    // Get user info
    const user = await db.query('SELECT name FROM users WHERE id = ?', [userId]);
    const userName = user.rows[0]?.name || 'Someone';
    
    // Create notification for request sender
    await createNotification(
      sender_id,
      'friend_accepted',
      'Friend Request Accepted',
      `${userName} accepted your friend request`,
      userId,
      requestId
    );
    
    // Delete the notification
    await db.query('DELETE FROM notifications WHERE reference_id = ? AND type = ?', [requestId, 'friend_request']);
    
    res.json({ success: true, message: 'Friend request accepted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Reject friend request
router.delete('/reject/:requestId', async (req, res) => {
  try {
    const { requestId } = req.params;
    const { body } = req;
    const userId = body.userId || body.requesterId;
    
    // Get request info first
    const request = await db.query('SELECT * FROM friend_requests WHERE id = ?', [requestId]);
    
    if (request.rows.length > 0) {
      const { sender_id } = request.rows[0];
      
      // Get user info
      const user = await db.query('SELECT name FROM users WHERE id = ?', [userId]);
      const userName = user.rows[0]?.name || 'Someone';
      
      // Create notification for request sender
      await createNotification(
        sender_id,
        'friend_rejected',
        'Friend Request Declined',
        `${userName} declined your friend request`,
        userId,
        requestId
      );
    }
    
    // Delete the friend request
    await db.query('DELETE FROM friend_requests WHERE id = ?', [requestId]);
    
    // Delete related notifications
    await db.query('DELETE FROM notifications WHERE reference_id = ?', [requestId]);
    
    res.json({ success: true, message: 'Friend request rejected' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get friends list
router.get('/list/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(`
      SELECT u.id, u.name, u.email, u.profile_image_url, u.course, u.year
      FROM followers f
      JOIN users u ON f.following_id = u.id
      WHERE f.follower_id = ?
    `, [userId]);
    
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

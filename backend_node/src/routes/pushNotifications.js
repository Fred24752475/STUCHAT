const express = require('express');
const router = express.Router();
const db = require('../db');

// Register device token
router.post('/register-token', async (req, res) => {
  const { userId, token, deviceType } = req.body;
  
  try {
    await db.query(
      'INSERT OR REPLACE INTO push_tokens (user_id, token, device_type) VALUES ($1, $2, $3)',
      [userId, token, deviceType]
    );
    
    res.json({ message: 'Token registered successfully' });
  } catch (err) {
    console.error('Register token error:', err);
    res.status(500).json({ error: 'Failed to register token' });
  }
});

// Remove device token
router.delete('/remove-token', async (req, res) => {
  const { userId, token } = req.body;
  
  try {
    await db.query(
      'DELETE FROM push_tokens WHERE user_id = $1 AND token = $2',
      [userId, token]
    );
    
    res.json({ message: 'Token removed successfully' });
  } catch (err) {
    console.error('Remove token error:', err);
    res.status(500).json({ error: 'Failed to remove token' });
  }
});

// Get user's tokens
router.get('/tokens/:userId', async (req, res) => {
  const { userId } = req.params;
  
  try {
    const result = await db.query(
      'SELECT token, device_type, created_at FROM push_tokens WHERE user_id = $1',
      [userId]
    );
    
    res.json(result.rows);
  } catch (err) {
    console.error('Get tokens error:', err);
    res.status(500).json({ error: 'Failed to get tokens' });
  }
});

// Send notification (helper function - would integrate with FCM/APNS in production)
async function sendPushNotification(userId, title, body, data = {}) {
  try {
    const tokens = await db.query(
      'SELECT token, device_type FROM push_tokens WHERE user_id = $1',
      [userId]
    );
    
    if (tokens.rows.length === 0) {
      console.log(`No tokens found for user ${userId}`);
      return false;
    }
    
    // In production, integrate with Firebase Cloud Messaging or Apple Push Notification Service
    console.log(`📱 Would send push notification to user ${userId}:`, {
      title,
      body,
      tokens: tokens.rows.length,
      data
    });
    
    // TODO: Implement actual push notification sending
    // Example with FCM:
    // const admin = require('firebase-admin');
    // const message = {
    //   notification: { title, body },
    //   data,
    //   tokens: tokens.rows.map(t => t.token)
    // };
    // await admin.messaging().sendMulticast(message);
    
    return true;
  } catch (err) {
    console.error('Send push notification error:', err);
    return false;
  }
}

// Trigger notification on like
router.post('/notify-like', async (req, res) => {
  const { postId, likerId } = req.body;
  
  try {
    // Get post owner
    const post = await db.query('SELECT user_id FROM posts WHERE id = $1', [postId]);
    if (post.rows.length === 0) {
      return res.status(404).json({ error: 'Post not found' });
    }
    
    const postOwnerId = post.rows[0].user_id;
    
    // Don't notify if user liked their own post
    if (postOwnerId === parseInt(likerId)) {
      return res.json({ message: 'No notification needed' });
    }
    
    // Get liker's name
    const liker = await db.query('SELECT name FROM users WHERE id = $1', [likerId]);
    
    await sendPushNotification(
      postOwnerId,
      'New Like',
      `${liker.rows[0].name} liked your post`,
      { type: 'like', postId, likerId }
    );
    
    res.json({ message: 'Notification sent' });
  } catch (err) {
    console.error('Notify like error:', err);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

// Trigger notification on comment
router.post('/notify-comment', async (req, res) => {
  const { postId, commenterId } = req.body;
  
  try {
    const post = await db.query('SELECT user_id FROM posts WHERE id = $1', [postId]);
    if (post.rows.length === 0) {
      return res.status(404).json({ error: 'Post not found' });
    }
    
    const postOwnerId = post.rows[0].user_id;
    
    if (postOwnerId === parseInt(commenterId)) {
      return res.json({ message: 'No notification needed' });
    }
    
    const commenter = await db.query('SELECT name FROM users WHERE id = $1', [commenterId]);
    
    await sendPushNotification(
      postOwnerId,
      'New Comment',
      `${commenter.rows[0].name} commented on your post`,
      { type: 'comment', postId, commenterId }
    );
    
    res.json({ message: 'Notification sent' });
  } catch (err) {
    console.error('Notify comment error:', err);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

// Trigger notification on follow
router.post('/notify-follow', async (req, res) => {
  const { followerId, followingId } = req.body;
  
  try {
    const follower = await db.query('SELECT name FROM users WHERE id = $1', [followerId]);
    
    await sendPushNotification(
      followingId,
      'New Follower',
      `${follower.rows[0].name} started following you`,
      { type: 'follow', followerId }
    );
    
    res.json({ message: 'Notification sent' });
  } catch (err) {
    console.error('Notify follow error:', err);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

module.exports = router;
module.exports.sendPushNotification = sendPushNotification;

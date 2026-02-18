const express = require('express');
const router = express.Router();
const db = require('../db');

// Mention a user in post/comment
router.post('/', async (req, res) => {
  try {
    const { mentionedUserId, mentioningUserId, postId, commentId } = req.body;

    if (!mentionedUserId || !mentioningUserId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    if (!postId && !commentId) {
      return res.status(400).json({ error: 'Either postId or commentId is required' });
    }

    await db.query(
      `INSERT INTO user_mentions (mentioned_user_id, mentioning_user_id, post_id, comment_id) 
       VALUES ($1, $2, $3, $4)`,
      [mentionedUserId, mentioningUserId, postId || null, commentId || null]
    );

    const mentioningUser = await db.query('SELECT name FROM users WHERE id = $1', [mentioningUserId]);
    const title = 'Mention';
    const message = `${mentioningUser.rows[0]?.name || 'Someone'} mentioned you in a post`;
    await db.query(
      `INSERT INTO notifications (user_id, type, title, message, from_user_id, reference_id) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [mentionedUserId, 'mention', title, message, mentioningUserId, postId || commentId]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error creating mention:', error);
    res.status(500).json({ error: 'Failed to create mention' });
  }
});

// Get mentions for user
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT um.*, u.name, u.profile_image_url FROM user_mentions um
       JOIN users u ON um.mentioning_user_id = u.id
       WHERE um.mentioned_user_id = $1 ORDER BY um.created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching mentions:', error);
    res.status(500).json({ error: 'Failed to fetch mentions' });
  }
});

// Get users mentioned in post
router.get('/post/:postId', async (req, res) => {
  try {
    const { postId } = req.params;

    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url FROM user_mentions um
       JOIN users u ON um.mentioned_user_id = u.id
       WHERE um.post_id = $1`,
      [postId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching mentioned users:', error);
    res.status(500).json({ error: 'Failed to fetch mentioned users' });
  }
});

module.exports = router;

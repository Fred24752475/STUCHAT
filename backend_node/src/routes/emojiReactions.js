const express = require('express');
const router = express.Router();
const db = require('../db');

// Add emoji reaction to post or comment
router.post('/', async (req, res) => {
  try {
    const { postId, commentId, userId, emoji } = req.body;

    if (!userId || !emoji) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    if (!postId && !commentId) {
      return res.status(400).json({ error: 'Either postId or commentId is required' });
    }

    const result = await db.query(
      `INSERT INTO emoji_reactions (post_id, comment_id, user_id, emoji) 
       VALUES (?, ?, ?, ?)`,
      [postId || null, commentId || null, userId, emoji]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error adding emoji reaction:', error);
    res.status(500).json({ error: 'Failed to add emoji reaction' });
  }
});

// Remove emoji reaction
router.delete('/:reactionId', async (req, res) => {
  try {
    const { reactionId } = req.params;

    await db.query('DELETE FROM emoji_reactions WHERE id = ?', [reactionId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Error removing emoji reaction:', error);
    res.status(500).json({ error: 'Failed to remove emoji reaction' });
  }
});

// Get emoji reactions for post
router.get('/post/:postId', async (req, res) => {
  try {
    const { postId } = req.params;

    const result = await db.query(
      `SELECT emoji, COUNT(*) as count FROM emoji_reactions 
       WHERE post_id = ? GROUP BY emoji`,
      [postId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching emoji reactions:', error);
    res.status(500).json({ error: 'Failed to fetch emoji reactions' });
  }
});

// Get emoji reactions for comment
router.get('/comment/:commentId', async (req, res) => {
  try {
    const { commentId } = req.params;

    const result = await db.query(
      `SELECT emoji, COUNT(*) as count FROM emoji_reactions 
       WHERE comment_id = ? GROUP BY emoji`,
      [commentId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching emoji reactions:', error);
    res.status(500).json({ error: 'Failed to fetch emoji reactions' });
  }
});

// Get users who reacted with specific emoji
router.get('/post/:postId/emoji/:emoji', async (req, res) => {
  try {
    const { postId, emoji } = req.params;

    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url FROM emoji_reactions er
       JOIN users u ON er.user_id = u.id
       WHERE er.post_id = ? AND er.emoji = ?`,
      [postId, emoji]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

module.exports = router;

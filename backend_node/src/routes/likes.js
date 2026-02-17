const express = require('express');
const router = express.Router();
const db = require('../db');

// Toggle like on a post
router.post('/post/:postId', async (req, res) => {
  const { postId } = req.params;
  const { userId } = req.body;
  
  try {
    // Check if already liked
    const existing = await db.query(
      'SELECT * FROM likes WHERE post_id = $1 AND user_id = $2',
      [postId, userId]
    );
    
    if (existing.rows.length > 0) {
      // Unlike
      await db.query('DELETE FROM likes WHERE post_id = $1 AND user_id = $2', [postId, userId]);
      await db.query('UPDATE posts SET likes = likes - 1 WHERE id = $1', [postId]);
      res.json({ liked: false });
    } else {
      // Like
      await db.query(
        'INSERT INTO likes (post_id, user_id) VALUES ($1, $2)',
        [postId, userId]
      );
      await db.query('UPDATE posts SET likes = likes + 1 WHERE id = $1', [postId]);
      res.json({ liked: true });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get users who liked a post
router.get('/post/:postId/users', async (req, res) => {
  const { postId } = req.params;
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, l.created_at
      FROM likes l
      JOIN users u ON l.user_id = u.id
      WHERE l.post_id = $1
      ORDER BY l.created_at DESC
    `, [postId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Check if user liked a post
router.get('/post/:postId/user/:userId', async (req, res) => {
  const { postId, userId } = req.params;
  try {
    const result = await db.query(
      'SELECT * FROM likes WHERE post_id = $1 AND user_id = $2',
      [postId, userId]
    );
    res.json({ liked: result.rows.length > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

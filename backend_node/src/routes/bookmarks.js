const express = require('express');
const router = express.Router();
const db = require('../db');

// Get bookmarked posts for a user
router.get('/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT p.*, u.name as user_name, u.profile_image_url, b.created_at as bookmarked_at
      FROM bookmarks b
      JOIN posts p ON b.post_id = p.id
      JOIN users u ON p.user_id = u.id
      WHERE b.user_id = $1
      ORDER BY b.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Toggle bookmark
router.post('/toggle', async (req, res) => {
  const { userId, postId } = req.body;
  try {
    const existing = await db.query(
      'SELECT * FROM bookmarks WHERE user_id = $1 AND post_id = $2',
      [userId, postId]
    );
    
    if (existing.rows.length > 0) {
      // Remove bookmark
      await db.query('DELETE FROM bookmarks WHERE user_id = $1 AND post_id = $2', [userId, postId]);
      res.json({ bookmarked: false });
    } else {
      // Add bookmark
      await db.query(
        'INSERT INTO bookmarks (user_id, post_id) VALUES ($1, $2)',
        [userId, postId]
      );
      res.json({ bookmarked: true });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Check if post is bookmarked
router.get('/check/:userId/:postId', async (req, res) => {
  const { userId, postId } = req.params;
  try {
    const result = await db.query(
      'SELECT * FROM bookmarks WHERE user_id = $1 AND post_id = $2',
      [userId, postId]
    );
    res.json({ bookmarked: result.rows.length > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

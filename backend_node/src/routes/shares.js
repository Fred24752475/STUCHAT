const express = require('express');
const router = express.Router();
const db = require('../db');

// Share/repost a post
router.post('/', async (req, res) => {
  const { originalPostId, userId, caption } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO post_shares (original_post_id, user_id, caption) VALUES ($1, $2, $3) RETURNING *',
      [originalPostId, userId, caption]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get shares of a post
router.get('/post/:postId', async (req, res) => {
  const { postId } = req.params;
  try {
    const result = await db.query(`
      SELECT s.*, u.name as user_name, u.profile_image_url
      FROM post_shares s
      JOIN users u ON s.user_id = u.id
      WHERE s.original_post_id = $1
      ORDER BY s.created_at DESC
    `, [postId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get shares by a user
router.get('/user/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT s.*, p.*, u.name as original_user_name
      FROM post_shares s
      JOIN posts p ON s.original_post_id = p.id
      JOIN users u ON p.user_id = u.id
      WHERE s.user_id = $1
      ORDER BY s.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete share
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM post_shares WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

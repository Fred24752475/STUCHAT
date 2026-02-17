const express = require('express');
const router = express.Router();
const db = require('../db');

// Get comments for a post
router.get('/post/:postId', async (req, res) => {
  const { postId } = req.params;
  try {
    const result = await db.query(`
      SELECT c.*, u.name as user_name, u.profile_image_url
      FROM comments c
      JOIN users u ON c.user_id = u.id
      WHERE c.post_id = $1
      ORDER BY c.created_at DESC
    `, [postId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create comment
router.post('/', async (req, res) => {
  const { postId, userId, content } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO comments (post_id, user_id, content) VALUES ($1, $2, $3) RETURNING *',
      [postId, userId, content]
    );
    
    // Update comment count on post
    await db.query('UPDATE posts SET comments = comments + 1 WHERE id = $1', [postId]);
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete comment
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const comment = await db.query('SELECT post_id FROM comments WHERE id = $1', [id]);
    await db.query('DELETE FROM comments WHERE id = $1', [id]);
    
    if (comment.rows.length > 0) {
      await db.query('UPDATE posts SET comments = comments - 1 WHERE id = $1', [comment.rows[0].post_id]);
    }
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

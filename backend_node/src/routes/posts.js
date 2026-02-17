const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all posts
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT p.*, u.name as user_name 
      FROM posts p 
      JOIN users u ON p.user_id = u.id 
      ORDER BY p.created_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create post
router.post('/', async (req, res) => {
  const { userId, content, imageUrl, videoUrl } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO posts (user_id, content, image_url, video_url) VALUES ($1, $2, $3, $4) RETURNING *',
      [userId, content, imageUrl, videoUrl]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Like post
router.post('/:id/like', async (req, res) => {
  const { id } = req.params;
  const { userId } = req.body;
  
  try {
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Check if already liked
    const existingLike = await db.query(
      `SELECT id FROM likes WHERE post_id = ? AND user_id = ?`,
      [id, userId]
    );

    if (existingLike.length > 0) {
      return res.status(200).json({ alreadyLiked: true, message: 'Already liked' });
    }

    await db.query(
      `INSERT INTO likes (post_id, user_id) VALUES (?, ?)`,
      [id, userId]
    );

    // Update like count
    await db.query(
      `UPDATE posts SET likes = likes + 1 WHERE id = ?`,
      [id]
    );

    res.status(201).json({ success: true });
  } catch (err) {
    console.error('Error liking post:', err);
    res.status(500).json({ error: err.message });
  }
});

// Unlike post
router.delete('/:id/like', async (req, res) => {
  const { id } = req.params;
  const { userId } = req.body;
  
  try {
    await db.query(
      `DELETE FROM likes WHERE post_id = ? AND user_id = ?`,
      [id, userId]
    );

    // Update like count
    await db.query(
      `UPDATE posts SET likes = likes - 1 WHERE id = ? AND likes > 0`,
      [id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error unliking post:', err);
    res.status(500).json({ error: err.message });
  }
});

// Comment on post
router.post('/:id/comments', async (req, res) => {
  const { id } = req.params;
  const { userId, content } = req.body;
  
  try {
    if (!userId || !content) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO comments (post_id, user_id, content) VALUES (?, ?, ?)`,
      [id, userId, content]
    );

    // Update comment count
    await db.query(
      `UPDATE posts SET comments = comments + 1 WHERE id = ?`,
      [id]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (err) {
    console.error('Error commenting on post:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get comments on post
router.get('/:id/comments', async (req, res) => {
  const { id } = req.params;
  
  try {
    const result = await db.query(
      `SELECT c.*, u.name as user_name FROM comments c 
       JOIN users u ON c.user_id = u.id 
       WHERE c.post_id = ? ORDER BY c.created_at DESC`,
      [id]
    );

    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching comments:', err);
    res.status(500).json({ error: err.message });
  }
});

// Delete comment on post
router.delete('/:id/comments/:commentId', async (req, res) => {
  const { id, commentId } = req.params;
  const { userId } = req.body;
  
  try {
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Check if user owns comment
    const comment = await db.query(
      `SELECT user_id FROM comments WHERE id = ? AND post_id = ?`,
      [commentId, id]
    );

    if (comment.length === 0) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    if (comment[0].user_id !== parseInt(userId)) {
      return res.status(403).json({ error: 'Not authorized to delete this comment' });
    }

    await db.query(
      `DELETE FROM comments WHERE id = ? AND post_id = ?`,
      [commentId, id]
    );

    // Update comment count
    await db.query(
      `UPDATE posts SET comments = comments - 1 WHERE id = ? AND comments > 0`,
      [id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting comment:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

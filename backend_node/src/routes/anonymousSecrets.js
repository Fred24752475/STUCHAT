const express = require('express');
const router = express.Router();
const db = require('../db');

// Create anonymous secret
router.post('/', async (req, res) => {
  try {
    const { userId, content, imageUrl, expiresAt } = req.body;

    if (!userId || !content) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO anonymous_secrets (user_id, content, image_url, expires_at) 
       VALUES (?, ?, ?, ?)`,
      [userId, content, imageUrl || null, expiresAt || null]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error creating anonymous secret:', error);
    res.status(500).json({ error: 'Failed to create anonymous secret' });
  }
});

// Get all anonymous secrets (feed)
router.get('/feed', async (req, res) => {
  try {
    const limit = req.query.limit || 20;
    const offset = req.query.offset || 0;

    const result = await db.query(
      `SELECT id, content, image_url, likes, comments, created_at 
       FROM anonymous_secrets 
       WHERE (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
       ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching anonymous secrets:', error);
    res.status(500).json({ error: 'Failed to fetch anonymous secrets' });
  }
});

// Get trending anonymous secrets
router.get('/trending', async (req, res) => {
  try {
    const limit = req.query.limit || 20;

    const result = await db.query(
      `SELECT id, content, image_url, likes, comments, created_at 
       FROM anonymous_secrets 
       WHERE (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
       ORDER BY (likes + comments) DESC LIMIT ?`,
      [limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching trending secrets:', error);
    res.status(500).json({ error: 'Failed to fetch trending secrets' });
  }
});

// Get single anonymous secret
router.get('/:secretId', async (req, res) => {
  try {
    const { secretId } = req.params;

    const result = await db.query(
      `SELECT id, content, image_url, likes, comments, created_at 
       FROM anonymous_secrets WHERE id = ?`,
      [secretId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Secret not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching anonymous secret:', error);
    res.status(500).json({ error: 'Failed to fetch anonymous secret' });
  }
});

// Like anonymous secret
router.post('/:secretId/like', async (req, res) => {
  try {
    const { secretId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Check if already liked
    const existingLike = await db.query(
      `SELECT id FROM anonymous_secret_likes WHERE secret_id = ? AND user_id = ?`,
      [secretId, userId]
    );

    if (existingLike.length > 0) {
      return res.status(200).json({ alreadyLiked: true, message: 'Already liked' });
    }

    await db.query(
      `INSERT INTO anonymous_secret_likes (secret_id, user_id) VALUES (?, ?)`,
      [secretId, userId]
    );

    // Update like count
    await db.query(
      `UPDATE anonymous_secrets SET likes = likes + 1 WHERE id = ?`,
      [secretId]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error liking secret:', error);
    res.status(500).json({ error: 'Failed to like secret' });
  }
});

// Unlike anonymous secret
router.delete('/:secretId/like', async (req, res) => {
  try {
    const { secretId } = req.params;
    const { userId } = req.body;

    await db.query(
      `DELETE FROM anonymous_secret_likes WHERE secret_id = ? AND user_id = ?`,
      [secretId, userId]
    );

    // Update like count
    await db.query(
      `UPDATE anonymous_secrets SET likes = likes - 1 WHERE id = ? AND likes > 0`,
      [secretId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error unliking secret:', error);
    res.status(500).json({ error: 'Failed to unlike secret' });
  }
});

// Comment on anonymous secret
router.post('/:secretId/comments', async (req, res) => {
  try {
    const { secretId } = req.params;
    const { userId, content, isAnonymous = true } = req.body;

    if (!userId || !content) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO anonymous_secret_comments (secret_id, user_id, content, is_anonymous) 
       VALUES (?, ?, ?, ?)`,
      [secretId, userId, content, isAnonymous ? 1 : 0]
    );

    // Update comment count
    await db.query(
      `UPDATE anonymous_secrets SET comments = comments + 1 WHERE id = ?`,
      [secretId]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error commenting on secret:', error);
    res.status(500).json({ error: 'Failed to comment on secret' });
  }
});

// Get comments on anonymous secret
router.get('/:secretId/comments', async (req, res) => {
  try {
    const { secretId } = req.params;

    const result = await db.query(
      `SELECT id, content, is_anonymous, created_at FROM anonymous_secret_comments 
       WHERE secret_id = ? ORDER BY created_at DESC`,
      [secretId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
});

// Delete comment on anonymous secret
router.delete('/:secretId/comments/:commentId', async (req, res) => {
  try {
    const { secretId, commentId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Check if user owns the comment
    const comment = await db.query(
      `SELECT user_id FROM anonymous_secret_comments WHERE id = ? AND secret_id = ?`,
      [commentId, secretId]
    );

    if (comment.length === 0) {
      return res.status(404).json({ error: 'Comment not found' });
    }

    if (comment[0].user_id !== parseInt(userId)) {
      return res.status(403).json({ error: 'Not authorized to delete this comment' });
    }

    await db.query(
      `DELETE FROM anonymous_secret_comments WHERE id = ? AND secret_id = ?`,
      [commentId, secretId]
    );

    // Update comment count
    await db.query(
      `UPDATE anonymous_secrets SET comments = comments - 1 WHERE id = ? AND comments > 0`,
      [secretId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting comment:', error);
    res.status(500).json({ error: 'Failed to delete comment' });
  }
});

// Delete anonymous secret
router.delete('/:secretId', async (req, res) => {
  try {
    const { secretId } = req.params;
    const { userId } = req.body;

    // Verify ownership
    const secret = await db.query(
      `SELECT user_id FROM anonymous_secrets WHERE id = ?`,
      [secretId]
    );

    if (secret.rows[0]?.user_id !== userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    await db.query('DELETE FROM anonymous_secrets WHERE id = ?', [secretId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting secret:', error);
    res.status(500).json({ error: 'Failed to delete secret' });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const db = require('../db');

// Toggle reaction on a post
router.post('/post/:postId', async (req, res) => {
  const { postId } = req.params;
  const { userId, reactionType } = req.body; // 'like', 'love', 'laugh', 'wow', 'sad', 'angry'
  
  try {
    // Check if already reacted
    const existing = await db.query(
      'SELECT * FROM reactions WHERE post_id = ? AND user_id = ?',
      [postId, userId]
    );
    
    if (existing.rows.length > 0) {
      if (existing.rows[0].reaction_type === reactionType) {
        // Remove reaction
        await db.query('DELETE FROM reactions WHERE post_id = ? AND user_id = ?', [postId, userId]);
        res.json({ reacted: false });
      } else {
        // Update reaction type
        await db.query(
          'UPDATE reactions SET reaction_type = ? WHERE post_id = ? AND user_id = ?',
          [reactionType, postId, userId]
        );
        res.json({ reacted: true, reactionType });
      }
    } else {
      // Add new reaction
      await db.query(
        'INSERT INTO reactions (post_id, user_id, reaction_type) VALUES (?, ?, ?)',
        [postId, userId, reactionType]
      );
      res.json({ reacted: true, reactionType });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get reactions for a post
router.get('/post/:postId', async (req, res) => {
  const { postId } = req.params;
  try {
    const result = await db.query(`
      SELECT r.reaction_type, COUNT(*) as count
      FROM reactions r
      WHERE r.post_id = ?
      GROUP BY r.reaction_type
    `, [postId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get users who reacted
router.get('/post/:postId/users', async (req, res) => {
  const { postId } = req.params;
  const { reactionType } = req.query;
  try {
    let query = `
      SELECT u.id, u.name, u.profile_image_url, r.reaction_type, r.created_at
      FROM reactions r
      JOIN users u ON r.user_id = u.id
      WHERE r.post_id = ?
    `;
    const params = [postId];

    if (reactionType) {
      query += ' AND r.reaction_type = ?';
      params.push(reactionType);
    }

    query += ' ORDER BY r.created_at DESC';
    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

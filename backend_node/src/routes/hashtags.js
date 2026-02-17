const express = require('express');
const router = express.Router();
const db = require('../db');

// Get trending hashtags
router.get('/trending', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT h.*, COUNT(ph.id) as post_count
      FROM hashtags h
      LEFT JOIN post_hashtags ph ON h.id = ph.hashtag_id
      WHERE ph.created_at >= datetime('now', '-7 days')
      GROUP BY h.id
      ORDER BY post_count DESC, h.usage_count DESC
      LIMIT 10
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get posts by hashtag
router.get('/:hashtag/posts', async (req, res) => {
  const { hashtag } = req.params;
  try {
    const result = await db.query(`
      SELECT p.*, u.name as user_name, u.profile_image_url
      FROM posts p
      JOIN post_hashtags ph ON p.id = ph.post_id
      JOIN hashtags h ON ph.hashtag_id = h.id
      JOIN users u ON p.user_id = u.id
      WHERE h.name = ?
      ORDER BY p.created_at DESC
      LIMIT 50
    `, [hashtag]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create or get hashtag
router.post('/', async (req, res) => {
  const { name } = req.body;
  try {
    // Check if exists
    let result = await db.query('SELECT * FROM hashtags WHERE name = ?', [name]);
    
    if (result.rows.length > 0) {
      // Update usage count
      await db.query('UPDATE hashtags SET usage_count = usage_count + 1 WHERE name = ?', [name]);
      res.json(result.rows[0]);
    } else {
      // Create new
      result = await db.query(
        'INSERT INTO hashtags (name, usage_count) VALUES (?, 1) RETURNING *',
        [name]
      );
      res.status(201).json(result.rows[0]);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Link hashtag to post
router.post('/link', async (req, res) => {
  const { postId, hashtagId } = req.body;
  try {
    await db.query(
      'INSERT OR IGNORE INTO post_hashtags (post_id, hashtag_id) VALUES (?, ?)',
      [postId, hashtagId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

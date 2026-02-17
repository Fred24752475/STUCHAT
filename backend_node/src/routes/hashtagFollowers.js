const express = require('express');
const router = express.Router();
const db = require('../db');

// Follow a hashtag
router.post('/follow', async (req, res) => {
  try {
    const { userId, hashtagId } = req.body;

    if (!userId || !hashtagId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.query(
      `INSERT INTO hashtag_followers (user_id, hashtag_id) VALUES (?, ?)`,
      [userId, hashtagId]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error following hashtag:', error);
    res.status(500).json({ error: 'Failed to follow hashtag' });
  }
});

// Unfollow a hashtag
router.post('/unfollow', async (req, res) => {
  try {
    const { userId, hashtagId } = req.body;

    await db.query(
      `DELETE FROM hashtag_followers WHERE user_id = ? AND hashtag_id = ?`,
      [userId, hashtagId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error unfollowing hashtag:', error);
    res.status(500).json({ error: 'Failed to unfollow hashtag' });
  }
});

// Get followed hashtags
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT h.id, h.name, h.usage_count FROM hashtag_followers hf
       JOIN hashtags h ON hf.hashtag_id = h.id
       WHERE hf.user_id = ? ORDER BY hf.followed_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching followed hashtags:', error);
    res.status(500).json({ error: 'Failed to fetch followed hashtags' });
  }
});

// Check if user follows hashtag
router.get('/check/:userId/:hashtagId', async (req, res) => {
  try {
    const { userId, hashtagId } = req.params;

    const result = await db.query(
      `SELECT id FROM hashtag_followers WHERE user_id = ? AND hashtag_id = ?`,
      [userId, hashtagId]
    );

    res.json({ isFollowing: result.rows.length > 0 });
  } catch (error) {
    console.error('Error checking hashtag follow:', error);
    res.status(500).json({ error: 'Failed to check hashtag follow' });
  }
});

// Get posts from followed hashtags
router.get('/feed/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = req.query.limit || 20;
    const offset = req.query.offset || 0;

    const result = await db.query(
      `SELECT DISTINCT p.* FROM posts p
       JOIN post_hashtags ph ON p.id = ph.post_id
       JOIN hashtag_followers hf ON ph.hashtag_id = hf.hashtag_id
       WHERE hf.user_id = ? ORDER BY p.created_at DESC LIMIT ? OFFSET ?`,
      [userId, limit, offset]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching hashtag feed:', error);
    res.status(500).json({ error: 'Failed to fetch hashtag feed' });
  }
});

module.exports = router;

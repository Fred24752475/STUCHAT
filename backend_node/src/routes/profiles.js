const express = require('express');
const router = express.Router();
const db = require('../db');

// Get user profile
router.get('/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const user = await db.query(`
      SELECT u.*, up.bio, up.interests, up.major, up.phone, up.website, up.location, up.is_private,
             (SELECT COUNT(*) FROM followers WHERE following_id = u.id) as followers_count,
             (SELECT COUNT(*) FROM followers WHERE follower_id = u.id) as following_count,
             (SELECT COUNT(*) FROM posts WHERE user_id = u.id) as posts_count
      FROM users u
      LEFT JOIN user_profiles up ON u.id = up.user_id
      WHERE u.id = $1
    `, [userId]);

    if (user.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(user.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update user profile
router.put('/:userId', async (req, res) => {
  const { userId } = req.params;
  const { name, bio, interests, major, phone, website, location, profileImageUrl } = req.body;
  
  try {
    if (name || profileImageUrl) {
      await db.query(
        'UPDATE users SET name = COALESCE($1, name), profile_image_url = COALESCE($2, profile_image_url) WHERE id = $3',
        [name, profileImageUrl, userId]
      );
    }

    const existing = await db.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]);
    
    if (existing.rows.length > 0) {
      await db.query(`
        UPDATE user_profiles 
        SET bio = COALESCE($1, bio), 
            interests = COALESCE($2, interests),
            major = COALESCE($3, major),
            phone = COALESCE($4, phone),
            website = COALESCE($5, website),
            location = COALESCE($6, location)
        WHERE user_id = $7
      `, [bio, interests, major, phone, website, location, userId]);
    } else {
      await db.query(`
        INSERT INTO user_profiles (user_id, bio, interests, major, phone, website, location)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [userId, bio, interests, major, phone, website, location]);
    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user posts
router.get('/:userId/posts', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT p.*, u.name as user_name, u.profile_image_url
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.user_id = $1
      ORDER BY p.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user achievements
router.get('/:userId/achievements', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT a.*, ua.earned_at
      FROM user_achievements ua
      JOIN achievements a ON ua.achievement_id = a.id
      WHERE ua.user_id = $1
      ORDER BY ua.earned_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Toggle private account
router.put('/:userId/privacy', async (req, res) => {
  const { userId } = req.params;
  const { isPrivate } = req.body;
  try {
    await db.query(
      'UPDATE user_profiles SET is_private = $1 WHERE user_id = $2',
      [isPrivate ? true : false, userId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

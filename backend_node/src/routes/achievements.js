const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all achievements
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM achievements ORDER BY points DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Award achievement to user
router.post('/award', async (req, res) => {
  const { userId, achievementId } = req.body;
  try {
    await db.query(
      'INSERT OR IGNORE INTO user_achievements (user_id, achievement_id) VALUES (?, ?)',
      [userId, achievementId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user's achievements
router.get('/user/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT a.*, ua.earned_at
      FROM user_achievements ua
      JOIN achievements a ON ua.achievement_id = a.id
      WHERE ua.user_id = ?
      ORDER BY ua.earned_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user's total points
router.get('/user/:userId/points', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT SUM(a.points) as total_points
      FROM user_achievements ua
      JOIN achievements a ON ua.achievement_id = a.id
      WHERE ua.user_id = ?
    `, [userId]);
    res.json({ totalPoints: result.rows[0].total_points || 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, SUM(a.points) as total_points,
             COUNT(ua.id) as achievement_count
      FROM users u
      LEFT JOIN user_achievements ua ON u.id = ua.user_id
      LEFT JOIN achievements a ON ua.achievement_id = a.id
      GROUP BY u.id
      ORDER BY total_points DESC
      LIMIT 50
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

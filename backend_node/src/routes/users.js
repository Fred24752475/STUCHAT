const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all available users - simple version
router.get('/available/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Simple query - just get all users except current user
    const result = await db.query(`
      SELECT id, name, email, course, year, profile_image_url
      FROM users
      WHERE id != $1
      ORDER BY name
      LIMIT 50
    `, [userId]);
    
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching available users:', err);
    res.status(500).json({ error: err.message });
  }
});

// Debug route to check DB connection
router.get('/test-db', async (req, res) => {
  try {
    const result = await db.query('SELECT COUNT(*) as count FROM users');
    res.json({ success: true, userCount: result.rows[0].count });
  } catch (err) {
    console.error('DB test error:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

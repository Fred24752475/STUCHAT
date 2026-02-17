const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all available users (not friends yet, not sent request to, not received request from)
router.get('/available/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(`
      SELECT id, name, email, course, year, profile_image_url      FROM users
      WHERE id != $1
      AND id NOT IN (
        SELECT following_id FROM followers WHERE follower_id = $1
      )
      AND id NOT IN (
        SELECT receiver_id FROM friend_requests WHERE sender_id = $1 AND status = 'pending'
      )
      AND id NOT IN (
        SELECT sender_id FROM friend_requests WHERE receiver_id = $1 AND status = 'pending'
      )
      ORDER BY name
      LIMIT 50
    `, [userId, userId, userId, userId]);
    
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching available users:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

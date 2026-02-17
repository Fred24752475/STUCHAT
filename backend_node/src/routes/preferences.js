const express = require('express');
const router = express.Router();
const db = require('../db');

// Get user preferences
router.get('/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    let result = await db.query('SELECT * FROM user_preferences WHERE user_id = ?', [userId]);
    
    if (result.rows.length === 0) {
      // Create default preferences
      result = await db.query(
        'INSERT INTO user_preferences (user_id) VALUES (?) RETURNING *',
        [userId]
      );
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update preferences
router.put('/:userId', async (req, res) => {
  const { userId } = req.params;
  const { theme, notificationsEnabled, emailNotifications, pushNotifications, language } = req.body;
  
  try {
    await db.query(`
      UPDATE user_preferences 
      SET theme = COALESCE(?, theme),
          notifications_enabled = COALESCE(?, notifications_enabled),
          email_notifications = COALESCE(?, email_notifications),
          push_notifications = COALESCE(?, push_notifications),
          language = COALESCE(?, language)
      WHERE user_id = ?
    `, [theme, notificationsEnabled, emailNotifications, pushNotifications, language, userId]);
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

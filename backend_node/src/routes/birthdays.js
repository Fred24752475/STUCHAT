const express = require('express');
const router = express.Router();
const db = require('../db');

// Set user birthday
router.post('/', async (req, res) => {
  try {
    const { userId, birthDate, showOnProfile = true } = req.body;

    if (!userId || !birthDate) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.query(
      `INSERT OR REPLACE INTO user_birthdays (user_id, birth_date, show_on_profile) 
       VALUES (?, ?, ?)`,
      [userId, birthDate, showOnProfile ? 1 : 0]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error setting birthday:', error);
    res.status(500).json({ error: 'Failed to set birthday' });
  }
});

// Get user birthday
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT birth_date, show_on_profile FROM user_birthdays WHERE user_id = ?`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({ birthDate: null });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching birthday:', error);
    res.status(500).json({ error: 'Failed to fetch birthday' });
  }
});

// Get today's birthdays
router.get('/today/list', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url, ub.birth_date 
       FROM user_birthdays ub
       JOIN users u ON ub.user_id = u.id
       WHERE ub.show_on_profile = 1 
       AND strftime('%m-%d', ub.birth_date) = strftime('%m-%d', 'now')
       ORDER BY u.name`,
      []
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching today birthdays:', error);
    res.status(500).json({ error: 'Failed to fetch birthdays' });
  }
});

// Send birthday celebration
router.post('/celebrate', async (req, res) => {
  try {
    const { userId, celebratorId, message } = req.body;

    if (!userId || !celebratorId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.query(
      `INSERT INTO birthday_celebrations (user_id, celebrator_id, message) 
       VALUES (?, ?, ?)`,
      [userId, celebratorId, message || 'Happy Birthday! 🎉']
    );

    // Create notification
    const celebrator = await db.query(
      `SELECT name FROM users WHERE id = ?`,
      [celebratorId]
    );

    await db.query(
      `INSERT INTO notifications (user_id, type, title, message, from_user_id, reference_id) 
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, 'birthday', 'Birthday message', `${celebrator.rows[0]?.name} sent you a birthday message!`, celebratorId, celebratorId]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error sending birthday celebration:', error);
    res.status(500).json({ error: 'Failed to send birthday celebration' });
  }
});

// Get birthday celebrations for user
router.get('/celebrations/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT bc.*, u.name, u.profile_image_url FROM birthday_celebrations bc
       JOIN users u ON bc.celebrator_id = u.id
       WHERE bc.user_id = ? ORDER BY bc.created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching birthday celebrations:', error);
    res.status(500).json({ error: 'Failed to fetch birthday celebrations' });
  }
});

// Get upcoming birthdays
router.get('/upcoming/:days', async (req, res) => {
  try {
    const { days } = req.params;

    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url, ub.birth_date,
              CAST((julianday(ub.birth_date) - julianday('now')) AS INTEGER) as days_until
       FROM user_birthdays ub
       JOIN users u ON ub.user_id = u.id
       WHERE ub.show_on_profile = 1 
       AND CAST((julianday(ub.birth_date) - julianday('now')) AS INTEGER) BETWEEN 0 AND ?
       ORDER BY days_until ASC`,
      [days]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching upcoming birthdays:', error);
    res.status(500).json({ error: 'Failed to fetch upcoming birthdays' });
  }
});

module.exports = router;

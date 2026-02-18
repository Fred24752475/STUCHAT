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
      `INSERT INTO user_birthdays (user_id, birth_date, show_on_profile) 
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id) DO UPDATE SET birth_date = $2, show_on_profile = $3`,
      [userId, birthDate, showOnProfile ? true : false]
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
      `SELECT birth_date, show_on_profile FROM user_birthdays WHERE user_id = $1`,
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
       WHERE ub.show_on_profile = true 
       AND TO_CHAR(ub.birth_date, 'MM-DD') = TO_CHAR(NOW(), 'MM-DD')
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
       VALUES ($1, $2, $3)`,
      [userId, celebratorId, message || 'Happy Birthday! 🎉']
    );

    const celebrator = await db.query(
      `SELECT name FROM users WHERE id = $1`,
      [celebratorId]
    );

    await db.query(
      `INSERT INTO notifications (user_id, type, title, message, from_user_id, reference_id) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
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
       WHERE bc.user_id = $1 ORDER BY bc.created_at DESC`,
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
              EXTRACT(DAY FROM (ub.birth_date - CURRENT_DATE)) as days_until
       FROM user_birthdays ub
       JOIN users u ON ub.user_id = u.id
       WHERE ub.show_on_profile = true 
       AND EXTRACT(DAY FROM (ub.birth_date - CURRENT_DATE)) BETWEEN 0 AND $1
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

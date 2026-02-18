const express = require('express');
const router = express.Router();
const db = require('../db');

// Get notifications for a user
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(`
      SELECT n.*, u.name as from_user_name, u.profile_image_url as from_user_image
      FROM notifications n
      LEFT JOIN users u ON n.from_user_id = u.id
      WHERE n.user_id = $1
      ORDER BY n.created_at DESC
      LIMIT 50
    `, [userId]);
    
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get unread notification count
router.get('/unread/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(
      'SELECT COUNT(*) as count FROM notifications WHERE user_id = $1 AND is_read = 0',
      [userId]
    );
    
    res.json({ count: result.rows[0].count });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Mark notification as read
router.put('/read/:notificationId', async (req, res) => {
  try {
    const { notificationId } = req.params;
    
    await db.query(
      'UPDATE notifications SET is_read = 1 WHERE id = $1',
      [notificationId]
    );
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Mark all as read
router.put('/read-all/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    await db.query(
      'UPDATE notifications SET is_read = 1 WHERE user_id = $1',
      [userId]
    );
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete notification
router.delete('/:notificationId', async (req, res) => {
  try {
    const { notificationId } = req.params;
    
    await db.query(
      'DELETE FROM notifications WHERE id = $1',
      [notificationId]
    );
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create notification (used internally)
router.post('/', async (req, res) => {
  try {
    const { userId, type, title, message, fromUserId, referenceId } = req.body;
    
    const result = await db.query(
      `INSERT INTO notifications (user_id, type, title, message, from_user_id, reference_id) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [userId, type, title, message, fromUserId, referenceId]
    );
    
    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

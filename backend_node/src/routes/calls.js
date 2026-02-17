const express = require('express');
const router = express.Router();
const db = require('../db');

// Initiate call
router.post('/initiate', async (req, res) => {
  try {
    const { callerId, receiverId, callType } = req.body;
    
    const result = await db.query(
      'INSERT INTO video_calls (caller_id, receiver_id, call_type, status) VALUES (?, ?, ?, ?) RETURNING *',
      [callerId, receiverId, callType, 'ringing']
    );

    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Answer call
router.put('/:callId/answer', async (req, res) => {
  try {
    const { callId } = req.params;
    
    await db.query(
      'UPDATE video_calls SET status = ? WHERE id = ?',
      ['active', callId]
    );

    const result = await db.query('SELECT * FROM video_calls WHERE id = ?', [callId]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// End call
router.put('/:callId/end', async (req, res) => {
  try {
    const { callId } = req.params;
    const { duration } = req.body;
    
    await db.query(
      "UPDATE video_calls SET status = ?, ended_at = datetime('now'), duration = ? WHERE id = ?",
      ['ended', duration, callId]
    );

    const result = await db.query('SELECT * FROM video_calls WHERE id = ?', [callId]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Reject call
router.put('/:callId/reject', async (req, res) => {
  try {
    const { callId } = req.params;
    
    await db.query(
      "UPDATE video_calls SET status = ?, ended_at = datetime('now') WHERE id = ?",
      ['rejected', callId]
    );

    const result = await db.query('SELECT * FROM video_calls WHERE id = ?', [callId]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get call history
router.get('/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await db.query(`
      SELECT vc.*, 
             u1.name as caller_name, u1.profile_image_url as caller_image,
             u2.name as receiver_name, u2.profile_image_url as receiver_image
      FROM video_calls vc
      JOIN users u1 ON vc.caller_id = u1.id
      JOIN users u2 ON vc.receiver_id = u2.id
      WHERE vc.caller_id = ? OR vc.receiver_id = ?
      ORDER BY vc.started_at DESC
      LIMIT 50
    `, [userId, userId]);

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

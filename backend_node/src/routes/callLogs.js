const express = require('express');
const router = express.Router();
const db = require('../db');

// Initiate video/voice call
router.post('/initiate', async (req, res) => {
  try {
    const { callerId, receiverId, callType } = req.body;

    if (!callerId || !receiverId || !callType) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO call_logs (caller_id, receiver_id, call_type, status) 
       VALUES (?, ?, ?, 'pending')`,
      [callerId, receiverId, callType]
    );

    res.status(201).json({ success: true, callId: result.rows[0]?.id });
  } catch (error) {
    console.error('Error initiating call:', error);
    res.status(500).json({ error: 'Failed to initiate call' });
  }
});

// Answer call
router.put('/:callId/answer', async (req, res) => {
  try {
    const { callId } = req.params;

    await db.query(
      `UPDATE call_logs SET status = 'active' WHERE id = ?`,
      [callId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error answering call:', error);
    res.status(500).json({ error: 'Failed to answer call' });
  }
});

// Reject call
router.put('/:callId/reject', async (req, res) => {
  try {
    const { callId } = req.params;

    await db.query(
      `UPDATE call_logs SET status = 'rejected' WHERE id = ?`,
      [callId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error rejecting call:', error);
    res.status(500).json({ error: 'Failed to reject call' });
  }
});

// End call
router.put('/:callId/end', async (req, res) => {
  try {
    const { callId } = req.params;
    const { duration = 0 } = req.body;

    await db.query(
      `UPDATE call_logs SET status = 'completed', ended_at = CURRENT_TIMESTAMP, duration = ? WHERE id = ?`,
      [duration, callId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error ending call:', error);
    res.status(500).json({ error: 'Failed to end call' });
  }
});

// Miss call
router.put('/:callId/miss', async (req, res) => {
  try {
    const { callId } = req.params;

    await db.query(
      `UPDATE call_logs SET status = 'missed', is_missed = 1, ended_at = CURRENT_TIMESTAMP WHERE id = ?`,
      [callId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error marking call as missed:', error);
    res.status(500).json({ error: 'Failed to mark call as missed' });
  }
});

// Get call history for user
router.get('/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = req.query.limit || 50;

    const result = await db.query(
      `SELECT cl.*, 
              CASE WHEN cl.caller_id = ? THEN u2.name ELSE u1.name END as contact_name,
              CASE WHEN cl.caller_id = ? THEN u2.profile_image_url ELSE u1.profile_image_url END as contact_image
       FROM call_logs cl
       JOIN users u1 ON cl.caller_id = u1.id
       JOIN users u2 ON cl.receiver_id = u2.id
       WHERE cl.caller_id = ? OR cl.receiver_id = ?
       ORDER BY cl.created_at DESC LIMIT ?`,
      [userId, userId, userId, userId, limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching call history:', error);
    res.status(500).json({ error: 'Failed to fetch call history' });
  }
});

// Get missed calls
router.get('/missed/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT cl.*, u.name, u.profile_image_url FROM call_logs cl
       JOIN users u ON cl.caller_id = u.id
       WHERE cl.receiver_id = ? AND cl.is_missed = 1
       ORDER BY cl.created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching missed calls:', error);
    res.status(500).json({ error: 'Failed to fetch missed calls' });
  }
});

// Get call statistics
router.get('/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const totalCalls = await db.query(
      `SELECT COUNT(*) as count FROM call_logs WHERE caller_id = ? OR receiver_id = ?`,
      [userId, userId]
    );

    const missedCalls = await db.query(
      `SELECT COUNT(*) as count FROM call_logs WHERE receiver_id = ? AND is_missed = 1`,
      [userId]
    );

    const totalDuration = await db.query(
      `SELECT SUM(duration) as total FROM call_logs WHERE (caller_id = ? OR receiver_id = ?) AND status = 'completed'`,
      [userId, userId]
    );

    res.json({
      totalCalls: totalCalls.rows[0]?.count || 0,
      missedCalls: missedCalls.rows[0]?.count || 0,
      totalDuration: totalDuration.rows[0]?.total || 0
    });
  } catch (error) {
    console.error('Error fetching call statistics:', error);
    res.status(500).json({ error: 'Failed to fetch call statistics' });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const db = require('../db');

// Block user
router.post('/block', async (req, res) => {
  const { blockerId, blockedId } = req.body;
  try {
    await db.query(
      'INSERT OR IGNORE INTO blocked_users (blocker_id, blocked_id) VALUES (?, ?)',
      [blockerId, blockedId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Unblock user
router.delete('/unblock', async (req, res) => {
  const { blockerId, blockedId } = req.body;
  try {
    await db.query(
      'DELETE FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
      [blockerId, blockedId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get blocked users
router.get('/blocked/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, b.created_at as blocked_at
      FROM blocked_users b
      JOIN users u ON b.blocked_id = u.id
      WHERE b.blocker_id = ?
      ORDER BY b.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Check if blocked
router.get('/check/:userId1/:userId2', async (req, res) => {
  const { userId1, userId2 } = req.params;
  try {
    const result = await db.query(
      'SELECT * FROM blocked_users WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)',
      [userId1, userId2, userId2, userId1]
    );
    res.json({ isBlocked: result.rows.length > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Report content
router.post('/report', async (req, res) => {
  const { reporterId, reportedUserId, postId, commentId, reason, description } = req.body;
  try {
    const result = await db.query(`
      INSERT INTO reports (reporter_id, reported_user_id, post_id, comment_id, reason, description)
      VALUES (?, ?, ?, ?, ?, ?) RETURNING *
    `, [reporterId, reportedUserId, postId, commentId, reason, description]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get all reports (admin)
router.get('/reports', async (req, res) => {
  const { status } = req.query;
  try {
    let query = `
      SELECT r.*, 
             reporter.name as reporter_name,
             reported.name as reported_user_name
      FROM reports r
      JOIN users reporter ON r.reporter_id = reporter.id
      LEFT JOIN users reported ON r.reported_user_id = reported.id
      WHERE 1=1
    `;
    const params = [];

    if (status) {
      query += ' AND r.status = ?';
      params.push(status);
    }

    query += ' ORDER BY r.created_at DESC';
    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update report status
router.put('/reports/:id', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
    await db.query('UPDATE reports SET status = ? WHERE id = ?', [status, id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

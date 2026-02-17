const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM events WHERE event_date >= NOW() ORDER BY event_date ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  const { title, description, eventDate, location, creatorId } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO events (title, description, event_date, location, creator_id) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [title, description, eventDate, location, creatorId]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// RSVP to event
router.post('/:eventId/rsvp', async (req, res) => {
  const { eventId } = req.params;
  const { userId, status } = req.body;
  try {
    const result = await db.query(
      'INSERT OR REPLACE INTO event_rsvps (event_id, user_id, status) VALUES ($1, $2, $3) RETURNING *',
      [eventId, userId, status]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get RSVPs for an event
router.get('/:eventId/rsvps', async (req, res) => {
  const { eventId } = req.params;
  try {
    const result = await db.query(`
      SELECT r.*, u.name, u.profile_image_url
      FROM event_rsvps r
      JOIN users u ON r.user_id = u.id
      WHERE r.event_id = $1
      ORDER BY r.created_at DESC
    `, [eventId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user's RSVP status for an event
router.get('/:eventId/rsvp/:userId', async (req, res) => {
  const { eventId, userId } = req.params;
  try {
    const result = await db.query(
      'SELECT status FROM event_rsvps WHERE event_id = $1 AND user_id = $2',
      [eventId, userId]
    );
    res.json(result.rows.length > 0 ? { status: result.rows[0].status } : { status: null });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const db = require('../db');

// Create poll
router.post('/', async (req, res) => {
  const { postId, question, options, durationHours } = req.body;
  try {
    const expiresAt = new Date(Date.now() + (durationHours || 24) * 60 * 60 * 1000).toISOString();
    
    const poll = await db.query(
      'INSERT INTO polls (post_id, question, duration_hours, expires_at) VALUES (?, ?, ?, ?) RETURNING *',
      [postId, question, durationHours || 24, expiresAt]
    );

    const pollId = poll.rows[0].id;

    // Create poll options
    for (const option of options) {
      await db.query(
        'INSERT INTO poll_options (poll_id, option_text) VALUES (?, ?)',
        [pollId, option]
      );
    }

    res.status(201).json(poll.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get poll by post ID
router.get('/post/:postId', async (req, res) => {
  const { postId } = req.params;
  try {
    const poll = await db.query('SELECT * FROM polls WHERE post_id = ?', [postId]);
    
    if (poll.rows.length === 0) {
      return res.status(404).json({ error: 'Poll not found' });
    }

    const options = await db.query(
      'SELECT * FROM poll_options WHERE poll_id = ? ORDER BY id',
      [poll.rows[0].id]
    );

    const totalVotes = await db.query(
      'SELECT COUNT(*) as count FROM poll_votes WHERE poll_id = ?',
      [poll.rows[0].id]
    );

    res.json({
      ...poll.rows[0],
      options: options.rows,
      totalVotes: totalVotes.rows[0].count
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Vote on poll
router.post('/:pollId/vote', async (req, res) => {
  const { pollId } = req.params;
  const { userId, optionId } = req.body;
  
  try {
    // Check if already voted
    const existing = await db.query(
      'SELECT * FROM poll_votes WHERE poll_id = ? AND user_id = ?',
      [pollId, userId]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Already voted' });
    }

    // Add vote
    await db.query(
      'INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES (?, ?, ?)',
      [pollId, optionId, userId]
    );

    // Update vote count
    await db.query(
      'UPDATE poll_options SET votes = votes + 1 WHERE id = ?',
      [optionId]
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get poll results
router.get('/:pollId/results', async (req, res) => {
  const { pollId } = req.params;
  try {
    const options = await db.query(
      'SELECT * FROM poll_options WHERE poll_id = ? ORDER BY votes DESC',
      [pollId]
    );

    const totalVotes = await db.query(
      'SELECT COUNT(*) as count FROM poll_votes WHERE poll_id = ?',
      [pollId]
    );

    res.json({
      options: options.rows,
      totalVotes: totalVotes.rows[0].count
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

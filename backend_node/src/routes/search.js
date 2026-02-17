const express = require('express');
const router = express.Router();
const db = require('../db');

// Add to search history
router.post('/history', async (req, res) => {
  try {
    const { userId, query, searchType = 'general' } = req.body;

    if (!userId || !query) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.query(
      `INSERT INTO search_history (user_id, query, search_type) VALUES (?, ?, ?)`,
      [userId, query, searchType]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error adding to search history:', error);
    res.status(500).json({ error: 'Failed to add to search history' });
  }
});

// Get search history
router.get('/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = req.query.limit || 20;

    const result = await db.query(
      `SELECT DISTINCT query, search_type FROM search_history 
       WHERE user_id = ? ORDER BY searched_at DESC LIMIT ?`,
      [userId, limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching search history:', error);
    res.status(500).json({ error: 'Failed to fetch search history' });
  }
});

// Clear search history
router.delete('/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    await db.query('DELETE FROM search_history WHERE user_id = ?', [userId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Error clearing search history:', error);
    res.status(500).json({ error: 'Failed to clear search history' });
  }
});

// Save search
router.post('/saved', async (req, res) => {
  try {
    const { userId, query, searchType = 'general', name } = req.body;

    if (!userId || !query) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(
      `INSERT INTO saved_searches (user_id, query, search_type, name) 
       VALUES (?, ?, ?, ?)`,
      [userId, query, searchType, name || query]
    );

    res.status(201).json({ success: true, id: result.rows[0]?.id });
  } catch (error) {
    console.error('Error saving search:', error);
    res.status(500).json({ error: 'Failed to save search' });
  }
});

// Get saved searches
router.get('/saved/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT id, query, search_type, name, created_at FROM saved_searches 
       WHERE user_id = ? ORDER BY created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching saved searches:', error);
    res.status(500).json({ error: 'Failed to fetch saved searches' });
  }
});

// Delete saved search
router.delete('/saved/:searchId', async (req, res) => {
  try {
    const { searchId } = req.params;

    await db.query('DELETE FROM saved_searches WHERE id = ?', [searchId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting saved search:', error);
    res.status(500).json({ error: 'Failed to delete saved search' });
  }
});

// Get search suggestions
router.get('/suggestions/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const query = req.query.q || '';

    const result = await db.query(
      `SELECT DISTINCT query FROM search_history 
       WHERE user_id = ? AND query LIKE ? 
       ORDER BY searched_at DESC LIMIT 10`,
      [userId, `${query}%`]
    );

    res.json(result.rows.map(r => r.query));
  } catch (error) {
    console.error('Error fetching suggestions:', error);
    res.status(500).json({ error: 'Failed to fetch suggestions' });
  }
});

module.exports = router;

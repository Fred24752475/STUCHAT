const express = require('express');
const router = express.Router();
const db = require('../db');

// Add content filter
router.post('/', async (req, res) => {
  try {
    const { userId, filterType, filterValue } = req.body;

    if (!userId || !filterType) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.query(
      `INSERT INTO content_filters (user_id, filter_type, filter_value) 
       VALUES (?, ?, ?)`,
      [userId, filterType, filterValue || null]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('Error adding content filter:', error);
    res.status(500).json({ error: 'Failed to add content filter' });
  }
});

// Get user filters
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT id, filter_type, filter_value, is_active FROM content_filters 
       WHERE user_id = ? AND is_active = 1`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching filters:', error);
    res.status(500).json({ error: 'Failed to fetch filters' });
  }
});

// Toggle filter
router.put('/:filterId', async (req, res) => {
  try {
    const { filterId } = req.params;
    const { isActive } = req.body;

    await db.query(
      `UPDATE content_filters SET is_active = ? WHERE id = ?`,
      [isActive ? 1 : 0, filterId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error updating filter:', error);
    res.status(500).json({ error: 'Failed to update filter' });
  }
});

// Delete filter
router.delete('/:filterId', async (req, res) => {
  try {
    const { filterId } = req.params;

    await db.query('DELETE FROM content_filters WHERE id = ?', [filterId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting filter:', error);
    res.status(500).json({ error: 'Failed to delete filter' });
  }
});

// Filter posts by criteria
router.get('/feed/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { filterType, filterValue, sortBy = 'recent' } = req.query;
    const limit = req.query.limit || 20;
    const offset = req.query.offset || 0;

    let query = `SELECT p.* FROM posts p WHERE 1=1`;
    let params = [];

    // Apply filters
    if (filterType === 'date') {
      const days = filterValue || 7;
      query += ` AND p.created_at >= datetime('now', '-${days} days')`;
    } else if (filterType === 'popularity') {
      const minLikes = filterValue || 10;
      query += ` AND p.likes >= ?`;
      params.push(minLikes);
    } else if (filterType === 'type') {
      if (filterValue === 'image') {
        query += ` AND p.image_url IS NOT NULL`;
      } else if (filterValue === 'video') {
        query += ` AND p.video_url IS NOT NULL`;
      } else if (filterValue === 'text') {
        query += ` AND p.image_url IS NULL AND p.video_url IS NULL`;
      }
    }

    // Apply sorting
    if (sortBy === 'popular') {
      query += ` ORDER BY p.likes DESC`;
    } else if (sortBy === 'trending') {
      query += ` ORDER BY (p.likes + p.comments) DESC`;
    } else {
      query += ` ORDER BY p.created_at DESC`;
    }

    query += ` LIMIT ? OFFSET ?`;
    params.push(limit, offset);

    const result = await db.query(query, params);

    res.json(result.rows);
  } catch (error) {
    console.error('Error filtering posts:', error);
    res.status(500).json({ error: 'Failed to filter posts' });
  }
});

module.exports = router;

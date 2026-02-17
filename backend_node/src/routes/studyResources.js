const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all study resources
router.get('/', async (req, res) => {
  try {
    const { course, search } = req.query;
    let query = 'SELECT sr.*, u.name as user_name FROM study_resources sr JOIN users u ON sr.user_id = u.id WHERE 1=1';
    const params = [];

    if (course) {
      query += ' AND sr.course = ?';
      params.push(course);
    }

    if (search) {
      query += ' AND (sr.title LIKE ? OR sr.description LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    query += ' ORDER BY sr.created_at DESC';

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get study resource by ID
router.get('/:id', async (req, res) => {
  try {
    const result = await db.query(
      'SELECT sr.*, u.name as user_name FROM study_resources sr JOIN users u ON sr.user_id = u.id WHERE sr.id = ?',
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Resource not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create study resource
router.post('/', async (req, res) => {
  try {
    const { userId, title, description, fileUrl, course, resourceType } = req.body;
    const result = await db.query(
      'INSERT INTO study_resources (user_id, title, description, file_url, course, resource_type) VALUES (?, ?, ?, ?, ?, ?) RETURNING *',
      [userId, title, description, fileUrl, course, resourceType]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update study resource
router.put('/:id', async (req, res) => {
  try {
    const { title, description, course } = req.body;
    const result = await db.query(
      'UPDATE study_resources SET title = ?, description = ?, course = ? WHERE id = ? RETURNING *',
      [title, description, course, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete study resource
router.delete('/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM study_resources WHERE id = ?', [req.params.id]);
    res.json({ message: 'Resource deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user's study resources
router.get('/user/:userId', async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM study_resources WHERE user_id = ? ORDER BY created_at DESC',
      [req.params.userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

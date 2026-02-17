const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all marketplace items
router.get('/', async (req, res) => {
  const { category, status, search } = req.query;
  try {
    let query = `
      SELECT m.*, u.name as seller_name, u.profile_image_url
      FROM marketplace_items m
      JOIN users u ON m.user_id = u.id
      WHERE 1=1
    `;
    const params = [];
    let paramIndex = 1;

    if (category) {
      query += ` AND m.category = $${paramIndex++}`;
      params.push(category);
    }
    if (status) {
      query += ` AND m.status = $${paramIndex++}`;
      params.push(status);
    }
    if (search) {
      query += ` AND (m.title LIKE $${paramIndex++} OR m.description LIKE $${paramIndex++})`;
      params.push(`%${search}%`, `%${search}%`);
    }

    query += ' ORDER BY m.created_at DESC LIMIT 100';
    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create marketplace item
router.post('/', async (req, res) => {
  const { userId, title, description, price, category, condition, imageUrl, location } = req.body;
  try {
    const result = await db.query(`
      INSERT INTO marketplace_items (user_id, title, description, price, category, condition, image_url, location)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *
    `, [userId, title, description, price, category, condition, imageUrl, location]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get item by ID
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.query(`
      SELECT m.*, u.name as seller_name, u.profile_image_url, u.email as seller_email
      FROM marketplace_items m
      JOIN users u ON m.user_id = u.id
      WHERE m.id = $1
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update item status
router.put('/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  try {
    await db.query('UPDATE marketplace_items SET status = $1 WHERE id = $2', [status, id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete item
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM marketplace_items WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user's items
router.get('/user/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT * FROM marketplace_items
      WHERE user_id = $1
      ORDER BY created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

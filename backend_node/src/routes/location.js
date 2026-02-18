const express = require('express');
const router = express.Router();
const db = require('../db');

// POST update user location
router.post('/update', async (req, res) => {
  try {
    const { userId, latitude, longitude, address } = req.body;
    
    if (!userId || !latitude || !longitude) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.query(
      `UPDATE users SET latitude = $1, longitude = $2, address = $3, last_location_update = $4 WHERE id = $5`,
      [latitude, longitude, address, new Date().toISOString(), userId]
    );
    
    res.status(200).json({ 
      success: true,
      message: 'Location updated successfully'
    });
  } catch (error) {
    console.error('Location update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET user's current location
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID required' });
    }
    
    const result = await db.query(
      'SELECT latitude, longitude, address, last_location_update FROM users WHERE id = $1',
      [userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('Get location error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

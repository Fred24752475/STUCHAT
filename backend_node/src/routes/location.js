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

    db.run(
      `UPDATE users SET latitude = ?, longitude = ?, address = ?, last_location_update = ? WHERE id = ?`,
      [latitude, longitude, address, new Date().toISOString(), userId],
      function(err) {
        if (err) {
          console.error('Error updating location:', err);
          return res.status(500).json({ error: 'Failed to update location' });
        }
        
        res.status(200).json({ 
          success: true,
          message: 'Location updated successfully'
        });
      }
    );
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
    
    db.get(
      'SELECT latitude, longitude, address, last_location_update FROM users WHERE id = ?',
      [userId],
      (err, row) => {
        if (err) {
          console.error('Error getting location:', err);
          return res.status(500).json({ error: 'Failed to get location' });
        }
        
        if (!row) {
          return res.status(404).json({ error: 'User not found' });
        }
        
        res.status(200).json(row);
      }
    );
  } catch (error) {
    console.error('Get location error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
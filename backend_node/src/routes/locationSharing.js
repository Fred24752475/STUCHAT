const express = require('express');
const router = express.Router();
const db = require('../db');

router.post('/enable', async (req, res) => {
  try {
    const { userId, shareWithFriends } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID required' });
    }
    
    res.status(200).json({ 
      success: true, 
      message: 'Location sharing enabled',
      shareWithFriends: shareWithFriends || []
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/disable', async (req, res) => {
  try {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID required' });
    }
    
    res.status(200).json({ success: true, message: 'Location sharing disabled' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/settings/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    res.status(200).json({ 
      isEnabled: false,
      shareWithFriends: []
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const db = require('../db');

// Apply referral code
router.post('/apply', async (req, res) => {
  const { userId, referralCode } = req.body;
  
  try {
    // Find referrer
    const referrer = await db.query(
      'SELECT id, name, referral_points FROM users WHERE referral_code = $1',
      [referralCode]
    );
    
    if (referrer.rows.length === 0) {
      return res.status(404).json({ error: 'Invalid referral code' });
    }
    
    const referrerId = referrer.rows[0].id;
    
    if (referrerId === parseInt(userId)) {
      return res.status(400).json({ error: 'Cannot use your own referral code' });
    }
    
    // Check if user already used a referral
    const user = await db.query('SELECT referred_by FROM users WHERE id = $1', [userId]);
    if (user.rows[0].referred_by) {
      return res.status(400).json({ error: 'You have already used a referral code' });
    }
    
    // Update user with referrer
    await db.query(
      'UPDATE users SET referred_by = $1 WHERE id = $2',
      [referrerId, userId]
    );
    
    // Award points to referrer (10 points per referral)
    await db.query(
      'UPDATE users SET referral_points = referral_points + 10 WHERE id = $1',
      [referrerId]
    );
    
    // Award points to new user (5 points for using referral)
    await db.query(
      'UPDATE users SET referral_points = referral_points + 5 WHERE id = $1',
      [userId]
    );
    
    res.json({ 
      message: `Referral applied! You earned 5 points. ${referrer.rows[0].name} earned 10 points!`,
      pointsEarned: 5
    });
  } catch (err) {
    console.error('Apply referral error:', err);
    res.status(500).json({ error: 'Failed to apply referral code' });
  }
});

// Get user's referral stats
router.get('/stats/:userId', async (req, res) => {
  const { userId } = req.params;
  
  try {
    const user = await db.query(
      'SELECT referral_code, referral_points FROM users WHERE id = $1',
      [userId]
    );
    
    if (user.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Count referrals
    const referrals = await db.query(
      'SELECT COUNT(*) as count FROM users WHERE referred_by = $1',
      [userId]
    );
    
    // Get referred users
    const referredUsers = await db.query(
      'SELECT id, name, created_at FROM users WHERE referred_by = $1 ORDER BY created_at DESC LIMIT 10',
      [userId]
    );
    
    res.json({
      referralCode: user.rows[0].referral_code,
      points: user.rows[0].referral_points || 0,
      totalReferrals: parseInt(referrals.rows[0].count),
      recentReferrals: referredUsers.rows
    });
  } catch (err) {
    console.error('Get referral stats error:', err);
    res.status(500).json({ error: 'Failed to get referral stats' });
  }
});

// Get referral leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT 
        u.id,
        u.name,
        u.referral_points,
        u.profile_image_url,
        COUNT(r.id) as referral_count
      FROM users u
      LEFT JOIN users r ON r.referred_by = u.id
      WHERE u.referral_points > 0
      GROUP BY u.id
      ORDER BY u.referral_points DESC, referral_count DESC
      LIMIT 50
    `);
    
    res.json(result.rows);
  } catch (err) {
    console.error('Get leaderboard error:', err);
    res.status(500).json({ error: 'Failed to get leaderboard' });
  }
});

module.exports = router;

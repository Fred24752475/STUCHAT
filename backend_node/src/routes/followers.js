const express = require('express');
const router = express.Router();
const db = require('../db');

// Follow a user
router.post('/follow', async (req, res) => {
  const { followerId, followingId } = req.body;
  
  if (followerId === followingId) {
    return res.status(400).json({ error: 'Cannot follow yourself' });
  }
  
  try {
    // Insert follow relationship
    await db.query(
      'INSERT OR IGNORE INTO followers (follower_id, following_id) VALUES ($1, $2)',
      [followerId, followingId]
    );
    
    // Update follower count for the user being followed
    await db.query(
      'UPDATE users SET follower_count = (SELECT COUNT(*) FROM followers WHERE following_id = $1) WHERE id = $1',
      [followingId]
    );
    
    // Update following count for the follower
    await db.query(
      'UPDATE users SET following_count = (SELECT COUNT(*) FROM followers WHERE follower_id = $1) WHERE id = $1',
      [followerId]
    );
    
    res.status(201).json({ success: true, message: 'Successfully followed user' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Unfollow a user
router.delete('/unfollow', async (req, res) => {
  const { followerId, followingId } = req.body;
  try {
    // Delete follow relationship
    await db.query(
      'DELETE FROM followers WHERE follower_id = $1 AND following_id = $2',
      [followerId, followingId]
    );
    
    // Update follower count for the user being unfollowed
    await db.query(
      'UPDATE users SET follower_count = (SELECT COUNT(*) FROM followers WHERE following_id = $1) WHERE id = $1',
      [followingId]
    );
    
    // Update following count for the unfollower
    await db.query(
      'UPDATE users SET following_count = (SELECT COUNT(*) FROM followers WHERE follower_id = $1) WHERE id = $1',
      [followerId]
    );
    
    res.json({ success: true, message: 'Successfully unfollowed user' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get followers of a user
router.get('/:userId/followers', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, u.course, f.created_at
      FROM followers f
      JOIN users u ON f.follower_id = u.id
      WHERE f.following_id = $1
      ORDER BY f.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get following of a user
router.get('/:userId/following', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, u.course, f.created_at
      FROM followers f
      JOIN users u ON f.following_id = u.id
      WHERE f.follower_id = $1
      ORDER BY f.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Check if user1 follows user2
router.get('/check/:followerId/:followingId', async (req, res) => {
  const { followerId, followingId } = req.params;
  try {
    const result = await db.query(
      'SELECT * FROM followers WHERE follower_id = $1 AND following_id = $2',
      [followerId, followingId]
    );
    res.json({ isFollowing: result.rows.length > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get follower/following counts
router.get('/:userId/counts', async (req, res) => {
  const { userId } = req.params;
  try {
    const followers = await db.query(
      'SELECT COUNT(*) as count FROM followers WHERE following_id = $1',
      [userId]
    );
    const following = await db.query(
      'SELECT COUNT(*) as count FROM followers WHERE follower_id = $1',
      [userId]
    );
    res.json({
      followers: followers.rows[0].count || 0,
      following: following.rows[0].count || 0
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

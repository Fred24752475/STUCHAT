const express = require('express');
const router = express.Router();
const db = require('../db');

// Track user action
router.post('/track', async (req, res) => {
  const { userId, actionType, metadata } = req.body;
  
  try {
    await db.query(
      'INSERT INTO user_analytics (user_id, action_type, metadata) VALUES ($1, $2, $3)',
      [userId, actionType, JSON.stringify(metadata || {})]
    );
    
    res.json({ message: 'Action tracked' });
  } catch (err) {
    console.error('Track action error:', err);
    res.status(500).json({ error: 'Failed to track action' });
  }
});

// Get user dashboard stats
router.get('/dashboard/:userId', async (req, res) => {
  const { userId } = req.params;
  const { period = '7' } = req.query; // days
  
  try {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(period));
    
    // Total posts
    const posts = await db.query(
      'SELECT COUNT(*) as count FROM posts WHERE user_id = $1',
      [userId]
    );
    
    // Total likes received
    const likes = await db.query(`
      SELECT COUNT(*) as count 
      FROM likes l
      JOIN posts p ON l.post_id = p.id
      WHERE p.user_id = $1
    `, [userId]);
    
    // Total comments received
    const comments = await db.query(`
      SELECT COUNT(*) as count 
      FROM comments c
      JOIN posts p ON c.post_id = p.id
      WHERE p.user_id = $1 AND c.user_id != $1
    `, [userId]);
    
    // Followers count
    const followers = await db.query(
      'SELECT COUNT(*) as count FROM followers WHERE following_id = $1',
      [userId]
    );
    
    // Following count
    const following = await db.query(
      'SELECT COUNT(*) as count FROM followers WHERE follower_id = $1',
      [userId]
    );
    
    // Profile views (from analytics)
    const profileViews = await db.query(`
      SELECT COUNT(*) as count 
      FROM user_analytics 
      WHERE action_type = 'profile_view' 
      AND metadata LIKE '%"profileId":${userId}%'
      AND created_at >= $1
    `, [startDate.toISOString()]);
    
    // Activity by day (last 7 days)
    const activityByDay = await db.query(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as count
      FROM user_analytics
      WHERE user_id = $1 AND created_at >= $2
      GROUP BY DATE(created_at)
      ORDER BY date DESC
    `, [userId, startDate.toISOString()]);
    
    // Most popular posts
    const popularPosts = await db.query(`
      SELECT 
        p.id,
        p.content,
        p.image_url,
        p.created_at,
        COUNT(DISTINCT l.id) as likes,
        COUNT(DISTINCT c.id) as comments
      FROM posts p
      LEFT JOIN likes l ON p.id = l.post_id
      LEFT JOIN comments c ON p.id = c.post_id
      WHERE p.user_id = $1
      GROUP BY p.id
      ORDER BY likes DESC, comments DESC
      LIMIT 5
    `, [userId]);
    
    // Engagement rate
    const totalEngagement = parseInt(likes.rows[0].count) + parseInt(comments.rows[0].count);
    const totalPosts = parseInt(posts.rows[0].count);
    const engagementRate = totalPosts > 0 ? (totalEngagement / totalPosts).toFixed(2) : 0;
    
    res.json({
      overview: {
        totalPosts: parseInt(posts.rows[0].count),
        totalLikes: parseInt(likes.rows[0].count),
        totalComments: parseInt(comments.rows[0].count),
        followers: parseInt(followers.rows[0].count),
        following: parseInt(following.rows[0].count),
        profileViews: parseInt(profileViews.rows[0].count),
        engagementRate: parseFloat(engagementRate)
      },
      activityByDay: activityByDay.rows,
      popularPosts: popularPosts.rows
    });
  } catch (err) {
    console.error('Get dashboard error:', err);
    res.status(500).json({ error: 'Failed to get dashboard stats' });
  }
});

// Get engagement trends
router.get('/trends/:userId', async (req, res) => {
  const { userId } = req.params;
  
  try {
    const last30Days = new Date();
    last30Days.setDate(last30Days.getDate() - 30);
    
    // Likes trend
    const likesTrend = await db.query(`
      SELECT 
        DATE(l.created_at) as date,
        COUNT(*) as count
      FROM likes l
      JOIN posts p ON l.post_id = p.id
      WHERE p.user_id = $1 AND l.created_at >= $2
      GROUP BY DATE(l.created_at)
      ORDER BY date ASC
    `, [userId, last30Days.toISOString()]);
    
    // Comments trend
    const commentsTrend = await db.query(`
      SELECT 
        DATE(c.created_at) as date,
        COUNT(*) as count
      FROM comments c
      JOIN posts p ON c.post_id = p.id
      WHERE p.user_id = $1 AND c.created_at >= $2
      GROUP BY DATE(c.created_at)
      ORDER BY date ASC
    `, [userId, last30Days.toISOString()]);
    
    // Followers trend
    const followersTrend = await db.query(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as count
      FROM followers
      WHERE following_id = $1 AND created_at >= $2
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `, [userId, last30Days.toISOString()]);
    
    res.json({
      likes: likesTrend.rows,
      comments: commentsTrend.rows,
      followers: followersTrend.rows
    });
  } catch (err) {
    console.error('Get trends error:', err);
    res.status(500).json({ error: 'Failed to get trends' });
  }
});

module.exports = router;

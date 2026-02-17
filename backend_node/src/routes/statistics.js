const express = require('express');
const router = express.Router();
const db = require('../db');

// Get user statistics
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT * FROM user_statistics WHERE user_id = ?`,
      [userId]
    );

    if (result.rows.length === 0) {
      // Create default stats
      await db.query(
        `INSERT INTO user_statistics (user_id) VALUES (?)`,
        [userId]
      );
      return res.json({
        userId,
        totalPosts: 0,
        totalFollowers: 0,
        totalFollowing: 0,
        totalLikesReceived: 0,
        totalCommentsReceived: 0,
        engagementScore: 0
      });
    }

    const stats = result.rows[0];
    res.json({
      userId: stats.user_id,
      totalPosts: stats.total_posts,
      totalFollowers: stats.total_followers,
      totalFollowing: stats.total_following,
      totalLikesReceived: stats.total_likes_received,
      totalCommentsReceived: stats.total_comments_received,
      engagementScore: stats.engagement_score,
      lastUpdated: stats.last_updated
    });
  } catch (error) {
    console.error('Error fetching user statistics:', error);
    res.status(500).json({ error: 'Failed to fetch user statistics' });
  }
});

// Update user statistics
router.put('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    // Calculate stats from database
    const postsResult = await db.query(
      `SELECT COUNT(*) as count FROM posts WHERE user_id = ?`,
      [userId]
    );

    const followersResult = await db.query(
      `SELECT COUNT(*) as count FROM followers WHERE following_id = ?`,
      [userId]
    );

    const followingResult = await db.query(
      `SELECT COUNT(*) as count FROM followers WHERE follower_id = ?`,
      [userId]
    );

    const likesResult = await db.query(
      `SELECT COUNT(*) as count FROM likes WHERE post_id IN (SELECT id FROM posts WHERE user_id = ?)`,
      [userId]
    );

    const commentsResult = await db.query(
      `SELECT COUNT(*) as count FROM comments WHERE post_id IN (SELECT id FROM posts WHERE user_id = ?)`,
      [userId]
    );

    const totalPosts = postsResult.rows[0]?.count || 0;
    const totalFollowers = followersResult.rows[0]?.count || 0;
    const totalFollowing = followingResult.rows[0]?.count || 0;
    const totalLikesReceived = likesResult.rows[0]?.count || 0;
    const totalCommentsReceived = commentsResult.rows[0]?.count || 0;

    // Calculate engagement score
    const engagementScore = (totalLikesReceived * 1 + totalCommentsReceived * 2 + totalFollowers * 0.5) / Math.max(totalPosts, 1);

    await db.query(
      `UPDATE user_statistics SET 
       total_posts = ?, total_followers = ?, total_following = ?, 
       total_likes_received = ?, total_comments_received = ?, 
       engagement_score = ?, last_updated = CURRENT_TIMESTAMP
       WHERE user_id = ?`,
      [totalPosts, totalFollowers, totalFollowing, totalLikesReceived, totalCommentsReceived, engagementScore, userId]
    );

    res.json({
      success: true,
      stats: {
        totalPosts,
        totalFollowers,
        totalFollowing,
        totalLikesReceived,
        totalCommentsReceived,
        engagementScore
      }
    });
  } catch (error) {
    console.error('Error updating user statistics:', error);
    res.status(500).json({ error: 'Failed to update user statistics' });
  }
});

// Get leaderboard by engagement
router.get('/leaderboard/engagement', async (req, res) => {
  try {
    const limit = req.query.limit || 50;

    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url, us.engagement_score, us.total_followers, us.total_posts
       FROM user_statistics us
       JOIN users u ON us.user_id = u.id
       ORDER BY us.engagement_score DESC LIMIT ?`,
      [limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching engagement leaderboard:', error);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// Get leaderboard by followers
router.get('/leaderboard/followers', async (req, res) => {
  try {
    const limit = req.query.limit || 50;

    const result = await db.query(
      `SELECT u.id, u.name, u.profile_image_url, us.total_followers, us.engagement_score
       FROM user_statistics us
       JOIN users u ON us.user_id = u.id
       ORDER BY us.total_followers DESC LIMIT ?`,
      [limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching followers leaderboard:', error);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// Get user rank
router.get('/:userId/rank', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT COUNT(*) as rank FROM user_statistics 
       WHERE engagement_score > (SELECT engagement_score FROM user_statistics WHERE user_id = ?)`,
      [userId]
    );

    res.json({ rank: (result.rows[0]?.rank || 0) + 1 });
  } catch (error) {
    console.error('Error fetching user rank:', error);
    res.status(500).json({ error: 'Failed to fetch user rank' });
  }
});

module.exports = router;

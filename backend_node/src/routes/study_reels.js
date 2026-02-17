const express = require('express');
const router = express.Router();
const db = require('../db');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

// Configure multer for video uploads
const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => {
      const dir = 'uploads/reels';
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      cb(null, dir);
    },
    filename: (req, file, cb) => {
      cb(null, `${Date.now()}-${file.originalname}`);
    }
  }),
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['video/mp4', 'video/webm', 'video/quicktime', 'video/avi'];
    cb(null, allowedMimes.includes(file.mimetype));
  },
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB limit
  }
});

// Get feed of reels with pagination
router.get('/feed', async (req, res) => {
  try {
    const { limit = 20, offset = 0, userId, hashtags, trending } = req.query;
    
    let query = `
      SELECT r.*, u.name as creator_name, u.profile_image_url as creator_avatar,
             COUNT(DISTINCT rl.id) as likes_count,
             COUNT(DISTINCT rc.id) as comments_count,
             COUNT(DISTINCT rs.id) as shares_count,
             CASE WHEN ul.id IS NOT NULL THEN 1 ELSE 0 END as user_liked
      FROM study_reels r 
      JOIN users u ON r.user_id = u.id 
      LEFT JOIN reel_likes rl ON rl.reel_id = r.id
      LEFT JOIN reel_comments rc ON rc.reel_id = r.id
      LEFT JOIN reel_shares rs ON rs.reel_id = r.id
      LEFT JOIN reel_likes ul ON ul.reel_id = r.id AND ul.user_id = ?
      WHERE r.is_public = 1
    `;
    
    const params = [userId || null];
    
    if (hashtags) {
      query += ` AND r.hashtags LIKE ?`;
      params.push(`%${hashtags}%`);
    }
    
    query += ` GROUP BY r.id`;
    
    if (trending === 'true') {
      query += ` ORDER BY (r.likes + r.views + r.shares) DESC, r.created_at DESC`;
    } else {
      query += ` ORDER BY r.created_at DESC`;
    }
    
    query += ` LIMIT ? OFFSET ?`;
    params.push(parseInt(limit), parseInt(offset));
    
    const result = await db.query(query, params);
    
    // Process hashtags from JSON string to array
    const reels = result.map(reel => ({
      ...reel,
      hashtags: reel.hashtags ? JSON.parse(reel.hashtags) : [],
      likes: reel.likes_count || 0,
      comments_count: reel.comments_count || 0,
      shares: reel.shares_count || 0,
      user_liked: reel.user_liked === 1
    }));
    
    res.json({ success: true, reels });
  } catch (error) {
    console.error('Error fetching reels feed:', error);
    res.status(500).json({ error: 'Failed to fetch reels feed' });
  }
});

// Get all reels (fallback endpoint)
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT r.*, u.name as creator_name, u.profile_image_url as creator_avatar,
             COUNT(DISTINCT rl.id) as likes_count,
             COUNT(DISTINCT rc.id) as comments_count,
             COUNT(DISTINCT rs.id) as shares_count
      FROM study_reels r 
      JOIN users u ON r.user_id = u.id 
      LEFT JOIN reel_likes rl ON rl.reel_id = r.id
      LEFT JOIN reel_comments rc ON rc.reel_id = r.id
      LEFT JOIN reel_shares rs ON rs.reel_id = r.id
      WHERE r.is_public = 1
      GROUP BY r.id
      ORDER BY r.created_at DESC
    `);
    
    const reels = result.map(reel => ({
      ...reel,
      hashtags: reel.hashtags ? JSON.parse(reel.hashtags) : [],
      likes: reel.likes_count || 0,
      comments_count: reel.comments_count || 0,
      shares: reel.shares_count || 0
    }));
    
    res.json(reels);
  } catch (error) {
    console.error('Error fetching reels:', error);
    res.status(500).json({ error: 'Failed to fetch reels' });
  }
});

// Get user's reels
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 20, offset = 0 } = req.query;
    
    const result = await db.query(`
      SELECT r.*, u.name as creator_name, u.profile_image_url as creator_avatar,
             COUNT(DISTINCT rl.id) as likes_count,
             COUNT(DISTINCT rc.id) as comments_count,
             COUNT(DISTINCT rs.id) as shares_count
      FROM study_reels r 
      JOIN users u ON r.user_id = u.id 
      LEFT JOIN reel_likes rl ON rl.reel_id = r.id
      LEFT JOIN reel_comments rc ON rc.reel_id = r.id
      LEFT JOIN reel_shares rs ON rs.reel_id = r.id
      WHERE r.user_id = ?
      GROUP BY r.id
      ORDER BY r.created_at DESC
      LIMIT ? OFFSET ?
    `, [userId, parseInt(limit), parseInt(offset)]);
    
    const reels = result.map(reel => ({
      ...reel,
      hashtags: reel.hashtags ? JSON.parse(reel.hashtags) : [],
      likes: reel.likes_count || 0,
      comments_count: reel.comments_count || 0,
      shares: reel.shares_count || 0
    }));
    
    res.json({ success: true, reels });
  } catch (error) {
    console.error('Error fetching user reels:', error);
    res.status(500).json({ error: 'Failed to fetch user reels' });
  }
});

// Create new reel
router.post('/create', upload.single('video'), async (req, res) => {
  try {
    const { userId, title, description, hashtags, isPublic = 'true' } = req.body;
    
    if (!req.file || !userId || !title) {
      return res.status(400).json({ error: 'Missing required fields: video, userId, title' });
    }

    const videoUrl = `/uploads/reels/${req.file.filename}`;
    const thumbnailUrl = `/uploads/thumbnails/${req.file.filename}.jpg`;
    
    // Process hashtags
    const hashtagsArray = hashtags ? hashtags.split(' ').filter(tag => tag.startsWith('#')).map(tag => tag.substring(1)) : [];
    const hashtagsJson = JSON.stringify(hashtagsArray);

    const result = await db.query(`
      INSERT INTO study_reels (user_id, title, description, video_url, thumbnail_url, hashtags, is_public)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [userId, title, description || '', videoUrl, thumbnailUrl, hashtagsJson, isPublic === 'true']);

    res.status(201).json({
      success: true,
      reel: {
        id: result.lastID,
        user_id: userId,
        title,
        description: description || '',
        video_url: videoUrl,
        thumbnail_url: thumbnailUrl,
        hashtags: hashtagsArray,
        is_public: isPublic === 'true'
      }
    });
  } catch (error) {
    console.error('Error creating reel:', error);
    res.status(500).json({ error: 'Failed to create reel' });
  }
});

// Like/unlike reel
router.post('/:reelId/like', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Check if already liked
    const existingLike = await db.query(
      `SELECT id FROM reel_likes WHERE reel_id = ? AND user_id = ?`,
      [reelId, userId]
    );

    if (existingLike.length > 0) {
      // Unlike
      await db.query(
        `DELETE FROM reel_likes WHERE reel_id = ? AND user_id = ?`,
        [reelId, userId]
      );
      
      await db.query(
        `UPDATE study_reels SET likes = likes - 1 WHERE id = ? AND likes > 0`,
        [reelId]
      );
      
      res.json({ success: true, liked: false });
    } else {
      // Like
      await db.query(
        `INSERT INTO reel_likes (reel_id, user_id) VALUES (?, ?)`, 
        [reelId, userId]
      );

      await db.query(
        `UPDATE study_reels SET likes = likes + 1 WHERE id = ?`,
        [reelId]
      );
      
      res.json({ success: true, liked: true });
    }
  } catch (error) {
    console.error('Error toggling reel like:', error);
    res.status(500).json({ error: 'Failed to toggle like' });
  }
});

// Unlike reel (DELETE endpoint)
router.delete('/:reelId/like', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.body;
    
    await db.query(
      `DELETE FROM reel_likes WHERE reel_id = ? AND user_id = ?`,
      [reelId, userId]
    );

    await db.query(
      `UPDATE study_reels SET likes = likes - 1 WHERE id = ? AND likes > 0`,
      [reelId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error unliking reel:', error);
    res.status(500).json({ error: 'Failed to unlike reel' });
  }
});

// Comment on reel
router.post('/:reelId/comments', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId, comment } = req.body;
    
    if (!userId || !comment) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await db.query(`
      INSERT INTO reel_comments (reel_id, user_id, comment)
      VALUES (?, ?, ?)
    `, [reelId, userId, comment]);

    // Update comment count
    await db.query(
      `UPDATE study_reels SET comments_count = comments_count + 1 WHERE id = ?`,
      [reelId]
    );

    res.status(201).json({ success: true, id: result.lastID });
  } catch (error) {
    console.error('Error commenting on reel:', error);
    res.status(500).json({ error: 'Failed to comment on reel' });
  }
});

// Get comments for reel
router.get('/:reelId/comments', async (req, res) => {
  try {
    const { reelId } = req.params;

    const result = await db.query(`
      SELECT rc.*, u.name as user_name, u.profile_image_url as user_avatar
      FROM reel_comments rc
      JOIN users u ON rc.user_id = u.id
      WHERE rc.reel_id = ?
      ORDER BY rc.created_at DESC
    `, [reelId]);

    res.json(result);
  } catch (error) {
    console.error('Error fetching reel comments:', error);
    res.status(500).json({ error: 'Failed to fetch reel comments' });
  }
});

// Share reel
router.post('/:reelId/share', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId, platform = 'unknown' } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    await db.query(`
      INSERT INTO reel_shares (reel_id, user_id, platform)
      VALUES (?, ?, ?)
    `, [reelId, userId, platform]);

    // Update share count
    await db.query(
      `UPDATE study_reels SET shares = shares + 1 WHERE id = ?`,
      [reelId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error sharing reel:', error);
    res.status(500).json({ error: 'Failed to share reel' });
  }
});

// Increment view count
router.post('/:reelId/view', async (req, res) => {
  try {
    const { reelId } = req.params;
    
    await db.query(
      `UPDATE study_reels SET views = views + 1 WHERE id = ?`,
      [reelId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error incrementing view:', error);
    res.status(500).json({ error: 'Failed to increment view' });
  }
});

// Get single reel
router.get('/:reelId', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.query;

    const result = await db.query(`
      SELECT r.*, u.name as creator_name, u.profile_image_url as creator_avatar,
             COUNT(DISTINCT rl.id) as likes_count,
             COUNT(DISTINCT rc.id) as comments_count,
             COUNT(DISTINCT rs.id) as shares_count,
             CASE WHEN ul.id IS NOT NULL THEN 1 ELSE 0 END as user_liked
      FROM study_reels r 
      JOIN users u ON r.user_id = u.id 
      LEFT JOIN reel_likes rl ON rl.reel_id = r.id
      LEFT JOIN reel_comments rc ON rc.reel_id = r.id
      LEFT JOIN reel_shares rs ON rs.reel_id = r.id
      LEFT JOIN reel_likes ul ON ul.reel_id = r.id AND ul.user_id = ?
      WHERE r.id = ?
      GROUP BY r.id
    `, [userId || null, reelId]);

    if (result.length === 0) {
      return res.status(404).json({ error: 'Reel not found' });
    }

    const reel = {
      ...result[0],
      hashtags: result[0].hashtags ? JSON.parse(result[0].hashtags) : [],
      likes: result[0].likes_count || 0,
      comments_count: result[0].comments_count || 0,
      shares: result[0].shares_count || 0,
      user_liked: result[0].user_liked === 1
    };

    res.json(reel);
  } catch (error) {
    console.error('Error fetching reel:', error);
    res.status(500).json({ error: 'Failed to fetch reel' });
  }
});

// Delete reel
router.delete('/:reelId', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId' });
    }

    // Check if user owns the reel
    const reel = await db.query(
      `SELECT user_id, video_url FROM study_reels WHERE id = ?`,
      [reelId]
    );

    if (reel.length === 0) {
      return res.status(404).json({ error: 'Reel not found' });
    }

    if (reel[0].user_id !== userId) {
      return res.status(403).json({ error: 'Not authorized to delete this reel' });
    }

    // Delete the reel (cascading deletes will handle likes, comments, shares)
    await db.query(`DELETE FROM study_reels WHERE id = ?`, [reelId]);

    // Optionally delete the video file
    try {
      const videoPath = path.join(__dirname, '../../', reel[0].video_url);
      if (fs.existsSync(videoPath)) {
        fs.unlinkSync(videoPath);
      }
    } catch (fileError) {
      console.warn('Could not delete video file:', fileError);
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting reel:', error);
    res.status(500).json({ error: 'Failed to delete reel' });
  }
});

// Get trending hashtags
router.get('/trending-hashtags', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT hashtags FROM study_reels 
      WHERE hashtags IS NOT NULL AND hashtags != '[]' 
      AND created_at > datetime('now', '-7 days')
      ORDER BY (likes + views + shares) DESC
      LIMIT 100
    `);
    
    const hashtagCounts = {};
    
    result.forEach(row => {
      try {
        const hashtags = JSON.parse(row.hashtags);
        hashtags.forEach(tag => {
          hashtagCounts[tag] = (hashtagCounts[tag] || 0) + 1;
        });
      } catch (e) {
        // Skip invalid JSON
      }
    });
    
    const trendingHashtags = Object.entries(hashtagCounts)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 20)
      .map(([tag, count]) => ({ tag, count }));
    
    res.json({ hashtags: trendingHashtags });
  } catch (error) {
    console.error('Error fetching trending hashtags:', error);
    res.status(500).json({ error: 'Failed to fetch trending hashtags' });
  }
});

module.exports = router;
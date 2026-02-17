const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const db = require('../db');
const GeminiService = require('../services/geminiService');

// Configure multer for video uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadsDir = path.join(__dirname, '../uploads/reels');
    await fs.mkdir(uploadsDir, { recursive: true });
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept video files
    if (file.mimetype.startsWith('video/')) {
      cb(null, true);
    } else {
      cb(new Error('Only video files are allowed!'), false);
    }
  }
});

// Create a new study reel
router.post('/create', upload.single('video'), async (req, res) => {
  try {
    const { userId, title, description, hashtags, isPublic = true } = req.body;
    
    if (!userId || !req.file) {
      return res.status(400).json({ error: 'User ID and video file are required' });
    }

    const videoPath = '/uploads/reels/' + req.file.filename;
    
    // AI analyze video content for educational value
    let aiAnalysis = null;
    try {
      const analysisResult = await GeminiService.analyzeVideo(videoPath, {
        purpose: 'educational',
        extractConcepts: true,
        suggestTags: true,
        generateSummary: true
      });
      
      if (analysisResult.success) {
        aiAnalysis = analysisResult;
      }
    } catch (error) {
      console.error('Video analysis failed:', error);
      // Continue without AI analysis
    }

    const result = await db.query(
      `INSERT INTO study_reels (
        user_id, title, description, video_url, thumbnail_url, 
        hashtags, views, likes, shares, comments_count,
        ai_analysis, is_public, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW()) RETURNING *`,
      [
        userId,
        title || 'Untitled Study Reel',
        description || '',
        videoPath,
        '/uploads/reels/thumb-' + req.file.filename, // Will be generated later
        hashtags ? hashtags.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0) : [],
        0, // views
        0, // likes  
        0, // shares
        0, // comments_count
        JSON.stringify(aiAnalysis),
        isPublic === 'true',
      ]
    );

    res.status(201).json({
      success: true,
      reel: result.rows[0],
      aiAnalysis: aiAnalysis
    });
  } catch (error) {
    console.error('Create Reel Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get reels feed
router.get('/feed', async (req, res) => {
  try {
    const { 
      limit = 20, 
      offset = 0, 
      userId, 
      hashtags,
      trending = false 
    } = req.query;

    let query = `
      SELECT sr.*, u.name, u.profile_image_url, 
      EXISTS(SELECT 1 FROM reel_likes WHERE reel_id = sr.id AND user_id = $1) as user_liked,
      EXISTS(SELECT 1 FROM user_following WHERE follower_id = sr.user_id AND following_id = $1) as user_following
      FROM study_reels sr
      JOIN users u ON sr.user_id = u.id
      WHERE sr.is_public = true
    `;
    
    const params = [];
    
    if (userId) {
      query += ` AND sr.user_id = $${params.length + 1}`;
      params.push(userId);
    }
    
    if (hashtags) {
      const tagList = hashtags.split(',').map(tag => tag.trim());
      query += ` AND EXISTS (
        SELECT 1 FROM json_array_elements_text(sr.hashtags) 
        WHERE value IN (${tagList.map(() => '?').join(', ')})
      )`;
      params.push(...tagList);
    }
    
    if (trending === 'true') {
      query += ` ORDER BY sr.views DESC, sr.likes DESC`;
    } else {
      query += ` ORDER BY sr.created_at DESC`;
    }
    
    query += ` LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(parseInt(limit), parseInt(offset));

    const result = await db.query(query, params);
    
    res.json({
      success: true,
      reels: result.rows.map(reel => ({
        ...reel,
        ai_analysis: reel.ai_analysis ? JSON.parse(reel.ai_analysis) : null,
        user_liked: reel.user_liked,
        user_following: reel.user_following,
      }))
    });
  } catch (error) {
    console.error('Get Feed Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single reel with comments
router.get('/:reelId', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.query;

    // Get reel details
    const reelResult = await db.query(
      `SELECT sr.*, u.name, u.profile_image_url FROM study_reels sr 
       JOIN users u ON sr.user_id = u.id WHERE sr.id = $1`,
      [reelId]
    );

    if (reelResult.rows.length === 0) {
      return res.status(404).json({ error: 'Reel not found' });
    }

    const reel = {
      ...reelResult.rows[0],
      ai_analysis: reelResult.rows[0].ai_analysis ? JSON.parse(reelResult.rows[0].ai_analysis) : null,
    };

    // Get comments
    const commentsResult = await db.query(
      `SELECT rc.*, u.name, u.profile_image_url FROM reel_comments rc
       JOIN users u ON rc.user_id = u.id WHERE rc.reel_id = $1 ORDER BY rc.created_at DESC`,
      [reelId]
    );

    // Check if user liked this reel
    let userLiked = false;
    if (userId) {
      const likeResult = await db.query(
        'SELECT 1 FROM reel_likes WHERE reel_id = $1 AND user_id = $2',
        [reelId, userId]
      );
      userLiked = likeResult.rows.length > 0;
    }

    res.json({
      success: true,
      reel,
      comments: commentsResult.rows,
      userLiked
    });
  } catch (error) {
    console.error('Get Reel Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Like/unlike reel
router.post('/:reelId/like', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Check if already liked
    const existingLike = await db.query(
      'SELECT 1 FROM reel_likes WHERE reel_id = $1 AND user_id = $2',
      [reelId, userId]
    );

    if (existingLike.rows.length > 0) {
      // Unlike
      await db.query(
        'DELETE FROM reel_likes WHERE reel_id = $1 AND user_id = $2',
        [reelId, userId]
      );
      
      await db.query(
        'UPDATE study_reels SET likes = likes - 1 WHERE id = $1',
        [reelId]
      );

      res.json({ success: true, liked: false });
    } else {
      // Like
      await db.query(
        'INSERT INTO reel_likes (reel_id, user_id, created_at) VALUES ($1, $2, NOW())',
        [reelId, userId]
      );
      
      await db.query(
        'UPDATE study_reels SET likes = likes + 1 WHERE id = $1',
        [reelId]
      );

      res.json({ success: true, liked: true });
    }
  } catch (error) {
    console.error('Like Reel Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Add comment
router.post('/:reelId/comments', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId, comment } = req.body;

    if (!userId || !comment) {
      return res.status(400).json({ error: 'User ID and comment are required' });
    }

    const result = await db.query(
      `INSERT INTO reel_comments (reel_id, user_id, comment, created_at) 
       VALUES ($1, $2, $3, NOW()) RETURNING *`,
      [reelId, userId, comment]
    );

    // Update comment count
    await db.query(
      'UPDATE study_reels SET comments_count = comments_count + 1 WHERE id = $1',
      [reelId]
    );

    res.status(201).json({
      success: true,
      comment: result.rows[0]
    });
  } catch (error) {
    console.error('Add Comment Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Share reel
router.post('/:reelId/share', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId, platform } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Track share
    await db.query(
      'INSERT INTO reel_shares (reel_id, user_id, platform, created_at) VALUES ($1, $2, $3, NOW())',
      [reelId, userId, platform || 'unknown']
    );

    // Update share count
    await db.query(
      'UPDATE study_reels SET shares = shares + 1 WHERE id = $1',
      [reelId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Share Reel Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get user's reels
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 20, offset = 0 } = req.query;

    const result = await db.query(
      `SELECT sr.*, u.name, u.profile_image_url FROM study_reels sr
       JOIN users u ON sr.user_id = u.id 
       WHERE sr.user_id = $1 
       ORDER BY sr.created_at DESC 
       LIMIT $2 OFFSET $3`,
      [userId, parseInt(limit), parseInt(offset)]
    );

    res.json({
      success: true,
      reels: result.rows.map(reel => ({
        ...reel,
        ai_analysis: reel.ai_analysis ? JSON.parse(reel.ai_analysis) : null,
      }))
    });
  } catch (error) {
    console.error('Get User Reels Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get trending hashtags
router.get('/trending-hashtags', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT 
        value as hashtag, 
        COUNT(*) as usage_count
      FROM json_array_elements_text(hashtags)
      WHERE value IS NOT NULL AND value != ''
      GROUP BY value 
      ORDER BY usage_count DESC 
      LIMIT 20
    `);

    res.json({
      success: true,
      hashtags: result.rows
    });
  } catch (error) {
    console.error('Trending Hashtags Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Increment view count
router.post('/:reelId/view', async (req, res) => {
  try {
    const { reelId } = req.params;

    await db.query(
      'UPDATE study_reels SET views = views + 1 WHERE id = $1',
      [reelId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('View Reel Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete reel
router.delete('/:reelId', async (req, res) => {
  try {
    const { reelId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Check if user owns this reel
    const reelResult = await db.query(
      'SELECT user_id FROM study_reels WHERE id = $1',
      [reelId]
    );

    if (reelResult.rows.length === 0 || reelResult.rows[0].user_id !== userId) {
      return res.status(403).json({ error: 'You can only delete your own reels' });
    }

    // Delete reel (cascade will handle likes, comments, shares)
    await db.query('DELETE FROM study_reels WHERE id = $1', [reelId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Delete Reel Error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
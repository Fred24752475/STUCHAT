const express = require('express');
const router = express.Router();
const db = require('../db');

// Get active stories (not expired)
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT s.*, u.name as user_name, u.profile_image_url,
             (SELECT COUNT(*) FROM story_views WHERE story_id = s.id) as view_count
      FROM stories s
      JOIN users u ON s.user_id = u.id
      WHERE s.expires_at > NOW()
      ORDER BY s.created_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get stories by user
router.get('/user/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await db.query(`
      SELECT s.*,
             (SELECT COUNT(*) FROM story_views WHERE story_id = s.id) as view_count
      FROM stories s
      WHERE s.user_id = $1 AND s.expires_at > datetime('now')
      ORDER BY s.created_at DESC
    `, [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create story
router.post('/', async (req, res) => {
  const { userId, imageUrl, videoUrl, content } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO stories (user_id, image_url, video_url, content) VALUES ($1, $2, $3, $4) RETURNING *',
      [userId, imageUrl, videoUrl, content]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// View a story
router.post('/:storyId/view', async (req, res) => {
  const { storyId } = req.params;
  const { userId } = req.body;
  try {
    // Add view (will ignore if already viewed due to UNIQUE constraint)
    await db.query(
      'INSERT OR IGNORE INTO story_views (story_id, user_id) VALUES ($1, $2)',
      [storyId, userId]
    );
    
    // Update view count
    await db.query('UPDATE stories SET views = views + 1 WHERE id = $1', [storyId]);
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get story viewers
router.get('/:storyId/viewers', async (req, res) => {
  const { storyId } = req.params;
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, sv.viewed_at
      FROM story_views sv
      JOIN users u ON sv.user_id = u.id
      WHERE sv.story_id = $1
      ORDER BY sv.viewed_at DESC
    `, [storyId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete story
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM stories WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add comment to story
router.post('/:storyId/comments', async (req, res) => {
  const { storyId } = req.params;
  const { userId, text } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO story_comments (story_id, user_id, text) VALUES ($1, $2, $3) RETURNING *',
      [storyId, userId, text]
    );
    
    // Get user info
    const user = await db.query('SELECT name, profile_image_url FROM users WHERE id = $1', [userId]);
    const comment = {
      ...result.rows[0],
      user_name: user.rows[0].name,
      profile_image_url: user.rows[0].profile_image_url
    };
    
    res.status(201).json(comment);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get story comments
router.get('/:storyId/comments', async (req, res) => {
  const { storyId } = req.params;
  try {
    const result = await db.query(`
      SELECT sc.*, u.name as user_name, u.profile_image_url
      FROM story_comments sc
      JOIN users u ON sc.user_id = u.id
      WHERE sc.story_id = $1
      ORDER BY sc.created_at ASC
    `, [storyId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add reaction to story
router.post('/:storyId/reactions', async (req, res) => {
  const { storyId } = req.params;
  const { userId, reactionType } = req.body;
  try {
    await db.query(
      'INSERT OR REPLACE INTO story_reactions (story_id, user_id, reaction_type) VALUES ($1, $2, $3)',
      [storyId, userId, reactionType]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get story reactions
router.get('/:storyId/reactions', async (req, res) => {
  const { storyId } = req.params;
  try {
    const result = await db.query(`
      SELECT sr.reaction_type, COUNT(*) as count
      FROM story_reactions sr
      WHERE sr.story_id = $1
      GROUP BY sr.reaction_type
    `, [storyId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

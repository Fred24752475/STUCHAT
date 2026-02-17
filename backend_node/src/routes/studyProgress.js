const express = require('express');
const router = express.Router();
const StudyProgressService = require('../services/studyProgressService');

// Track study session
router.post('/track-session', async (req, res) => {
  try {
    const { userId, duration, subject, topics, score } = req.body;

    if (!userId || !duration) {
      return res.status(400).json({ error: 'User ID and duration are required' });
    }

    const result = await StudyProgressService.trackStudySession(userId, {
      duration: parseInt(duration),
      subject,
      topics: topics || [],
      score: score ? parseFloat(score) : null,
    });

    res.json(result);
  } catch (error) {
    console.error('Track Session Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get study statistics
router.get('/statistics/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await StudyProgressService.getStudyStatistics(userId);
    res.json({
      success: true,
      statistics: result,
    });
  } catch (error) {
    console.error('Get Statistics Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const { type = 'weekly', limit = 10 } = req.query;
    const result = await StudyProgressService.getLeaderboard(type, parseInt(limit));
    res.json(result);
  } catch (error) {
    console.error('Get Leaderboard Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Check and award achievements
router.post('/check-achievements/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await StudyProgressService.checkAchievements(userId);
    res.json(result);
  } catch (error) {
    console.error('Check Achievements Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get study goals
router.get('/goals/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await StudyProgressService.getStudyGoals(userId);
    res.json(result);
  } catch (error) {
    console.error('Get Goals Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Set study goal
router.post('/goals', async (req, res) => {
  try {
    const { userId, type, target, timeframe, subject } = req.body;

    if (!userId || !type || !target || !timeframe) {
      return res.status(400).json({ 
        error: 'User ID, type, target, and timeframe are required' 
      });
    }

    const result = await StudyProgressService.setStudyGoal(userId, {
      type,
      target: parseInt(target),
      timeframe,
      subject,
    });

    res.json(result);
  } catch (error) {
    console.error('Set Goal Error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
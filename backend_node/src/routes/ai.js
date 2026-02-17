const express = require('express');
const router = express.Router();
const GeminiService = require('../services/geminiService');
const db = require('../db');

// Store conversation history in database
router.post('/chat', async (req, res) => {
  try {
    const { userId, message, mode = 'general', conversationId } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }

    // Get conversation history if conversationId provided
    let messages = [];
    if (conversationId) {
      const history = await db.query(
        'SELECT role, content FROM ai_conversations WHERE conversation_id = $1 ORDER BY created_at ASC LIMIT 20',
        [conversationId]
      );
      messages = history.rows.map(row => ({
        role: row.role,
        content: row.content,
      }));
    }

    // Add user message
    messages.push({ role: 'user', content: message });

    // Get AI response
    const response = await GeminiService.chat(messages, mode);

    if (!response.success) {
      const statusCode = response.errorType === 'quota_exceeded' || response.errorType === 'rate_limit' ? 429 : 500;
      return res.status(statusCode).json({ 
        error: response.error,
        errorType: response.errorType 
      });
    }

    // Generate conversation ID if new
    const convId = conversationId || `conv_${Date.now()}_${userId}`;

    // Save to database
    await db.query(
      'INSERT INTO ai_conversations (conversation_id, user_id, role, content, mode) VALUES ($1, $2, $3, $4, $5)',
      [convId, userId, 'user', message, mode]
    );

    await db.query(
      'INSERT INTO ai_conversations (conversation_id, user_id, role, content, mode) VALUES ($1, $2, $3, $4, $5)',
      [convId, userId, 'assistant', response.message, mode]
    );

    res.json({
      success: true,
      message: response.message,
      conversationId: convId,
    });
  } catch (error) {
    console.error('Chat Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Generate flashcards
router.post('/flashcards', async (req, res) => {
  try {
    const { text, count = 10 } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }

    const result = await GeminiService.generateFlashcards(text, count);

    if (!result.success) {
      return res.status(500).json({ error: result.error });
    }

    res.json(result);
  } catch (error) {
    console.error('Flashcards Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Summarize text
router.post('/summarize', async (req, res) => {
  try {
    const { text, length = 'medium' } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }

    const result = await GeminiService.summarize(text, length);

    if (!result.success) {
      return res.status(500).json({ error: result.error });
    }

    res.json(result);
  } catch (error) {
    console.error('Summarize Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Solve homework
router.post('/homework', async (req, res) => {
  try {
    const { problem, subject } = req.body;

    if (!problem) {
      return res.status(400).json({ error: 'Problem is required' });
    }

    const result = await GeminiService.solveHomework(problem, subject || 'General');

    if (!result.success) {
      return res.status(500).json({ error: result.error });
    }

    res.json(result);
  } catch (error) {
    console.error('Homework Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Essay help
router.post('/essay', async (req, res) => {
  try {
    const { text, helpType = 'feedback' } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Essay text is required' });
    }

    const result = await GeminiService.helpWithEssay(text, helpType);

    if (!result.success) {
      return res.status(500).json({ error: result.error });
    }

    res.json(result);
  } catch (error) {
    console.error('Essay Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Generate practice questions
router.post('/questions', async (req, res) => {
  try {
    const { topic, count = 5, difficulty = 'medium' } = req.body;

    if (!topic) {
      return res.status(400).json({ error: 'Topic is required' });
    }

    const result = await GeminiService.generateQuestions(topic, count, difficulty);

    if (!result.success) {
      return res.status(500).json({ error: result.error });
    }

    res.json(result);
  } catch (error) {
    console.error('Questions Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Explain concept
router.post('/explain', async (req, res) => {
  try {
    const { concept, level = 'college' } = req.body;

    if (!concept) {
      return res.status(400).json({ error: 'Concept is required' });
    }

    const result = await GeminiService.explainConcept(concept, level);

    if (!result.success) {
      return res.status(500).json({ error: result.error });
    }

    res.json(result);
  } catch (error) {
    console.error('Explain Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get conversation history
router.get('/conversations/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const conversations = await db.query(`
      SELECT DISTINCT conversation_id, mode, 
             MIN(created_at) as started_at,
             MAX(created_at) as last_message_at,
             COUNT(*) as message_count
      FROM ai_conversations
      WHERE user_id = $1
      GROUP BY conversation_id, mode
      ORDER BY last_message_at DESC
      LIMIT 50
    `, [userId]);

    res.json(conversations.rows);
  } catch (error) {
    console.error('Conversations Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get specific conversation
router.get('/conversation/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;

    const messages = await db.query(`
      SELECT role, content, created_at
      FROM ai_conversations
      WHERE conversation_id = $1
      ORDER BY created_at ASC
    `, [conversationId]);

    res.json(messages.rows);
  } catch (error) {
    console.error('Conversation Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete conversation
router.delete('/conversation/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;

    await db.query('DELETE FROM ai_conversations WHERE conversation_id = $1', [conversationId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Delete Conversation Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// AI Study Buddy Pro - Enhanced homework problem solving
router.post('/homework-problem', async (req, res) => {
  try {
    const { userId, problemText, mode = 'scan', conversationId } = req.body;

    if (!problemText) {
      return res.status(400).json({ error: 'Problem text is required' });
    }

    // Get conversation history if conversationId provided
    let messages = [];
    if (conversationId) {
      const history = await db.query(
        'SELECT role, content FROM ai_conversations WHERE conversation_id = $1 ORDER BY created_at ASC LIMIT 20',
        [conversationId]
      );
      messages = history.rows.map(row => ({
        role: row.role,
        content: row.content,
      }));
    }

    // Add problem text as user message
    messages.push({ role: 'user', content: problemText });

    // Get AI response with enhanced problem-solving capabilities
    const response = await GeminiService.solveHomeworkPro(problemText, mode, messages);

    if (!response.success) {
      const statusCode = response.errorType === 'quota_exceeded' || response.errorType === 'rate_limit' ? 429 : 500;
      return res.status(statusCode).json({ 
        error: response.error,
        errorType: response.errorType 
      });
    }

    // Generate conversation ID if new
    const convId = conversationId || `conv_${Date.now()}_${userId}`;

    // Save to database
    await db.query(
      'INSERT INTO ai_conversations (conversation_id, user_id, role, content, mode) VALUES ($1, $2, $3, $4, $5)',
      [convId, userId, 'user', problemText, mode]
    );

    await db.query(
      'INSERT INTO ai_conversations (conversation_id, user_id, role, content, mode) VALUES ($1, $2, $3, $4, $5)',
      [convId, userId, 'assistant', response.message, mode]
    );

    res.json({
      success: true,
      solution: response.message,
      conversationId: convId,
    });
  } catch (error) {
    console.error('Homework Problem Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// AI Study Buddy Pro - Generate study schedule
router.post('/study-schedule', async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Get user's study preferences and current schedule
    const preferencesQuery = await db.query(
      'SELECT preferences FROM user_preferences WHERE user_id = $1',
      [userId]
    );

    const preferences = preferencesQuery.rows[0]?.preferences || {};
    
    // Get user's recent study activity
    const activityQuery = await db.query(
      'SELECT study_session_data FROM study_analytics WHERE user_id = $1 ORDER BY session_date DESC LIMIT 7',
      [userId]
    );

    const recentActivity = activityQuery.rows;

    // Generate personalized study schedule
    const response = await GeminiService.generateStudySchedule(preferences, recentActivity);

    if (!response.success) {
      return res.status(500).json({ error: response.error });
    }

    // Save generated schedule to database
    await db.query(
      'INSERT INTO study_schedules (user_id, schedule_data, created_at) VALUES ($1, $2, NOW()) RETURNING id',
      [userId, response.schedule]
    );

    res.json({
      success: true,
      schedule: response.schedule,
    });
  } catch (error) {
    console.error('Study Schedule Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// AI Study Buddy Pro - Generate practice quiz
router.post('/generate-quiz', async (req, res) => {
  try {
    const { userId, topic, difficulty = 'medium', questionCount = 10 } = req.body;

    if (!topic) {
      return res.status(400).json({ error: 'Topic is required' });
    }

    // Get user's quiz history to adapt difficulty
    const quizHistoryQuery = await db.query(
      'SELECT score, difficulty FROM quiz_results WHERE user_id = $1 AND topic = $2 ORDER BY created_at DESC LIMIT 5',
      [userId, topic]
    );

    const quizHistory = quizHistoryQuery.rows;
    const avgScore = quizHistory.reduce((sum, quiz) => sum + quiz.score, 0) / (quizHistory.length || 1);

    // Adjust difficulty based on performance
    let adaptiveDifficulty = difficulty;
    if (avgScore > 85 && difficulty === 'medium') {
      adaptiveDifficulty = 'hard';
    } else if (avgScore < 60 && difficulty === 'medium') {
      adaptiveDifficulty = 'easy';
    }

    const response = await GeminiService.generatePracticeQuiz(topic, adaptiveDifficulty, questionCount, avgScore);

    if (!response.success) {
      return res.status(500).json({ error: response.error });
    }

    // Save quiz to database
    const quizResult = await db.query(
      'INSERT INTO practice_quizzes (user_id, topic, difficulty, questions, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id',
      [userId, topic, adaptiveDifficulty, response.quiz]
    );

    res.json({
      success: true,
      quizId: quizResult.rows[0].id,
      quiz: response.quiz,
      difficulty: adaptiveDifficulty,
      adaptiveMessage: avgScore > 85 ? 'Great job! Trying harder questions.' : avgScore < 60 ? 'Let\'s build confidence with easier questions.' : 'Perfect difficulty for you!',
    });
  } catch (error) {
    console.error('Generate Quiz Error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

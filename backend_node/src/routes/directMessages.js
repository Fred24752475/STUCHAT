const express = require('express');
const router = express.Router();
const db = require('../db');

// Get conversations for a user
router.get('/conversations/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const messages = await db.query(`
      SELECT 
        dm.*,
        CASE 
          WHEN dm.sender_id = $1 THEN dm.receiver_id
          ELSE dm.sender_id
        END as other_user_id
      FROM direct_messages dm
      WHERE dm.sender_id = $1 OR dm.receiver_id = $1
      ORDER BY dm.created_at DESC
    `, [userId]);

    const conversationsMap = new Map();
    
    for (const msg of messages.rows) {
      const otherUserId = msg.other_user_id;
      
      if (!conversationsMap.has(otherUserId)) {
        const userResult = await db.query(
          'SELECT id, name, profile_image_url FROM users WHERE id = $1',
          [otherUserId]
        );
        
        if (userResult.rows.length > 0) {
          const user = userResult.rows[0];
          
          const unreadResult = await db.query(
            'SELECT COUNT(*) as count FROM direct_messages WHERE sender_id = $1 AND receiver_id = $2 AND is_read = 0',
            [otherUserId, userId]
          );
          
          conversationsMap.set(otherUserId, {
            other_user_id: otherUserId,
            name: user.name,
            profile_image_url: user.profile_image_url,
            last_message: msg.content,
            last_message_time: msg.created_at,
            unread_count: unreadResult.rows[0].count || 0
          });
        }
      }
    }
    
    const conversations = Array.from(conversationsMap.values());
    res.json(conversations);
  } catch (err) {
    console.error('Error in /conversations:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get messages between two users
router.get('/:userId1/:userId2', async (req, res) => {
  const { userId1, userId2 } = req.params;
  try {
    const result = await db.query(`
      SELECT dm.*, 
             sender.name as sender_name, 
             sender.profile_image_url as sender_image
      FROM direct_messages dm
      JOIN users sender ON dm.sender_id = sender.id
      WHERE (dm.sender_id = $1 AND dm.receiver_id = $2)
         OR (dm.sender_id = $3 AND dm.receiver_id = $4)
      ORDER BY dm.created_at ASC
    `, [userId1, userId2, userId2, userId1]);
    res.json(result.rows);
  } catch (err) {
    console.error('Error in /messages:', err);
    res.status(500).json({ error: err.message });
  }
});

// Send message
router.post('/', async (req, res) => {
  const { senderId, receiverId, content, fileUrl, messageType = 'text', fileName, audioDuration } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO direct_messages (sender_id, receiver_id, content, file_url, message_type, file_name, audio_duration) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [
        senderId, 
        receiverId, 
        content, 
        fileUrl || null,
        messageType || 'text',
        fileName || null,
        audioDuration || null
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error in /send:', err);
    res.status(500).json({ error: err.message });
  }
});

// Mark messages as read
router.put('/read/:userId1/:userId2', async (req, res) => {
  const { userId1, userId2 } = req.params;
  try {
    await db.query(
      'UPDATE direct_messages SET is_read = 1 WHERE sender_id = $1 AND receiver_id = $2 AND is_read = 0',
      [userId2, userId1]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Error in /read:', err);
    res.status(500).json({ error: err.message });
  }
});

// Delete message
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM direct_messages WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error in /delete:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

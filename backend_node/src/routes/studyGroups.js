const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all study groups
router.get('/', async (req, res) => {
  const { course, search } = req.query;
  try {
    let query = `
      SELECT sg.*, u.name as creator_name,
             (SELECT COUNT(*) FROM study_group_members WHERE group_id = sg.id) as member_count
      FROM study_groups sg
      JOIN users u ON sg.creator_id = u.id
      WHERE 1=1
    `;
    const params = [];

    if (course) {
      query += ' AND sg.course LIKE ?';
      params.push(`%${course}%`);
    }
    if (search) {
      query += ' AND (sg.name LIKE ? OR sg.description LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    query += ' ORDER BY sg.created_at DESC';
    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create study group
router.post('/', async (req, res) => {
  const { name, description, course, creatorId, maxMembers, isPrivate, meetingSchedule } = req.body;
  try {
    const result = await db.query(`
      INSERT INTO study_groups (name, description, course, creator_id, max_members, is_private, meeting_schedule)
      VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING *
    `, [name, description, course, creatorId, maxMembers || 50, isPrivate ? 1 : 0, meetingSchedule]);
    
    const groupId = result.rows[0].id;
    
    // Add creator as admin
    await db.query(
      'INSERT INTO study_group_members (group_id, user_id, role) VALUES (?, ?, ?)',
      [groupId, creatorId, 'admin']
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Join study group
router.post('/:groupId/join', async (req, res) => {
  const { groupId } = req.params;
  const { userId } = req.body;
  try {
    await db.query(
      'INSERT OR IGNORE INTO study_group_members (group_id, user_id) VALUES (?, ?)',
      [groupId, userId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Leave study group
router.delete('/:groupId/leave', async (req, res) => {
  const { groupId } = req.params;
  const { userId } = req.body;
  try {
    await db.query(
      'DELETE FROM study_group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get group members
router.get('/:groupId/members', async (req, res) => {
  const { groupId } = req.params;
  try {
    const result = await db.query(`
      SELECT u.id, u.name, u.profile_image_url, sgm.role, sgm.joined_at
      FROM study_group_members sgm
      JOIN users u ON sgm.user_id = u.id
      WHERE sgm.group_id = ?
      ORDER BY sgm.joined_at
    `, [groupId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

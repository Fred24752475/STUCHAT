const express = require('express');
const router = express.Router();
const db = require('../db');
const QRCode = require('qrcode');

// Generate QR code for profile
router.post('/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const qrData = `stuchat://profile/${userId}`;
    const qrCodeUrl = await QRCode.toDataURL(qrData);

    const result = await db.query(
      `INSERT INTO qr_code_shares (user_id, shareable_type, shareable_id, qr_code_url) 
       VALUES (?, 'profile', ?, ?)`,
      [userId, userId, qrCodeUrl]
    );

    res.status(201).json({ success: true, qrCode: qrCodeUrl });
  } catch (error) {
    console.error('Error generating QR code:', error);
    res.status(500).json({ error: 'Failed to generate QR code' });
  }
});

// Generate QR code for group
router.post('/group/:groupId', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    const qrData = `stuchat://group/${groupId}`;
    const qrCodeUrl = await QRCode.toDataURL(qrData);

    const result = await db.query(
      `INSERT INTO qr_code_shares (user_id, shareable_type, shareable_id, qr_code_url) 
       VALUES (?, 'group', ?, ?)`,
      [userId, groupId, qrCodeUrl]
    );

    res.status(201).json({ success: true, qrCode: qrCodeUrl });
  } catch (error) {
    console.error('Error generating QR code:', error);
    res.status(500).json({ error: 'Failed to generate QR code' });
  }
});

// Generate QR code for study group
router.post('/study-group/:groupId', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    const qrData = `stuchat://study-group/${groupId}`;
    const qrCodeUrl = await QRCode.toDataURL(qrData);

    const result = await db.query(
      `INSERT INTO qr_code_shares (user_id, shareable_type, shareable_id, qr_code_url) 
       VALUES (?, 'study_group', ?, ?)`,
      [userId, groupId, qrCodeUrl]
    );

    res.status(201).json({ success: true, qrCode: qrCodeUrl });
  } catch (error) {
    console.error('Error generating QR code:', error);
    res.status(500).json({ error: 'Failed to generate QR code' });
  }
});

// Generate QR code for event
router.post('/event/:eventId', async (req, res) => {
  try {
    const { eventId } = req.params;
    const { userId } = req.body;

    const qrData = `stuchat://event/${eventId}`;
    const qrCodeUrl = await QRCode.toDataURL(qrData);

    const result = await db.query(
      `INSERT INTO qr_code_shares (user_id, shareable_type, shareable_id, qr_code_url) 
       VALUES (?, 'event', ?, ?)`,
      [userId, eventId, qrCodeUrl]
    );

    res.status(201).json({ success: true, qrCode: qrCodeUrl });
  } catch (error) {
    console.error('Error generating QR code:', error);
    res.status(500).json({ error: 'Failed to generate QR code' });
  }
});

// Scan QR code
router.post('/scan', async (req, res) => {
  try {
    const { qrId } = req.body;

    if (!qrId) {
      return res.status(400).json({ error: 'Missing qrId' });
    }

    // Update scan count
    await db.query(
      `UPDATE qr_code_shares SET scans = scans + 1 WHERE id = ?`,
      [qrId]
    );

    // Get QR code details
    const result = await db.query(
      `SELECT shareable_type, shareable_id FROM qr_code_shares WHERE id = ?`,
      [qrId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'QR code not found' });
    }

    res.json({
      success: true,
      shareableType: result.rows[0].shareable_type,
      shareableId: result.rows[0].shareable_id
    });
  } catch (error) {
    console.error('Error scanning QR code:', error);
    res.status(500).json({ error: 'Failed to scan QR code' });
  }
});

// Get QR code statistics
router.get('/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await db.query(
      `SELECT shareable_type, COUNT(*) as count, SUM(scans) as total_scans 
       FROM qr_code_shares WHERE user_id = ? GROUP BY shareable_type`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching QR statistics:', error);
    res.status(500).json({ error: 'Failed to fetch QR statistics' });
  }
});

module.exports = router;

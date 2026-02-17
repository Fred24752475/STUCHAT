const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const db = require('../db');

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
  fileFilter: (req, file, cb) => {
    // Check file extension
    const allowedExtensions = /\.(jpeg|jpg|png|gif|bmp|webp|svg|mp4|mov|avi|webm|mkv)$/i;
    const hasValidExtension = allowedExtensions.test(file.originalname.toLowerCase());
    
    // Check mimetype
    const isImage = file.mimetype.startsWith('image/');
    const isVideo = file.mimetype.startsWith('video/');
    
    // Accept if either extension is valid OR mimetype is image/video
    if (hasValidExtension || isImage || isVideo) {
      return cb(null, true);
    } else {
      console.log('❌ Rejected file:', file.originalname, 'mimetype:', file.mimetype);
      cb(new Error('Only images and videos are allowed!'));
    }
  }
});

// Upload single file
router.post('/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const { userId } = req.body;
    const fileType = req.file.mimetype.startsWith('image') ? 'image' : 'video';
    const fileUrl = `/uploads/${req.file.filename}`;

    console.log('✅ File uploaded:', req.file.originalname, 'Type:', fileType, 'Size:', req.file.size);

    // Save to database
    const result = await db.query(
      'INSERT INTO media_uploads (user_id, file_path, file_type, file_size) VALUES ($1, $2, $3, $4) RETURNING *',
      [userId, fileUrl, fileType, req.file.size]
    );

    res.json({
      success: true,
      file: {
        id: result.rows[0].id,
        url: fileUrl,
        type: fileType,
        size: req.file.size
      }
    });
  } catch (err) {
    console.error('❌ Upload error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Upload multiple files
router.post('/upload-multiple', upload.array('files', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files uploaded' });
    }

    const { userId } = req.body;
    const uploadedFiles = [];

    for (const file of req.files) {
      const fileType = file.mimetype.startsWith('image') ? 'image' : 'video';
      const fileUrl = `/uploads/${file.filename}`;

      const result = await db.query(
        'INSERT INTO media_uploads (user_id, file_path, file_type, file_size) VALUES ($1, $2, $3, $4) RETURNING *',
        [userId, fileUrl, fileType, file.size]
      );

      uploadedFiles.push({
        id: result.rows[0].id,
        url: fileUrl,
        type: fileType,
        size: file.size
      });
    }

    res.json({ success: true, files: uploadedFiles });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user's uploaded media
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await db.query(
      'SELECT * FROM media_uploads WHERE user_id = $1 ORDER BY uploaded_at DESC',
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Error handling middleware for multer
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    console.error('❌ Multer error:', err.message);
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 50MB.' });
    }
    return res.status(400).json({ error: err.message });
  } else if (err) {
    console.error('❌ Upload error:', err.message);
    return res.status(400).json({ error: err.message });
  }
  next();
});

module.exports = router;

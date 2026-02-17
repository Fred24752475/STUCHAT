const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');

router.post('/register', async (req, res) => {
  const { name, email, password, course, year } = req.body;
  console.log('📝 Register request:', { name, email, course, year });
  
  try {
    // Check if user already exists
    const existingUser = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    if (existingUser.rows.length > 0) {
      console.log('⚠️ Email already exists');
      return res.status(400).json({ error: 'Account with this email already exists. Please login instead.' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('🔒 Password hashed');
    
    const result = await db.query(
      'INSERT INTO users (name, email, password, course, year) VALUES ($1, $2, $3, $4, $5) RETURNING id, name, email, course, year',
      [name, email, hashedPassword, course, year]
    );
    console.log('✅ User created:', result.rows[0]);
    
    const token = jwt.sign({ userId: result.rows[0].id }, process.env.JWT_SECRET || 'default_secret');
    res.status(201).json({ user: result.rows[0], token });
  } catch (err) {
    console.error('❌ Register error:', err);
    if (err.code === 'SQLITE_CONSTRAINT') {
      res.status(400).json({ error: 'Account with this email already exists. Please login instead.' });
    } else {
      res.status(500).json({ error: err.message });
    }
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  console.log('🔑 Login request:', email);
  
  try {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    console.log('📊 Query result:', result.rows.length, 'users found');
    
    if (result.rows.length === 0) {
      console.log('❌ User not found for email:', email);
      return res.status(401).json({ error: 'Invalid email or password. Please check your credentials.' });
    }
    
    const user = result.rows[0];
    console.log('👤 Found user:', { id: user.id, name: user.name, email: user.email });
    
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      console.log('❌ Invalid password');
      return res.status(401).json({ error: 'Invalid email or password. Please check your credentials.' });
    }
    
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET || 'default_secret');
    console.log('✅ Login successful for:', user.email);
    
    res.json({ 
      user: { 
        id: user.id, 
        name: user.name, 
        email: user.email, 
        course: user.course, 
        year: user.year 
      }, 
      token 
    });
  } catch (err) {
    console.error('❌ Login error:', err);
    res.status(500).json({ error: 'Server error. Please try again.' });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const db = require('../db');
const { generateVerificationCode, sendVerificationEmail, sendWelcomeEmail, generateReferralCode } = require('../services/emailService');

// Send verification code
router.post('/send-code', async (req, res) => {
  const { email, name } = req.body;
  
  try {
    const code = generateVerificationCode();
    const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes
    
    await db.query(
      'UPDATE users SET verification_code = $1, verification_expires = $2 WHERE email = $3',
      [code, expires, email]
    );
    
    // Send email (in production, handle errors gracefully)
    const sent = await sendVerificationEmail(email, code, name);
    
    // For development: return the code in the response
    console.log(`📧 Verification code for ${email}: ${code}`);
    res.json({ 
      message: 'Verification code sent to your email',
      code: code // REMOVE THIS IN PRODUCTION!
    });
  } catch (err) {
    console.error('Send code error:', err);
    res.status(500).json({ error: 'Failed to send verification code' });
  }
});

// Verify code
router.post('/verify-code', async (req, res) => {
  const { email, code } = req.body;
  
  try {
    const result = await db.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const user = result.rows[0];
    
    if (user.is_verified) {
      return res.json({ message: 'Account already verified' });
    }
    
    if (user.verification_code !== code) {
      return res.status(400).json({ error: 'Invalid verification code' });
    }
    
    if (new Date() > new Date(user.verification_expires)) {
      return res.status(400).json({ error: 'Verification code expired' });
    }
    
    // Generate referral code
    const referralCode = generateReferralCode(user.name);
    
    // Mark as verified
    await db.query(
      'UPDATE users SET is_verified = 1, referral_code = $1, verification_code = NULL, verification_expires = NULL WHERE email = $2',
      [referralCode, email]
    );
    
    // Send welcome email
    await sendWelcomeEmail(email, user.name, referralCode);
    
    res.json({ 
      message: 'Account verified successfully',
      referralCode
    });
  } catch (err) {
    console.error('Verify code error:', err);
    res.status(500).json({ error: 'Verification failed' });
  }
});

// Resend verification code
router.post('/resend-code', async (req, res) => {
  const { email } = req.body;
  
  try {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const user = result.rows[0];
    
    if (user.is_verified) {
      return res.json({ message: 'Account already verified' });
    }
    
    const code = generateVerificationCode();
    const expires = new Date(Date.now() + 10 * 60 * 1000);
    
    await db.query(
      'UPDATE users SET verification_code = $1, verification_expires = $2 WHERE email = $3',
      [code, expires, email]
    );
    
    await sendVerificationEmail(email, code, user.name);
    console.log(`📧 Resent code for ${email}: ${code}`);
    
    res.json({ message: 'Verification code resent' });
  } catch (err) {
    console.error('Resend code error:', err);
    res.status(500).json({ error: 'Failed to resend code' });
  }
});

module.exports = router;

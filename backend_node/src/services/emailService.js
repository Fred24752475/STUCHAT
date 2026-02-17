// Email service - using nodemailer
let nodemailer;
let transporter = null;

try {
  nodemailer = require('nodemailer');
  // Create transporter (using Gmail for demo)
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER || 'your-email@gmail.com',
      pass: process.env.EMAIL_PASS || 'your-app-password'
    }
  });
} catch (err) {
  console.log('⚠️ Nodemailer not installed. Emails will be logged to console.');
  console.log('To install: npm install nodemailer');
}

// Generate 6-digit verification code
function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Generate unique referral code
function generateReferralCode(name) {
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  const namePrefix = name.substring(0, 3).toUpperCase();
  return `${namePrefix}${random}`;
}

// Send verification email
async function sendVerificationEmail(email, code, name) {
  console.log(`📧 Verification code for ${email}: ${code}`);
  
  if (!transporter) {
    return true; // Return success even without email
  }

  const mailOptions = {
    from: process.env.EMAIL_USER || 'Campus Connect <noreply@campusconnect.com>',
    to: email,
    subject: 'Verify Your Campus Connect Account',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2196F3;">Welcome to Campus Connect, ${name}!</h2>
        <p>Thank you for signing up. Please verify your email address to get started.</p>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
          <h1 style="color: #2196F3; letter-spacing: 5px; margin: 0;">${code}</h1>
        </div>
        <p>Enter this code in the app to verify your account.</p>
        <p style="color: #666; font-size: 12px;">This code will expire in 10 minutes.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        <p style="color: #999; font-size: 11px;">If you didn't create this account, please ignore this email.</p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Email sent to ${email}`);
    return true;
  } catch (error) {
    console.error('Email send error:', error.message);
    return true; // Still return success for development
  }
}

// Send welcome email after verification
async function sendWelcomeEmail(email, name, referralCode) {
  console.log(`🎉 Welcome email for ${email} - Referral code: ${referralCode}`);
  
  if (!transporter) {
    return true;
  }

  const mailOptions = {
    from: process.env.EMAIL_USER || 'Campus Connect <noreply@campusconnect.com>',
    to: email,
    subject: 'Welcome to Campus Connect! 🎉',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2196F3;">You're all set, ${name}!</h2>
        <p>Your account has been verified successfully. Start connecting with your campus community!</p>
        <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="margin-top: 0;">Your Referral Code</h3>
          <p style="font-size: 24px; font-weight: bold; color: #2196F3; margin: 10px 0;">${referralCode}</p>
          <p style="font-size: 14px; color: #666;">Share this code with friends and earn rewards!</p>
        </div>
        <h3>Get Started:</h3>
        <ul>
          <li>Complete your profile</li>
          <li>Find and follow friends</li>
          <li>Join study groups</li>
          <li>Share your first post</li>
        </ul>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Welcome email sent to ${email}`);
    return true;
  } catch (error) {
    console.error('Welcome email error:', error.message);
    return true;
  }
}

module.exports = {
  generateVerificationCode,
  generateReferralCode,
  sendVerificationEmail,
  sendWelcomeEmail
};

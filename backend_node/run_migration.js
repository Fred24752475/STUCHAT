const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:Fred678rick2475@db.usvythgjalhgmjuvxqsa.supabase.co:5432/postgres?sslmode=require',
  ssl: { rejectUnauthorized: false }
});

const sql = `
-- Add your SQL commands here
ALTER TABLE users ADD COLUMN test_column VARCHAR(50);
`;

async function run() {
  try {
    await pool.query(sql);
    console.log('✅ SQL executed successfully');
  } catch (err) {
    console.error('Error:', err.message);
  }
  process.exit();
}

run();

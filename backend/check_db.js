const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');
dotenv.config();

async function main() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'simple_advt',
  });

  const [users] = await pool.query('SELECT id, email, full_name FROM users');
  const [biz] = await pool.query('SELECT business_id, user_id, business_name FROM business_profile');
  const [followed] = await pool.query('SELECT * FROM followed_businesses');
  const [notifs] = await pool.query('SELECT * FROM notifications');

  const out = {
    users,
    biz,
    followed,
    notifs
  };

  const targetPath = path.join(__dirname, 'db_output.json');
  fs.writeFileSync(targetPath, JSON.stringify(out, null, 2));

  await pool.end();
}

main().catch(err => {
  const targetPath = path.join(__dirname, 'db_output.json');
  fs.writeFileSync(targetPath, JSON.stringify({ error: err.message, stack: err.stack }));
});

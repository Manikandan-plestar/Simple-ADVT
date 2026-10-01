const dotenv = require('dotenv');
const mysql = require('mysql2/promise');
dotenv.config();

async function run() {
  const db = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'simple_advt'
  });

  const [users] = await db.query('SELECT id, email, full_name FROM users');
  console.log('USERS:', users);

  const [saved] = await db.query('SELECT * FROM saved_posts');
  console.log('SAVED_POSTS:', saved);

  const [followed] = await db.query('SELECT * FROM followed_businesses');
  console.log('FOLLOWED_BIZ:', followed);

  const [posts] = await db.query('SELECT post_id, business_id, user_id, title FROM posts');
  console.log('POSTS:', posts);

  const [biz] = await db.query('SELECT business_id, user_id, business_name FROM business_profile');
  console.log('BIZ:', biz);

  await db.end();
}

run().catch(console.error);

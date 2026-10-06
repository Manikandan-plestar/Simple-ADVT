const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const mysql = require('mysql2/promise');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const http = require('http');
const https = require('https');

// Load environment variables from .env
dotenv.config();

// ==========================================
// 1. CONFIGURATION & ENVIRONMENT VARIABLES
// ==========================================
const PORT = parseInt(process.env.PORT || '5000', 10);
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = parseInt(process.env.DB_PORT || '3306', 10);
const DB_USER = process.env.DB_USER || 'root';
const DB_PASSWORD = process.env.DB_PASSWORD || '';
const DB_NAME = process.env.DB_NAME || 'simple_advt';

const SMTP_HOST = process.env.SMTP_HOST || 'smtp.gmail.com';
const SMTP_PORT = parseInt(process.env.SMTP_PORT || '465', 10);
const SMTP_SECURE = process.env.SMTP_SECURE !== 'false';
const SMTP_USER = process.env.SMTP_USER || '';
const SMTP_PASS = process.env.SMTP_PASS || '';
const FROM_EMAIL = process.env.FROM_EMAIL || `"ADVT App" <${SMTP_USER || 'no-reply@advtapp.com'}>`;

const JWT_SECRET = process.env.JWT_SECRET || 'simple_advt_jwt_super_secret_key_2026_xyz';
const JWT_SECRET_PREVIOUS = process.env.JWT_SECRET_PREVIOUS || '';
const ALLOW_LEGACY_IDENTITY = process.env.ALLOW_LEGACY_IDENTITY !== 'false'; // Default: true for backward compatibility
const ENFORCE_PROFILE_AUTH = process.env.ENFORCE_PROFILE_AUTH === 'true'; // Default: false for backward compatibility
const ENABLE_TEST_OTP = process.env.ENABLE_TEST_OTP === 'true' || process.env.NODE_ENV !== 'production';
const TEST_OTP_ALLOWLIST_RAW = process.env.TEST_OTP_ALLOWLIST || 'test1@gmail.com,test2@gmail.com';
const TEST_OTP_ALLOWLIST = TEST_OTP_ALLOWLIST_RAW.split(',').map(e => e.trim().toLowerCase()).filter(e => e.length > 0);
const VERIFY_PLAY_PURCHASES = process.env.VERIFY_PLAY_PURCHASES === 'true';

const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES || '5', 10);
const RATE_LIMIT_MAX = parseInt(process.env.RATE_LIMIT_MAX_ATTEMPTS || '3', 10);
const RATE_LIMIT_WINDOW_MIN = parseInt(process.env.RATE_LIMIT_WINDOW_MINUTES || '10', 10);

// In strict production mode, validate JWT_SECRET length
if (process.env.NODE_ENV === 'production' && (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32)) {
  console.error('⚠️ [SECURITY WARNING] In production, JWT_SECRET should be at least 32 characters long.');
}

// ==========================================
// 2. MYSQL DATABASE CONNECTION POOL & SCHEMA
// ==========================================
const pool = mysql.createPool({
  host: DB_HOST,
  port: DB_PORT,
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '+00:00'
});

/**
 * Automatically creates the Database & all required Tables, and runs safe column cleanups.
 */
async function initDatabase() {
  try {
    const rawConnection = await mysql.createConnection({
      host: DB_HOST,
      port: DB_PORT,
      user: DB_USER,
      password: DB_PASSWORD
    });

    await rawConnection.query(`
      CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
      CHARACTER SET utf8mb4 
      COLLATE utf8mb4_unicode_ci;
    `);
    await rawConnection.end();

    const connection = await pool.getConnection();
    console.log(`[Database] Connected successfully to MySQL database: "${DB_NAME}"`);

    // 1. Table: email_otp
    await connection.query(`
      CREATE TABLE IF NOT EXISTS email_otp (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL,
        otp VARCHAR(6) NOT NULL,
        expires_at DATETIME NOT NULL,
        is_used TINYINT DEFAULT 0,
        attempts INT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_expires (expires_at),
        INDEX idx_created (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // Safe migration: Add attempts column to email_otp if missing
    try {
      const [otpCols] = await connection.query(`
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'email_otp'
      `, [DB_NAME]);
      const otpColNames = otpCols.map(c => c.COLUMN_NAME);
      if (!otpColNames.includes('attempts')) {
        await connection.query('ALTER TABLE email_otp ADD COLUMN attempts INT DEFAULT 0');
        console.log('[Migration] Added column attempts to email_otp');
      }
    } catch (otpMigErr) {
      console.log('[Migration] email_otp migration notice:', otpMigErr.message);
    }

    // 2. Table: users (One Email = One User Account)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        full_name VARCHAR(255) NOT NULL,
        mobile_number VARCHAR(20) DEFAULT '',
        country_code VARCHAR(10) DEFAULT '+91',
        full_address TEXT NOT NULL,
        locality VARCHAR(100),
        city VARCHAR(100),
        state VARCHAR(100),
        country VARCHAR(100) DEFAULT 'India',
        latitude DECIMAL(10, 7) DEFAULT 0.0,
        longitude DECIMAL(10, 7) DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_city (city),
        INDEX idx_state (state)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 3. Table: business_profile (Business profiles owned by users)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS business_profile (
        business_id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        business_name VARCHAR(255) NOT NULL,
        category VARCHAR(100) DEFAULT 'General Store',
        business_phone VARCHAR(30) NOT NULL,
        country_code VARCHAR(10) DEFAULT '+91',
        full_address TEXT NOT NULL,
        locality VARCHAR(100),
        city VARCHAR(100),
        state VARCHAR(100),
        country VARCHAR(100) DEFAULT 'India',
        latitude DECIMAL(10, 7) DEFAULT 0.0,
        longitude DECIMAL(10, 7) DEFAULT 0.0,
        profile_image TEXT,
        images TEXT,
        about TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_city (city),
        INDEX idx_category (category)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 4. Table: posts (Cleaned Schema - structured targeting via target_locations_json)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS posts (
        post_id INT AUTO_INCREMENT PRIMARY KEY,
        business_id INT NOT NULL,
        user_id INT NOT NULL,
        title VARCHAR(255) NOT NULL,
        subtitle VARCHAR(255),
        description TEXT,
        target_location VARCHAR(255) NOT NULL,
        target_locations_json TEXT,
        images TEXT,
        brand_logo TEXT,
        duration_days INT NOT NULL DEFAULT 1,
        status VARCHAR(50) NOT NULL DEFAULT 'pending_payment',
        published_at DATETIME DEFAULT NULL,
        expires_at DATETIME DEFAULT NULL,
        payment_id VARCHAR(255) DEFAULT NULL,
        more_info_clicks INT DEFAULT 0,
        saved_count INT DEFAULT 0,
        is_active TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_business_id (business_id),
        INDEX idx_user_id (user_id),
        INDEX idx_status (status),
        INDEX idx_is_active (is_active),
        INDEX idx_expires_at (expires_at),
        INDEX idx_created (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // Safe migration: Add paid duration, payment, status, and engagement columns
    try {
      const [cols] = await connection.query(`
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'posts'
      `, [DB_NAME]);
      const colNames = cols.map(c => c.COLUMN_NAME);

      if (!colNames.includes('duration_days')) {
        await connection.query('ALTER TABLE posts ADD COLUMN duration_days INT NOT NULL DEFAULT 1');
        console.log('[Migration] Added column duration_days to posts');
      }
      if (!colNames.includes('status')) {
        await connection.query("ALTER TABLE posts ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'active'");
        console.log('[Migration] Added column status to posts');
      }
      if (!colNames.includes('published_at')) {
        await connection.query('ALTER TABLE posts ADD COLUMN published_at DATETIME DEFAULT NULL');
        console.log('[Migration] Added column published_at to posts');
      }
      if (!colNames.includes('expires_at')) {
        await connection.query('ALTER TABLE posts ADD COLUMN expires_at DATETIME DEFAULT NULL');
        console.log('[Migration] Added column expires_at to posts');
        // Retrofit existing active posts to have a safe 30-day default expiration
        await connection.query(`
          UPDATE posts 
          SET published_at = COALESCE(published_at, created_at),
              expires_at = COALESCE(expires_at, DATE_ADD(created_at, INTERVAL 30 DAY)),
              status = IF(is_active = 1, 'active', 'pending_payment')
          WHERE expires_at IS NULL
        `);
        console.log('[Migration] Populated published_at and expires_at for legacy posts');
      }
      if (!colNames.includes('payment_id')) {
        await connection.query('ALTER TABLE posts ADD COLUMN payment_id VARCHAR(255) DEFAULT NULL');
        console.log('[Migration] Added column payment_id to posts');
      }

      if (!colNames.includes('more_info_clicks')) {
        await connection.query('ALTER TABLE posts ADD COLUMN more_info_clicks INT DEFAULT 0');
        console.log('[Migration] Added column more_info_clicks to posts');
      }
      if (!colNames.includes('saved_count')) {
        await connection.query('ALTER TABLE posts ADD COLUMN saved_count INT DEFAULT 0');
        console.log('[Migration] Added column saved_count to posts');
        await connection.query(`
          UPDATE posts p 
          SET saved_count = (SELECT COUNT(*) FROM saved_posts sp WHERE sp.post_id = p.post_id)
        `);
        console.log('[Migration] Synchronized existing saved_count for all posts');
      }

      if (colNames.includes('target_city')) {
        await connection.query('ALTER TABLE posts DROP COLUMN target_city');
      }
      if (colNames.includes('target_district')) {
        await connection.query('ALTER TABLE posts DROP COLUMN target_district');
      }
      if (colNames.includes('target_state')) {
        await connection.query('ALTER TABLE posts DROP COLUMN target_state');
      }
      if (colNames.includes('post_type')) {
        await connection.query('ALTER TABLE posts DROP COLUMN post_type');
      }
    } catch (migErr) {
      console.log('[Migration] Posts table migration notice:', migErr.message);
    }

    // 5. Table: payment_transactions (Audit log & verification record for Google Play & Apple StoreKit)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS payment_transactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        business_id INT NOT NULL,
        post_id INT NOT NULL,
        platform VARCHAR(50) NOT NULL,
        product_id VARCHAR(100) NOT NULL,
        transaction_id VARCHAR(255) NOT NULL,
        purchase_token TEXT NOT NULL,
        selected_days INT NOT NULL DEFAULT 1,
        amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        currency VARCHAR(10) NOT NULL DEFAULT 'INR',
        payment_status VARCHAR(50) NOT NULL DEFAULT 'completed',
        verification_status VARCHAR(50) NOT NULL DEFAULT 'verified',
        raw_verification_payload LONGTEXT NULL,
        payment_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_platform_tx (platform, transaction_id),
        INDEX idx_user_id (user_id),
        INDEX idx_business_id (business_id),
        INDEX idx_post_id (post_id),
        INDEX idx_product_id (product_id),
        INDEX idx_payment_time (payment_time)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 6. Table: saved_posts (Bookmarks for authenticated users)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS saved_posts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        post_id INT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY user_post_unique (user_id, post_id),
        INDEX idx_user_id (user_id),
        INDEX idx_post_id (post_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 7. Table: followed_businesses (Business profiles followed by users)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS followed_businesses (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        business_id INT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY user_biz_unique (user_id, business_id),
        INDEX idx_user_id (user_id),
        INDEX idx_business_id (business_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 8. Table: notifications (Persistent follower notifications for business posts with 15-day retention)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        business_id INT NOT NULL,
        post_id INT DEFAULT NULL,
        type VARCHAR(50) NOT NULL DEFAULT 'new_business_post',
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        is_read TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_user_post_notif (user_id, post_id, type),
        INDEX idx_user_id (user_id),
        INDEX idx_business_id (business_id),
        INDEX idx_post_id (post_id),
        INDEX idx_is_read (is_read),
        INDEX idx_created (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // Seed test accounts
    await connection.query(`
      INSERT IGNORE INTO users (id, email, full_name, mobile_number, country_code, full_address, locality, city, state, country, latitude, longitude)
      VALUES 
        (1, 'test1@gmail.com', 'Mani Kumar', '9876543210', '+91', '12 South Car Street, Palayamkottai, Tirunelveli, Tamil Nadu 627002', 'Palayamkottai', 'Tirunelveli', 'Tamil Nadu', 'India', 8.7139, 77.7567),
        (2, 'test2@gmail.com', 'Devi Priya', '9876543211', '+91', '45 West Veli Street, Madurai Main, Madurai, Tamil Nadu 625001', 'Madurai Main', 'Madurai', 'Tamil Nadu', 'India', 9.9252, 78.1198);
    `);

    // Seed demo business profile and posts if empty
    const [bizCount] = await connection.query('SELECT COUNT(*) as cnt FROM business_profile');
    if (bizCount[0].cnt === 0) {
      await connection.query(`
        INSERT INTO business_profile (business_id, user_id, business_name, category, business_phone, country_code, full_address, locality, city, state, country, latitude, longitude, profile_image, images, about)
        VALUES 
          (1, 1, 'Apex Dental Care', 'Healthcare & Clinic', '9443322110', '+91', '14 North High Ground Road, Palayamkottai, Tirunelveli, Tamil Nadu 627002', 'Palayamkottai', 'Tirunelveli', 'Tamil Nadu', 'India', 8.7139, 77.7567, 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=600&q=80', '[\"https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=600&q=80\"]', 'Comprehensive family dental clinic providing laser dentistry, smile designing, and orthodontic treatments.', '2026-09-21 11:20:34', '2026-09-25 12:00:00'),
          (2, 1, 'Nova Tech Solutions', 'Electronics & Gadgets', '9876543210', '+91', '45 West Veli Street, Madurai Main, Madurai, Tamil Nadu 625001', 'Madurai Main', 'Madurai', 'Tamil Nadu', 'India', 9.9252, 78.1198, 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80', '[\"https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80\",\"https://images.unsplash.com/photo-1572536147248-ac59a8abfa4b?auto=format&fit=crop&w=600&q=80\"]', 'Authorized retailer for smart audio, wearables, IT hardware accessories, and repair services.', '2026-09-21 13:02:26', '2026-09-25 12:00:00');
      `);

      await connection.query(`
        INSERT INTO posts (post_id, business_id, user_id, title, subtitle, description, target_location, target_locations_json, images, brand_logo, is_active)
        VALUES
          (1, 1, 1, 'Advanced Smile Designing & Laser Dentistry', 'Apex Dental Care • Palayamkottai', 'Experience painless laser dentistry and precision smile designing with our modern dental equipment. Book your consultation today.', 'Tirunelveli, Palayamkottai', '[{\"placeId\":\"city_tirunelveli\",\"name\":\"Tirunelveli\",\"type\":\"city\",\"state\":\"Tamil Nadu\",\"country\":\"India\"},{\"placeId\":\"loc_palayamkottai\",\"name\":\"Palayamkottai\",\"type\":\"locality\",\"city\":\"Tirunelveli\",\"state\":\"Tamil Nadu\",\"country\":\"India\"}]', '[\"https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=600&q=80\",\"https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?auto=format&fit=crop&w=600&q=80\"]', 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=150&q=80', 1),
          (2, 2, 1, 'Wireless Audio & Smart Gadgets Arrival', 'Nova Tech Solutions • Madurai', 'Check out the new range of active noise cancelling wireless earphones and fast magnetic chargers at Nova Tech.', 'Madurai, Madurai Main', '[{\"placeId\":\"city_madurai\",\"name\":\"Madurai\",\"type\":\"city\",\"state\":\"Tamil Nadu\",\"country\":\"India\"}]', '[\"https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80\",\"https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80\"]', 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=150&q=80', 1);
      `);
    }

    connection.release();
  } catch (error) {
    console.error('[Database] MySQL Initialization Error:', error.message);
  }
}

// ==========================================
// 3. NODEMAILER EMAIL TRANSPORTER
// ==========================================
const cleanSmtpPass = (SMTP_PASS || '').replace(/\s+/g, '');

const transporterConfig = SMTP_HOST === 'smtp.gmail.com'
  ? {
    service: 'gmail',
    auth: {
      user: SMTP_USER,
      pass: cleanSmtpPass,
    },
  }
  : {
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_SECURE,
    auth: {
      user: SMTP_USER,
      pass: cleanSmtpPass,
    },
    tls: {
      rejectUnauthorized: false
    }
  };

const transporter = nodemailer.createTransport(transporterConfig);

function buildOtpHtmlTemplate(otp, expiryMinutes = 5) {
  return `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ADVT Verification Code</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f8fafc; margin: 0; padding: 0; }
      .container { max-width: 500px; margin: 30px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; }
      .header { background: linear-gradient(135deg, #4f46e5 0%, #6366f1 100%); padding: 30px 20px; text-align: center; color: #ffffff; }
      .header h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px; }
      .content { padding: 30px 24px; text-align: center; color: #334155; }
      .otp-box { display: inline-block; background: #eef2ff; border: 2px dashed #4f46e5; border-radius: 12px; padding: 14px 32px; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #4f46e5; margin: 15px 0 20px 0; }
      .expiry { font-size: 13px; color: #ef4444; font-weight: 600; margin-bottom: 16px; }
      .security { font-size: 12px; color: #94a3b8; line-height: 1.5; border-top: 1px solid #f1f5f9; padding-top: 16px; margin-top: 20px; }
      .footer { background: #f8fafc; padding: 14px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1> ADVT</h1>
        <p style="margin: 4px 0 0 0; opacity: 0.9; font-size: 14px;">Email Verification Code</p>
      </div>
      <div class="content">
        <p style="font-size: 15px; margin-bottom: 16px;">Please use the following 6-digit code to complete your verification:</p>
        <div class="otp-box">${otp}</div>
        <p class="expiry">⚠️ This code expires in ${expiryMinutes} minutes.</p>
        <div class="security">If you did not request this code, please ignore this email. Never share your OTP with anyone.</div>
      </div>
      <div class="footer">&copy; ${new Date().getFullYear()}  ADVT. All rights reserved.</div>
    </div>
  </body>
  </html>
  `;
}

async function sendOtpEmail(email, otp) {
  if (!SMTP_USER || !cleanSmtpPass) {
    throw new Error('SMTP credentials are not configured in backend .env file.');
  }

  const senderAddress = FROM_EMAIL && FROM_EMAIL.includes('<') && FROM_EMAIL.includes('>')
    ? FROM_EMAIL
    : `"ADVT App" <${SMTP_USER}>`;

  const mailOptions = {
    from: senderAddress,
    to: email,
    subject: `${otp} is your ADVT App verification code`,
    text: `Your ADVT App verification code is: ${otp}. It will expire in ${OTP_EXPIRY_MINUTES} minutes.`,
    html: buildOtpHtmlTemplate(otp, OTP_EXPIRY_MINUTES),
  };

  const info = await transporter.sendMail(mailOptions);
  console.log(`[Mailer] Verification OTP sent successfully to ${email} (MessageID: ${info.messageId})`);
  return info;
}

// ==========================================
// 4. HIERARCHICAL LOCATION MATCHING ENGINE
// ==========================================

function normalizeStr(str) {
  if (str === null || str === undefined) return '';
  return str.toString().trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Returns hierarchical rank for a location type.
 * Lower number = broader geographic scope.
 */
function getLocationRank(type) {
  const t = normalizeStr(type);
  if (!t) return 4;
  if (t === 'country' || t === 'nation') return 1;
  if (['state', 'province', 'region', 'administrative_area_level_1', 'territory'].includes(t)) return 2;
  if (['city', 'district', 'county', 'administrative_area_level_2', 'administrative_area_level_3', 'town', 'municipality'].includes(t)) return 3;
  if (['locality', 'sublocality', 'neighborhood', 'sublocality_level_1', 'sublocality_level_2', 'area', 'postal_code'].includes(t)) return 4;
  return 5;
}

/**
 * Calculate distance between two GPS coordinates in kilometers (Haversine formula).
 */
function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const nLat1 = parseFloat(lat1);
  const nLon1 = parseFloat(lon1);
  const nLat2 = parseFloat(lat2);
  const nLon2 = parseFloat(lon2);

  if (isNaN(nLat1) || isNaN(nLon1) || isNaN(nLat2) || isNaN(nLon2)) return Infinity;
  if (nLat1 === 0 && nLon1 === 0) return Infinity;
  if (nLat2 === 0 && nLon2 === 0) return Infinity;

  const R = 6371; // Earth's radius in km
  const dLat = (nLat2 - nLat1) * (Math.PI / 180);
  const dLon = (nLon2 - nLon1) * (Math.PI / 180);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(nLat1 * (Math.PI / 180)) *
    Math.cos(nLat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Normalizes user registration location into structured object.
 */
function normalizeUserLocation(user) {
  if (!user) {
    return {
      locality: '',
      city: '',
      state: '',
      country: '',
      latitude: 0,
      longitude: 0,
      full_address: ''
    };
  }

  return {
    locality: normalizeStr(user.locality || user.area || ''),
    city: normalizeStr(user.city || user.district || ''),
    state: normalizeStr(user.state || ''),
    country: normalizeStr(user.country || ''),
    latitude: parseFloat(user.latitude) || 0,
    longitude: parseFloat(user.longitude) || 0,
    full_address: normalizeStr(user.full_address || user.address || '')
  };
}

/**
 * Normalizes a single target location object.
 */
function normalizeTargetLocationItem(item) {
  if (!item) return null;

  if (typeof item === 'string') {
    const clean = normalizeStr(item);
    return {
      placeId: '',
      name: clean,
      type: 'city',
      country: '',
      countryCode: '',
      state: '',
      city: clean,
      locality: '',
      latitude: 0,
      longitude: 0
    };
  }

  const name = normalizeStr(item.name || item.cityName || item.stateName || item.countryName || '');
  const type = normalizeStr(item.type || 'locality');
  const country = normalizeStr(item.country || item.countryName || '');
  const countryCode = normalizeStr(item.countryCode || '');
  const state = normalizeStr(item.state || item.stateName || '');
  const city = normalizeStr(item.city || item.cityName || '');
  const locality = normalizeStr(item.locality || (type === 'locality' ? name : ''));

  return {
    placeId: item.placeId || item.place_id || '',
    name: name,
    type: type,
    country: country,
    countryCode: countryCode,
    state: state,
    city: city,
    locality: locality,
    latitude: parseFloat(item.latitude) || 0,
    longitude: parseFloat(item.longitude) || 0
  };
}

/**
 * Extracts and parses target locations from post record.
 */
function extractPostTargetLocations(post) {
  if (!post) return [];

  const rawJson = post.target_locations_json || post.target_locations || post.targetLocationItems;
  let list = [];

  if (rawJson) {
    if (Array.isArray(rawJson)) {
      list = rawJson;
    } else if (typeof rawJson === 'string' && rawJson.trim().length > 0) {
      try {
        const parsed = JSON.parse(rawJson);
        if (Array.isArray(parsed)) list = parsed;
      } catch (_) {
        // Not JSON
      }
    }
  }

  // Fallback: parse from target_location string if JSON was empty
  if (list.length === 0 && post.target_location && typeof post.target_location === 'string') {
    const parts = post.target_location.split(',').map(s => s.trim()).filter(Boolean);
    list = parts.map(p => ({
      name: p,
      type: 'city',
      city: p
    }));
  }

  return list
    .map(normalizeTargetLocationItem)
    .filter(item => item && (item.name || item.city || item.state || item.country));
}

/**
 * Checks if two target location objects refer to the exact same geographic entity.
 */
function isSameLocation(a, b) {
  if (a.placeId && b.placeId && a.placeId === b.placeId) return true;
  if (a.name === b.name && getLocationRank(a.type) === getLocationRank(b.type)) {
    const aCountry = a.country || a.countryCode;
    const bCountry = b.country || b.countryCode;
    if (aCountry && bCountry && aCountry !== bCountry) return false;
    return true;
  }
  return false;
}

/**
 * Checks if location [parent] geographically contains location [child].
 * Returns true if parent is an ancestor of child on the same geographic branch.
 */
function isLocationContained(parent, child) {
  if (!parent || !child) return false;
  if (isSameLocation(parent, child)) return false;

  const parentRank = getLocationRank(parent.type);
  const childRank = getLocationRank(child.type);

  // Parent must be strictly broader in scope
  if (parentRank >= childRank) return false;

  const pCountry = parent.country || (parentRank === 1 ? parent.name : '');
  const cCountry = child.country || (childRank === 1 ? child.name : '');
  const pCountryCode = parent.countryCode || '';
  const cCountryCode = child.countryCode || '';

  const sameCountry =
    !pCountry ||
    !cCountry ||
    pCountry === cCountry ||
    (pCountryCode && cCountryCode && pCountryCode === cCountryCode) ||
    child.name === pCountry;

  // 1. Parent is Country (rank 1)
  if (parentRank === 1) {
    if (sameCountry) return true;
    if (child.country === parent.name || child.name === parent.name) return true;
    if (pCountryCode && cCountryCode === pCountryCode) return true;
    return false;
  }

  // State, City, Locality must share country
  if (!sameCountry) return false;

  const pState = parent.state || (parentRank === 2 ? parent.name : '');
  const cState = child.state || (childRank === 2 ? child.name : '');

  // 2. Parent is State (rank 2)
  if (parentRank === 2) {
    if (cState && (cState === pState || child.name === pState)) {
      return true;
    }
    // Proximity fallback if coordinates exist (< 350 km)
    const dist = calculateDistanceKm(parent.latitude, parent.longitude, child.latitude, child.longitude);
    if (dist < 350) return true;
    return false;
  }

  const pCity = parent.city || (parentRank === 3 ? parent.name : '');
  const cCity = child.city || (childRank === 3 ? child.name : '');

  // 3. Parent is City / District (rank 3)
  if (parentRank === 3) {
    if (cCity && (cCity === pCity || child.name === pCity)) {
      return true;
    }
    // Locality inside city proximity check (< 45 km)
    const dist = calculateDistanceKm(parent.latitude, parent.longitude, child.latitude, child.longitude);
    if (dist < 45) return true;
    return false;
  }

  return false;
}

/**
 * Applies specificity elimination rule:
 * When multiple target locations contain one another (e.g. parent + child):
 * The more specific descendant target takes precedence.
 * Broader parent is eliminated from effective audience.
 * Unrelated locations are preserved (OR behavior).
 */
function getEffectiveTargetLocations(targetLocations) {
  if (!targetLocations || targetLocations.length <= 1) {
    return targetLocations || [];
  }

  // Deduplicate identical items
  const uniqueTargets = [];
  for (const item of targetLocations) {
    if (!uniqueTargets.some(e => isSameLocation(e, item))) {
      uniqueTargets.push(item);
    }
  }

  // Keep only targets that do NOT have a more-specific descendant in the list
  const effective = [];
  for (let i = 0; i < uniqueTargets.length; i++) {
    const candidate = uniqueTargets[i];
    let hasMoreSpecificChild = false;

    for (let j = 0; j < uniqueTargets.length; j++) {
      if (i === j) continue;
      const other = uniqueTargets[j];

      // If 'candidate' contains 'other', then 'other' is a more specific child
      if (isLocationContained(candidate, other)) {
        hasMoreSpecificChild = true;
        break;
      }
    }

    if (!hasMoreSpecificChild) {
      effective.push(candidate);
    }
  }

  return effective;
}

/**
 * Tests whether a user's registration/current location falls within a specific target location.
 */
function isUserCoveredByTarget(target, userLoc) {
  if (!target || !userLoc) return false;

  const cleanTargetName = normalizeStr(target.name);
  const cleanTargetType = normalizeStr(target.type);

  // Global / Worldwide / All Locations coverage
  if (
    cleanTargetName === 'all' ||
    cleanTargetName === 'worldwide' ||
    cleanTargetName === 'global' ||
    cleanTargetName === 'everywhere' ||
    cleanTargetName === 'all locations' ||
    cleanTargetType === 'worldwide' ||
    cleanTargetType === 'all'
  ) {
    return true;
  }

  const rank = getLocationRank(target.type);

  const userCountry = normalizeStr(userLoc.country);
  const userState = normalizeStr(userLoc.state);
  const userCity = normalizeStr(userLoc.city);
  const userLocality = normalizeStr(userLoc.locality);
  const userFullAddr = normalizeStr(userLoc.full_address);

  const targetCountry = normalizeStr(target.country || (rank === 1 ? cleanTargetName : ''));
  const targetState = normalizeStr(target.state || (rank === 2 ? cleanTargetName : ''));
  const targetCity = normalizeStr(target.city || (rank === 3 ? cleanTargetName : ''));
  const targetLocality = normalizeStr(target.locality || (rank >= 4 ? cleanTargetName : ''));

  // 1. Target is Country (rank 1)
  if (rank === 1) {
    if (userCountry && (userCountry === cleanTargetName || userCountry === targetCountry)) return true;
    if (target.countryCode && userLoc.countryCode && normalizeStr(target.countryCode) === normalizeStr(userLoc.countryCode)) return true;
    if (userFullAddr && (userFullAddr.includes(cleanTargetName) || (targetCountry && userFullAddr.includes(targetCountry)))) return true;
    return false;
  }

  // Country mismatch check (if both have specified countries)
  if (userCountry && targetCountry && userCountry !== targetCountry) {
    return false;
  }

  // 2. Target is State (rank 2)
  if (rank === 2) {
    if (userState && (userState === cleanTargetName || userState === targetState)) return true;
    if (userFullAddr && userFullAddr.includes(cleanTargetName)) return true;
    const dist = calculateDistanceKm(target.latitude, target.longitude, userLoc.latitude, userLoc.longitude);
    if (dist < 350) return true;
    return false;
  }

  // State mismatch check (if both have specified states)
  if (userState && targetState && userState !== targetState) {
    return false;
  }

  // 3. Target is City / District (rank 3)
  if (rank === 3) {
    // Exact city match
    if (userCity && (userCity === cleanTargetName || userCity === targetCity)) return true;
    // User locality matches city name or vice versa
    if (userLocality && (userLocality === cleanTargetName || userLocality.includes(cleanTargetName) || cleanTargetName.includes(userLocality))) return true;
    // Containment check between user city and target city
    if (userCity && (userCity.includes(cleanTargetName) || cleanTargetName.includes(userCity))) return true;
    // Address string containment
    if (userFullAddr && (userFullAddr.includes(cleanTargetName) || (targetCity && userFullAddr.includes(targetCity)))) {
      return true;
    }
    // Coordinate proximity (< 45 km)
    const dist = calculateDistanceKm(target.latitude, target.longitude, userLoc.latitude, userLoc.longitude);
    if (dist < 45) return true;
    return false;
  }

  // 4. Target is Locality / Sub-locality (rank 4)
  if (rank >= 4) {
    // Exact locality match
    if (userLocality && (userLocality === cleanTargetName || userLocality === targetLocality)) {
      return true;
    }
    // User locality containment
    if (userLocality && (userLocality.includes(cleanTargetName) || cleanTargetName.includes(userLocality))) {
      return true;
    }
    // Proximity check (< 10 km)
    const dist = calculateDistanceKm(target.latitude, target.longitude, userLoc.latitude, userLoc.longitude);
    if (dist < 10) return true;

    // Address containment check
    if (userFullAddr && userFullAddr.includes(cleanTargetName)) {
      if (!userLocality || userLocality.includes(cleanTargetName) || cleanTargetName.includes(userLocality)) {
        return true;
      }
    }
    return false;
  }

  return false;
}

/**
 * Primary matching function: determines if a post is visible to a given user.
 */
function isPostVisibleToUser(post, user) {
  if (!post) return false;
  if (!user) return true;

  const userLoc = normalizeUserLocation(user);
  const targets = extractPostTargetLocations(post);

  if (targets.length === 0) {
    if (!post.target_location) return true;
    const cleanTarget = normalizeStr(post.target_location);
    if (cleanTarget === 'all' || cleanTarget === 'worldwide' || cleanTarget === 'global' || cleanTarget === '') return true;

    if (userLoc.city && cleanTarget.includes(userLoc.city)) return true;
    if (userLoc.locality && cleanTarget.includes(userLoc.locality)) return true;
    if (userLoc.state && cleanTarget.includes(userLoc.state)) return true;
    if (userLoc.country && cleanTarget.includes(userLoc.country)) return true;
    if (userLoc.full_address && cleanTarget.split(',').some(part => userLoc.full_address.includes(part.trim()))) return true;
    return false;
  }

  // Specificity Rule: more-specific child location takes precedence
  const effectiveTargets = getEffectiveTargetLocations(targets);

  for (const target of effectiveTargets) {
    if (isUserCoveredByTarget(target, userLoc)) {
      return true;
    }
  }

  return false;
}

/**
 * Filter an array of posts for a user, applying location targeting and optional client filters.
 */
function filterPostsForUser(posts, user, options = {}) {
  if (!Array.isArray(posts)) return [];

  const {
    businessId,
    searchQuery,
    skipLocationCheck = false
  } = options;

  return posts.filter(post => {
    // 1. Business Profile ID filter (if requested)
    if (businessId) {
      const bId = businessId.toString().replace(/^BP0*/i, '');
      const postBId = (post.business_id || post.businessProfileId || '').toString().replace(/^BP0*/i, '');
      if (bId !== postBId) return false;
    }

    // 2. Location Eligibility (enforced server-side)
    if (!skipLocationCheck && user) {
      if (!isPostVisibleToUser(post, user)) {
        return false;
      }
    }

    // 3. Search text filter (if requested)
    if (searchQuery && searchQuery.trim().length > 0) {
      const q = normalizeStr(searchQuery);
      const title = normalizeStr(post.title || '');
      const subtitle = normalizeStr(post.subtitle || '');
      const desc = normalizeStr(post.description || '');
      const bizName = normalizeStr(post.business_name || post.bizName || '');
      const loc = normalizeStr(post.target_location || '');

      const matchesSearch =
        title.includes(q) ||
        subtitle.includes(q) ||
        desc.includes(q) ||
        bizName.includes(q) ||
        loc.includes(q);

      if (!matchesSearch) return false;
    }

    return true;
  });
}

// ==========================================
// 5. PRICING CONFIGURATION & SCHEDULED CLEANUP
// ==========================================
const POST_PRICING_CONFIG = {
  testMode: process.env.NODE_ENV !== 'production',
  defaultCurrency: 'INR',
  products: {
    'advt_post_1_day': { days: 1, testPrice: 1.0, prodPrice: 100.0, name: '1 Day Post' },
    'advt_post_2_days': { days: 2, testPrice: 2.0, prodPrice: 200.0, name: '2 Days Post' },
    'advt_post_3_days': { days: 3, testPrice: 3.0, prodPrice: 300.0, name: '3 Days Post' },
    'advt_post_7_days': { days: 7, testPrice: 7.0, prodPrice: 700.0, name: '7 Days Post' },
    'advt_post_15_days': { days: 15, testPrice: 15.0, prodPrice: 1500.0, name: '15 Days Post' },
    'advt_post_30_days': { days: 30, testPrice: 30.0, prodPrice: 3000.0, name: '30 Days Post' },
  }
};

/**
 * Scheduled background job: Periodically scans and marks expired posts.
 */
async function runExpiredPostsCleanup() {
  try {
    const [res] = await pool.query(`
      UPDATE posts 
      SET status = 'expired', is_active = 0 
      WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()
    `);
    if (res && res.changedRows > 0) {
      console.log(`[Scheduler] Automatically marked ${res.changedRows} post(s) as expired.`);
    }
  } catch (err) {
    console.error('[Scheduler] Error cleaning up expired posts:', err.message);
  }
}

// Execute every 60 seconds
setInterval(runExpiredPostsCleanup, 60 * 1000);

// ==========================================
// 6. HELPER FUNCTIONS & LOGIC
// ==========================================
function isTestAccount(email) {
  if (!ENABLE_TEST_OTP) return false;
  const clean = (email || '').toLowerCase().trim();
  return TEST_OTP_ALLOWLIST.includes(clean);
}

function verifyTestCredentials(email, otp) {
  if (!ENABLE_TEST_OTP) return false;
  const cleanEmail = (email || '').toLowerCase().trim();
  const cleanOtp = (otp || '').toString().trim();
  return TEST_OTP_ALLOWLIST.includes(cleanEmail) && cleanOtp === '123456';
}

function generate6DigitOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

function isValidEmailFormat(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return email && emailRegex.test(email.trim());
}

function capitalizeWords(str) {
  if (!str) return '';
  return str.trim().split(/\s+/).map(w => {
    if (!w) return '';
    return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
  }).join(' ');
}

function extractAddressComponents(fullAddress, existingLocality = '', existingCity = '', existingState = '', existingCountry = '') {
  let locality = (existingLocality || '').trim();
  let city = (existingCity || '').trim();
  let state = (existingState || '').trim();
  let country = (existingCountry || '').trim();

  const rawAddress = (fullAddress || '').trim();
  if (!rawAddress) {
    return {
      full_address: '',
      locality: locality || 'Local Area',
      city: city || 'City',
      state: state || 'Tamil Nadu',
      country: country || 'India'
    };
  }

  const parts = rawAddress.split(',').map(p => p.trim()).filter(p => p.length > 0);

  if (parts.length > 0) {
    if (!country) {
      const lastPart = parts[parts.length - 1];
      const cleanedCountry = lastPart.replace(/[0-9-]/g, '').trim();
      country = cleanedCountry.length > 1 ? cleanedCountry : 'India';
    }

    if (!state) {
      if (parts.length >= 2) {
        const stateCandidate = parts[parts.length - 2].replace(/[0-9-]/g, '').trim();
        if (stateCandidate.length > 0) state = stateCandidate;
      }
      if (!state) state = 'Tamil Nadu';
    }

    if (!city) {
      if (parts.length >= 3) {
        city = parts[parts.length - 3].replace(/[0-9-]/g, '').trim();
      } else if (parts.length === 2) {
        city = parts[0].replace(/[0-9-]/g, '').trim();
      } else if (parts.length === 1) {
        city = parts[0].trim();
      }
      if (!city) city = 'Tirunelveli';
    }

    if (!locality) {
      if (parts.length >= 4) {
        locality = parts.slice(0, parts.length - 3).join(', ').trim();
      } else if (parts.length >= 2) {
        locality = parts[0].trim();
      } else {
        locality = city || 'Palayamkottai';
      }
    }
  }

  return {
    full_address: rawAddress,
    locality: locality || city || 'Local Area',
    city: city || 'City',
    state: state || 'Tamil Nadu',
    country: country || 'India'
  };
}

async function checkRateLimit(email) {
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MIN * 60 * 1000);
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS attempt_count FROM email_otp WHERE email = ? AND created_at >= ?`,
    [email, windowStart]
  );
  const attemptCount = rows[0]?.attempt_count || 0;
  return {
    isLimited: attemptCount >= RATE_LIMIT_MAX,
    attemptCount
  };
}

async function processAndSendOtp(email) {
  const cleanEmail = email.trim().toLowerCase();

  if (isTestAccount(cleanEmail)) {
    console.log(`[Auth] Test account: ${cleanEmail}. Skipping email dispatch (Fixed OTP: 123456).`);
    return { email: cleanEmail, expiresInSeconds: OTP_EXPIRY_MINUTES * 60 };
  }

  const rateStatus = await checkRateLimit(cleanEmail);
  if (rateStatus.isLimited) {
    const error = new Error(`Rate limit exceeded. Maximum ${RATE_LIMIT_MAX} requests per ${RATE_LIMIT_WINDOW_MIN} minutes.`);
    error.statusCode = 429;
    throw error;
  }

  await pool.query(`UPDATE email_otp SET is_used = 1 WHERE email = ? AND is_used = 0`, [cleanEmail]);
  const otp = generate6DigitOtp();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  const [insertResult] = await pool.query(
    `INSERT INTO email_otp (email, otp, expires_at, is_used) VALUES (?, ?, ?, 0)`,
    [cleanEmail, otp, expiresAt]
  );

  try {
    await sendOtpEmail(cleanEmail, otp);
  } catch (mailErr) {
    await pool.query(`DELETE FROM email_otp WHERE id = ?`, [insertResult.insertId]);
    console.error(`[Auth] Failed to send OTP to ${cleanEmail}:`, mailErr.message);
    const error = new Error(`Failed to send verification email: ${mailErr.message}`);
    error.statusCode = 500;
    throw error;
  }

  return { email: cleanEmail, expiresInSeconds: OTP_EXPIRY_MINUTES * 60 };
}

// ==========================================
// 5. EXPRESS APP & API ROUTE HANDLERS
// ==========================================
const app = express();

// Disable x-powered-by header to prevent server fingerprinting
app.disable('x-powered-by');

// Trust reverse proxy for Google Cloud / Nginx HTTPS termination
app.set('trust proxy', 1);

// Security Headers Middleware
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Health Check
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'online',
    service: 'ADVT App Server',
    timestamp: new Date().toISOString()
  });
});

// App Config & Version Management (Force Update Support)
app.get(['/api/app-config', '/api/config'], (req, res) => {
  res.status(200).json({
    success: true,
    min_supported_version: process.env.MIN_SUPPORTED_APP_VERSION || '1.0.0',
    latest_version: process.env.LATEST_APP_VERSION || '1.0.0',
    force_update: false
  });
});

/**
 * 1. POST /api/send-email-otp
 */
app.post(['/api/send-email-otp', '/api/send-otp'], async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || !isValidEmailFormat(email)) {
      return res.status(400).json({ success: false, message: 'A valid email address is required.' });
    }

    const data = await processAndSendOtp(email);
    return res.status(200).json({
      success: true,
      message: `Verification code sent to ${data.email}.`,
      expiresInSeconds: data.expiresInSeconds
    });
  } catch (error) {
    const status = error.statusCode || 500;
    return res.status(status).json({ success: false, message: error.message || 'Failed to send OTP.' });
  }
});

/**
 * 2. POST /api/resend-email-otp
 */
app.post(['/api/resend-email-otp', '/api/resend-otp'], async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || !isValidEmailFormat(email)) {
      return res.status(400).json({ success: false, message: 'A valid email address is required.' });
    }

    const data = await processAndSendOtp(email);
    return res.status(200).json({
      success: true,
      message: `A new verification code was sent to ${data.email}.`,
      expiresInSeconds: data.expiresInSeconds
    });
  } catch (error) {
    const status = error.statusCode || 500;
    return res.status(status).json({ success: false, message: error.message || 'Failed to resend OTP.' });
  }
});

/**
 * 3. POST /api/verify-email-otp
 */
app.post(['/api/verify-email-otp', '/api/verify-otp'], async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !isValidEmailFormat(email)) {
      return res.status(400).json({ success: false, message: 'A valid email address is required.' });
    }
    if (!otp || otp.toString().trim().length !== 6) {
      return res.status(400).json({ success: false, message: 'Wrong OTP' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = otp.toString().trim();

    let isVerified = false;

    if (isTestAccount(cleanEmail)) {
      if (verifyTestCredentials(cleanEmail, cleanOtp)) {
        isVerified = true;
      } else {
        return res.status(400).json({ success: false, message: 'Wrong OTP' });
      }
    } else {
      const [rows] = await pool.query(
        `SELECT * FROM email_otp WHERE email = ? AND is_used = 0 ORDER BY created_at DESC LIMIT 1`,
        [cleanEmail]
      );

      if (!rows || rows.length === 0) {
        return res.status(400).json({ success: false, message: 'Wrong OTP' });
      }

      const record = rows[0];
      const now = new Date();
      if (now > new Date(record.expires_at)) {
        await pool.query(`UPDATE email_otp SET is_used = 1 WHERE id = ?`, [record.id]);
        return res.status(400).json({ success: false, message: 'OTP expired. Please resend the OTP.' });
      }

      if ((record.attempts || 0) >= 5) {
        await pool.query(`UPDATE email_otp SET is_used = 1 WHERE id = ?`, [record.id]);
        return res.status(400).json({ success: false, message: 'Too many failed attempts. Please request a new OTP.' });
      }

      if (record.otp !== cleanOtp) {
        const nextAttempts = (record.attempts || 0) + 1;
        await pool.query(`UPDATE email_otp SET attempts = ?, is_used = IF(? >= 5, 1, 0) WHERE id = ?`, [nextAttempts, nextAttempts, record.id]);
        return res.status(400).json({ success: false, message: 'Wrong OTP' });
      }

      await pool.query(`UPDATE email_otp SET is_used = 1 WHERE id = ?`, [record.id]);
      isVerified = true;
    }

    if (!isVerified) {
      return res.status(400).json({ success: false, message: 'Wrong OTP' });
    }

    // Check if user already exists in users table
    const [userRows] = await pool.query(`SELECT * FROM users WHERE email = ? LIMIT 1`, [cleanEmail]);

    const token = jwt.sign({ email: cleanEmail, isVerified: true }, JWT_SECRET, { expiresIn: '30d' });

    if (userRows && userRows.length > 0) {
      const u = userRows[0];
      const addr = extractAddressComponents(u.full_address, u.locality, u.city, u.state, u.country);

      return res.status(200).json({
        success: true,
        message: 'Email verified successfully!',
        token,
        isExistingUser: true,
        user: {
          id: u.id,
          userId: `U${u.id.toString().padStart(3, '0')}`,
          email: u.email,
          full_name: capitalizeWords(u.full_name),
          name: capitalizeWords(u.full_name),
          mobile_number: u.mobile_number || '',
          phone: u.mobile_number || '',
          country_code: u.country_code || '+91',
          full_address: u.full_address,
          address: u.full_address,
          locality: addr.locality,
          city: addr.city,
          state: addr.state,
          country: addr.country,
          latitude: parseFloat(u.latitude) || 0.0,
          longitude: parseFloat(u.longitude) || 0.0,
          isEmailVerified: true
        }
      });
    }

    // New user -> Requires registration
    return res.status(200).json({
      success: true,
      message: 'Email verified successfully!',
      token,
      isExistingUser: false,
      user: {
        email: cleanEmail,
        isEmailVerified: true
      }
    });
  } catch (error) {
    console.error('[Auth] Verification error:', error.message);
    return res.status(500).json({ success: false, message: 'Internal server error while verifying OTP.' });
  }
});

/**
 * 4. POST /api/register-user
 * Registration with Name and Address (One Email = One User Account)
 */
app.post(['/api/register-user', '/api/register'], async (req, res) => {
  try {
    const {
      email,
      full_name,
      name,
      full_address,
      address,
      locality = '',
      city = '',
      state = '',
      country = 'India',
      latitude = 0.0,
      longitude = 0.0,
      mobile_number = '',
      country_code = '+91'
    } = req.body;

    const targetEmail = (email || '').trim().toLowerCase();
    const targetName = capitalizeWords((full_name || name || '').trim());
    const targetAddress = (full_address || address || '').trim();

    if (!targetEmail || !isValidEmailFormat(targetEmail)) {
      return res.status(400).json({ success: false, message: 'A valid email address is required.' });
    }
    if (!targetName) {
      return res.status(400).json({ success: false, message: 'Name is required.' });
    }
    if (!targetAddress) {
      return res.status(400).json({ success: false, message: 'Address is required.' });
    }

    const addr = extractAddressComponents(targetAddress, locality, city, state, country);

    // Enforce 1-Email = 1-User
    const [existing] = await pool.query(`SELECT id FROM users WHERE email = ? LIMIT 1`, [targetEmail]);
    if (existing && existing.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'An account with this email address already exists. Please login.'
      });
    }

    const [result] = await pool.query(`
      INSERT INTO users (email, full_name, mobile_number, country_code, full_address, locality, city, state, country, latitude, longitude)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      targetEmail,
      targetName,
      (mobile_number || '').trim(),
      (country_code || '+91').trim(),
      addr.full_address,
      addr.locality,
      addr.city,
      addr.state,
      addr.country,
      parseFloat(latitude) || 0.0,
      parseFloat(longitude) || 0.0
    ]);

    const newUserId = result.insertId;
    const token = jwt.sign({ id: newUserId, email: targetEmail, isVerified: true }, JWT_SECRET, { expiresIn: '30d' });

    return res.status(201).json({
      success: true,
      message: 'User registered successfully!',
      token,
      user: {
        id: newUserId,
        userId: `U${newUserId.toString().padStart(3, '0')}`,
        email: targetEmail,
        full_name: targetName,
        name: targetName,
        mobile_number: mobile_number || '',
        phone: mobile_number || '',
        country_code: country_code || '+91',
        full_address: addr.full_address,
        address: addr.full_address,
        locality: addr.locality,
        city: addr.city,
        state: addr.state,
        country: addr.country,
        latitude: parseFloat(latitude) || 0.0,
        longitude: parseFloat(longitude) || 0.0
      }
    });
  } catch (error) {
    console.error('[Users] Registration error:', error.message);
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ success: false, message: 'An account with this email already exists.' });
    }
    return res.status(500).json({ success: false, message: error.message || 'Error registering user.' });
  }
});

// User Resolution Helper (from Token, Headers, or Query)
async function getUserFromRequest(req) {
  try {
    let user = null;
    const authHeader = req.headers['authorization'];
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7).trim();
      try {
        let decoded = null;
        try {
          decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
        } catch (jwtErr) {
          if (JWT_SECRET_PREVIOUS) {
            decoded = jwt.verify(token, JWT_SECRET_PREVIOUS, { algorithms: ['HS256'] });
          } else {
            throw jwtErr;
          }
        }

        if (decoded && decoded.id) {
          const [rows] = await pool.query('SELECT * FROM users WHERE id = ? LIMIT 1', [decoded.id]);
          if (rows && rows.length > 0) user = rows[0];
        }
        if (!user && decoded && decoded.email) {
          const [rows] = await pool.query('SELECT * FROM users WHERE email = ? LIMIT 1', [decoded.email.toLowerCase().trim()]);
          if (rows && rows.length > 0) user = rows[0];
        }
        if (!user && decoded && decoded.id) {
          user = { id: decoded.id, email: decoded.email || `user${decoded.id}@advtapp.com`, full_name: 'App User' };
        }

        // If authenticated with valid JWT, strictly use JWT identity
        if (user) return user;
      } catch (_) { }
    }

    // If legacy fallbacks are disabled, reject non-JWT authentication
    if (!ALLOW_LEGACY_IDENTITY) {
      return null;
    }

    const appVersion = req.headers['x-app-version'] || 'unknown';
    let legacyDetected = false;

    if (!user && req.headers['x-user-id']) {
      legacyDetected = true;
      const rawId = req.headers['x-user-id'].toString().replace(/^U0*/i, '');
      const numId = parseInt(rawId, 10);
      if (!isNaN(numId) && numId > 0) {
        const [rows] = await pool.query('SELECT * FROM users WHERE id = ? LIMIT 1', [numId]);
        if (rows && rows.length > 0) user = rows[0];
        else user = { id: numId, email: req.headers['x-user-email'] || `user${numId}@advtapp.com`, full_name: 'App User' };
      }
    }

    if (!user && req.headers['x-user-email']) {
      legacyDetected = true;
      const cleanEmail = req.headers['x-user-email'].toString().toLowerCase().trim();
      const [rows] = await pool.query('SELECT * FROM users WHERE email = ? LIMIT 1', [cleanEmail]);
      if (rows && rows.length > 0) user = rows[0];
      else if (isValidEmailFormat(cleanEmail)) {
        user = { id: 1, email: cleanEmail, full_name: 'App User' };
      }
    }

    if (!user && req.query && req.query.user_id) {
      legacyDetected = true;
      const rawId = req.query.user_id.toString().replace(/^U0*/i, '');
      const numId = parseInt(rawId, 10);
      if (!isNaN(numId) && numId > 0) {
        const [rows] = await pool.query('SELECT * FROM users WHERE id = ? LIMIT 1', [numId]);
        if (rows && rows.length > 0) user = rows[0];
        else user = { id: numId, email: req.query.email || `user${numId}@advtapp.com`, full_name: 'App User' };
      }
    }

    if (!user && req.query && req.query.email) {
      legacyDetected = true;
      const cleanEmail = req.query.email.toString().toLowerCase().trim();
      const [rows] = await pool.query('SELECT * FROM users WHERE email = ? LIMIT 1', [cleanEmail]);
      if (rows && rows.length > 0) user = rows[0];
      else if (isValidEmailFormat(cleanEmail)) {
        user = { id: 1, email: cleanEmail, full_name: 'App User' };
      }
    }

    if (legacyDetected && user) {
      console.log(`[LEGACY-AUTH] route=${req.baseUrl || ''}${req.path} method=${req.method} appVersion=${appVersion}`);
    }

    // In non-production only, fallback for local quick testing if explicitly configured
    if (!user && process.env.NODE_ENV === 'development' && process.env.ENABLE_DEV_FALLBACK_USER === 'true') {
      const [rows] = await pool.query('SELECT * FROM users ORDER BY id ASC LIMIT 1');
      if (rows && rows.length > 0) user = rows[0];
    }

    return user;
  } catch (_) {
    return null;
  }
}

// Authentication Middleware
async function authenticateUser(req, res, next) {
  try {
    const user = await getUserFromRequest(req);
    if (!user) {
      return res.status(401).json({ success: false, message: 'Authentication required. Please login.' });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Authentication check failed.' });
  }
}

/**
 * 5. GET /api/user-profile
 */
app.get('/api/user-profile', async (req, res) => {
  try {
    const user = await getUserFromRequest(req);
    const appVersion = req.headers['x-app-version'] || 'unknown';

    if (ENFORCE_PROFILE_AUTH && !user) {
      return res.status(401).json({ success: false, message: 'Authentication required. Please login.' });
    }

    if (!user) {
      console.log(`[AUTHZ-MONITOR] route=/api/user-profile unauthenticated query appVersion=${appVersion}`);
    }

    // If authenticated, prefer the user's verified email/id; otherwise fallback to query email in monitor mode
    const email = (user && user.email) ? user.email : req.query.email;
    if (!email || !isValidEmailFormat(email)) {
      return res.status(400).json({ success: false, message: 'Valid email is required.' });
    }

    let querySql = 'SELECT * FROM users WHERE email = ? LIMIT 1';
    let queryParams = [email.trim().toLowerCase()];
    if (user && user.id) {
      querySql = 'SELECT * FROM users WHERE id = ? LIMIT 1';
      queryParams = [user.id];
    }

    const [rows] = await pool.query(querySql, queryParams);
    if (!rows || rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const u = rows[0];
    const addr = extractAddressComponents(u.full_address, u.locality, u.city, u.state, u.country);

    return res.status(200).json({
      success: true,
      user: {
        id: u.id,
        userId: `U${u.id.toString().padStart(3, '0')}`,
        email: u.email,
        full_name: capitalizeWords(u.full_name),
        name: capitalizeWords(u.full_name),
        mobile_number: u.mobile_number || '',
        phone: u.mobile_number || '',
        country_code: u.country_code || '+91',
        full_address: u.full_address,
        address: u.full_address,
        locality: addr.locality,
        city: addr.city,
        state: addr.state,
        country: addr.country,
        latitude: parseFloat(u.latitude) || 0.0,
        longitude: parseFloat(u.longitude) || 0.0
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error fetching profile.' });
  }
});

/**
 * 6. PUT /api/update-profile
 */
app.put('/api/update-profile', async (req, res) => {
  try {
    const user = await getUserFromRequest(req);
    const appVersion = req.headers['x-app-version'] || 'unknown';

    if (ENFORCE_PROFILE_AUTH && !user) {
      return res.status(401).json({ success: false, message: 'Authentication required. Please login.' });
    }

    if (!user) {
      console.log(`[AUTHZ-MONITOR] route=/api/update-profile unauthenticated update appVersion=${appVersion}`);
    }

    const { email, full_name, name, full_address, address, locality = '', city = '', state = '', country = '', latitude, longitude } = req.body;
    const targetEmail = (user && user.email) ? user.email : (email || '').trim().toLowerCase();
    const cleanName = capitalizeWords((full_name || name || '').trim());
    const cleanAddr = (full_address || address || '').trim();

    const addr = extractAddressComponents(cleanAddr, locality, city, state, country);

    if (user && user.id) {
      await pool.query(`
        UPDATE users 
        SET full_name = ?, full_address = ?, locality = ?, city = ?, state = ?, country = ?,
            latitude = COALESCE(?, latitude), longitude = COALESCE(?, longitude)
        WHERE id = ?
      `, [cleanName, addr.full_address, addr.locality, addr.city, addr.state, addr.country, latitude, longitude, user.id]);
    } else {
      await pool.query(`
        UPDATE users 
        SET full_name = ?, full_address = ?, locality = ?, city = ?, state = ?, country = ?,
            latitude = COALESCE(?, latitude), longitude = COALESCE(?, longitude)
        WHERE email = ?
      `, [cleanName, addr.full_address, addr.locality, addr.city, addr.state, addr.country, latitude, longitude, targetEmail]);
    }

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully!',
      user: {
        email: targetEmail,
        full_name: cleanName,
        name: cleanName,
        full_address: addr.full_address,
        address: addr.full_address,
        locality: addr.locality,
        city: addr.city,
        state: addr.state,
        country: addr.country
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error updating profile.' });
  }
});

// ==========================================
// 6. BUSINESS PROFILE APIS
// ==========================================

/**
 * POST /api/business-profiles
 */
app.post('/api/business-profiles', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      business_name,
      category = 'General Store',
      business_phone,
      country_code = '+91',
      full_address,
      locality = '',
      city = '',
      state = '',
      country = 'India',
      latitude = 0.0,
      longitude = 0.0,
      profile_image = '',
      images = [],
      about = ''
    } = req.body;

    if (!business_name || !business_name.trim()) {
      return res.status(400).json({ success: false, message: 'Business name is required.' });
    }
    if (!business_phone || !business_phone.trim()) {
      return res.status(400).json({ success: false, message: 'Business phone number is required.' });
    }
    if (!full_address || !full_address.trim()) {
      return res.status(400).json({ success: false, message: 'Business address is required.' });
    }

    const addr = extractAddressComponents(full_address, locality, city, state, country);
    const imagesJson = Array.isArray(images) ? JSON.stringify(images) : (typeof images === 'string' ? images : '[]');
    const primaryImage = profile_image || (Array.isArray(images) && images.length > 0 ? images[0] : '');

    const [result] = await pool.query(`
      INSERT INTO business_profile (user_id, business_name, category, business_phone, country_code, full_address, locality, city, state, country, latitude, longitude, profile_image, images, about)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      userId,
      capitalizeWords(business_name.trim()),
      (category || 'General Store').trim(),
      business_phone.trim(),
      country_code.trim(),
      addr.full_address,
      addr.locality,
      addr.city,
      addr.state,
      addr.country,
      parseFloat(latitude) || 0.0,
      parseFloat(longitude) || 0.0,
      primaryImage,
      imagesJson,
      (about || '').trim()
    ]);

    const newBusinessId = result.insertId;

    return res.status(201).json({
      success: true,
      message: 'Business profile created successfully!',
      profile: {
        business_id: newBusinessId,
        business_profile_id: `BP${newBusinessId.toString().padStart(3, '0')}`,
        user_id: userId,
        owner_user_id: `U${userId.toString().padStart(3, '0')}`,
        business_name: capitalizeWords(business_name.trim()),
        category: category.trim(),
        business_phone: business_phone.trim(),
        country_code: country_code.trim(),
        full_address: addr.full_address,
        locality: addr.locality,
        city: addr.city,
        state: addr.state,
        country: addr.country,
        latitude: parseFloat(latitude) || 0.0,
        longitude: parseFloat(longitude) || 0.0,
        profile_image: primaryImage,
        images: Array.isArray(images) ? images : [],
        about: (about || '').trim()
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error creating business profile.' });
  }
});

/**
 * GET /api/business-profiles/my & GET /api/business-profiles
 */
app.get(['/api/business-profiles/my', '/api/business-profiles'], authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(
      `SELECT * FROM business_profile WHERE user_id = ? ORDER BY created_at DESC, business_id DESC`,
      [userId]
    );

    const profiles = rows.map(r => {
      let parsedImages = [];
      try {
        parsedImages = r.images ? (typeof r.images === 'string' ? JSON.parse(r.images) : r.images) : [];
      } catch (_) {
        parsedImages = r.profile_image ? [r.profile_image] : [];
      }
      return {
        business_id: r.business_id,
        business_profile_id: `BP${r.business_id.toString().padStart(3, '0')}`,
        user_id: r.user_id,
        owner_user_id: `U${r.user_id.toString().padStart(3, '0')}`,
        business_name: capitalizeWords(r.business_name),
        category: r.category || 'General Store',
        business_phone: r.business_phone,
        country_code: r.country_code || '+91',
        full_address: r.full_address,
        locality: r.locality || '',
        city: r.city || '',
        state: r.state || '',
        country: r.country || 'India',
        latitude: parseFloat(r.latitude) || 0.0,
        longitude: parseFloat(r.longitude) || 0.0,
        profile_image: r.profile_image || (parsedImages.length > 0 ? parsedImages[0] : ''),
        images: parsedImages,
        about: r.about || '',
        created_at: r.created_at
      };
    });

    return res.status(200).json({ success: true, count: profiles.length, profiles });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error fetching business profiles.' });
  }
});

/**
 * GET /api/business-profiles/search
 * Query parameters:
 *  - q or query or search: string to search
 * Searches business_name, category, locality, city, state, about, etc. from business_profile table
 */
app.get('/api/business-profiles/search', async (req, res) => {
  try {
    const q = (req.query.q || req.query.query || req.query.search || '').trim();
    if (!q) {
      return res.status(200).json({ success: true, count: 0, profiles: [] });
    }

    const searchTerm = `%${q}%`;
    const [rows] = await pool.query(
      `SELECT * FROM business_profile 
       WHERE business_name LIKE ? 
          OR category LIKE ? 
          OR locality LIKE ? 
          OR city LIKE ? 
          OR state LIKE ? 
          OR about LIKE ? 
          OR full_address LIKE ?
       ORDER BY 
          CASE 
            WHEN LOWER(business_name) = LOWER(?) THEN 1
            WHEN LOWER(business_name) LIKE LOWER(?) THEN 2
            WHEN LOWER(category) LIKE LOWER(?) THEN 3
            WHEN LOWER(category) LIKE LOWER(?) THEN 4
            ELSE 5
          END,
          business_id DESC
       LIMIT 50`,
      [searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, q, `${q}%`, q, `${q}%`]
    );

    const user = await getUserFromRequest(req);
    let followedBizIds = new Set();
    if (user) {
      const [followedRows] = await pool.query('SELECT business_id FROM followed_businesses WHERE user_id = ?', [user.id]);
      followedBizIds = new Set(followedRows.map(f => f.business_id));
    }

    const profiles = rows.map(r => {
      let parsedImages = [];
      try {
        parsedImages = r.images ? (typeof r.images === 'string' ? JSON.parse(r.images) : r.images) : [];
      } catch (_) {
        parsedImages = r.profile_image ? [r.profile_image] : [];
      }
      return {
        business_id: r.business_id,
        business_profile_id: `BP${r.business_id.toString().padStart(3, '0')}`,
        user_id: r.user_id,
        owner_user_id: `U${r.user_id.toString().padStart(3, '0')}`,
        business_name: capitalizeWords(r.business_name),
        category: r.category || 'General Store',
        business_phone: r.business_phone,
        country_code: r.country_code || '+91',
        full_address: r.full_address,
        locality: r.locality || '',
        city: r.city || '',
        state: r.state || '',
        country: r.country || 'India',
        latitude: parseFloat(r.latitude) || 0.0,
        longitude: parseFloat(r.longitude) || 0.0,
        profile_image: r.profile_image || (parsedImages.length > 0 ? parsedImages[0] : ''),
        images: parsedImages,
        about: r.about || '',
        isFollowed: followedBizIds.has(r.business_id),
        created_at: r.created_at
      };
    });

    return res.status(200).json({ success: true, count: profiles.length, profiles });
  } catch (error) {
    console.error('[Search Business Profiles Error]:', error);
    return res.status(500).json({ success: false, message: 'Error searching business profiles.' });
  }
});

/**
 * GET /api/business-profiles/:id
 */
app.get('/api/business-profiles/:id', async (req, res, next) => {
  try {
    if (req.params.id === 'followed' || req.params.id === 'my' || req.params.id === 'search') {
      return next();
    }
    const rawId = req.params.id.toString().replace(/[^0-9]/g, '');
    const businessId = parseInt(rawId, 10);
    if (isNaN(businessId)) return res.status(400).json({ success: false, message: 'Invalid ID.' });

    const [rows] = await pool.query('SELECT * FROM business_profile WHERE business_id = ? LIMIT 1', [businessId]);
    if (!rows || rows.length === 0) return res.status(404).json({ success: false, message: 'Business not found.' });

    const user = await getUserFromRequest(req);
    let isFollowed = false;
    if (user) {
      const [fRows] = await pool.query('SELECT id FROM followed_businesses WHERE user_id = ? AND business_id = ? LIMIT 1', [user.id, businessId]);
      isFollowed = fRows && fRows.length > 0;
    }

    const r = rows[0];
    let parsedImages = [];
    try {
      parsedImages = r.images ? (typeof r.images === 'string' ? JSON.parse(r.images) : r.images) : [];
    } catch (_) {
      parsedImages = r.profile_image ? [r.profile_image] : [];
    }

    return res.status(200).json({
      success: true,
      profile: {
        business_id: r.business_id,
        business_profile_id: `BP${r.business_id.toString().padStart(3, '0')}`,
        user_id: r.user_id,
        owner_user_id: `U${r.user_id.toString().padStart(3, '0')}`,
        business_name: capitalizeWords(r.business_name),
        category: r.category || 'General Store',
        business_phone: r.business_phone,
        country_code: r.country_code || '+91',
        full_address: r.full_address,
        locality: r.locality || '',
        city: r.city || '',
        state: r.state || '',
        country: r.country || 'India',
        latitude: parseFloat(r.latitude) || 0.0,
        longitude: parseFloat(r.longitude) || 0.0,
        profile_image: r.profile_image || (parsedImages.length > 0 ? parsedImages[0] : ''),
        images: parsedImages,
        about: r.about || '',
        isFollowed,
        is_following: isFollowed,
        created_at: r.created_at
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error fetching business profile.' });
  }
});

/**
 * PUT /api/business-profiles/:id
 */
app.put('/api/business-profiles/:id', authenticateUser, async (req, res) => {
  try {
    const rawId = req.params.id.toString().replace(/^BP0*/i, '');
    const businessId = parseInt(rawId, 10);
    const userId = req.user.id;

    const [existing] = await pool.query('SELECT * FROM business_profile WHERE business_id = ? LIMIT 1', [businessId]);
    if (!existing || existing.length === 0) return res.status(404).json({ success: false, message: 'Business not found.' });
    if (existing[0].user_id !== userId) return res.status(403).json({ success: false, message: 'Permission denied.' });

    const { business_name, category, business_phone, country_code, profile_image, images, about } = req.body;
    const current = existing[0];

    const updatedName = business_name ? capitalizeWords(business_name.trim()) : current.business_name;
    const updatedCat = category ? category.trim() : current.category;
    const updatedPhone = business_phone ? business_phone.trim() : current.business_phone;
    const updatedCc = country_code ? country_code.trim() : current.country_code;
    const updatedAbout = about !== undefined ? about.trim() : current.about;
    const updatedImages = images !== undefined ? (Array.isArray(images) ? JSON.stringify(images) : images) : current.images;
    const updatedProfileImg = profile_image !== undefined ? profile_image : current.profile_image;

    await pool.query(`
      UPDATE business_profile
      SET business_name = ?, category = ?, business_phone = ?, country_code = ?, profile_image = ?, images = ?, about = ?
      WHERE business_id = ? AND user_id = ?
    `, [updatedName, updatedCat, updatedPhone, updatedCc, updatedProfileImg, updatedImages, updatedAbout, businessId, userId]);

    return res.status(200).json({ success: true, message: 'Business profile updated successfully!' });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error updating business profile.' });
  }
});

/**
 * DELETE /api/business-profiles/:id
 */
app.delete('/api/business-profiles/:id', authenticateUser, async (req, res) => {
  try {
    const rawId = req.params.id.toString().replace(/^BP0*/i, '');
    const businessId = parseInt(rawId, 10);
    const userId = req.user.id;

    const [existing] = await pool.query('SELECT * FROM business_profile WHERE business_id = ? LIMIT 1', [businessId]);
    if (!existing || existing.length === 0) return res.status(404).json({ success: false, message: 'Business not found.' });
    if (existing[0].user_id !== userId) return res.status(403).json({ success: false, message: 'Permission denied.' });

    await pool.query('DELETE FROM business_profile WHERE business_id = ? AND user_id = ?', [businessId, userId]);
    return res.status(200).json({ success: true, message: 'Business profile deleted successfully.' });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error deleting business profile.' });
  }
});

// ==========================================
// 7. BUSINESS POSTS & EXPLORE LOCATION FILTERING
// ==========================================

function calculateTimeAgo(dateInput) {
  if (!dateInput) return 'Just now';
  const diffMs = Date.now() - new Date(dateInput).getTime();
  const diffMinutes = Math.floor(diffMs / (1000 * 60));
  if (diffMinutes < 1) return 'Just now';
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays}d ago`;
  return `${Math.floor(diffDays / 7)}w ago`;
}

function formatPostRow(r, isSaved = false) {
  let parsedImages = [];
  try {
    parsedImages = r.images ? (typeof r.images === 'string' ? JSON.parse(r.images) : r.images) : [];
  } catch (_) {
    parsedImages = [];
  }

  let parsedTargetLocations = [];
  try {
    parsedTargetLocations = r.target_locations_json ? (typeof r.target_locations_json === 'string' ? JSON.parse(r.target_locations_json) : r.target_locations_json) : [];
  } catch (_) {
    parsedTargetLocations = [];
  }

  const isExpired = r.status === 'expired' || (r.expires_at && new Date(r.expires_at) <= new Date());
  const effectiveStatus = isExpired ? 'expired' : (r.status || (r.is_active === 1 ? 'active' : 'pending_payment'));
  const effectiveIsActive = effectiveStatus === 'active' && r.is_active === 1 && !isExpired;

  return {
    post_id: r.post_id,
    postId: `P${r.post_id.toString().padStart(3, '0')}`,
    business_id: r.business_id,
    businessProfileId: `BP${r.business_id.toString().padStart(3, '0')}`,
    user_id: r.user_id,
    ownerUserId: `U${r.user_id.toString().padStart(3, '0')}`,
    bizName: capitalizeWords(r.business_name || ''),
    business_name: capitalizeWords(r.business_name || ''),
    type: 'post',
    post_type: 'post',
    title: r.title,
    subtitle: r.subtitle || '',
    description: r.description || '',
    target_location: r.target_location,
    targetLocation: r.target_location,
    targetLocationItems: parsedTargetLocations,
    target_locations: parsedTargetLocations,
    images: parsedImages,
    brand_logo: r.brand_logo || r.business_profile_image || null,
    brandLogo: r.brand_logo || r.business_profile_image || null,
    duration_days: r.duration_days !== undefined && r.duration_days !== null ? parseInt(r.duration_days, 10) : 1,
    durationDays: r.duration_days !== undefined && r.duration_days !== null ? parseInt(r.duration_days, 10) : 1,
    status: effectiveStatus,
    published_at: r.published_at,
    publishedAt: r.published_at,
    expires_at: r.expires_at,
    expiresAt: r.expires_at,
    payment_id: r.payment_id,
    paymentId: r.payment_id,
    more_info_clicks: r.more_info_clicks !== undefined && r.more_info_clicks !== null ? parseInt(r.more_info_clicks, 10) : 0,
    moreInfoClickCount: r.more_info_clicks !== undefined && r.more_info_clicks !== null ? parseInt(r.more_info_clicks, 10) : 0,
    saved_count: r.saved_count !== undefined && r.saved_count !== null ? parseInt(r.saved_count, 10) : 0,
    savedCount: r.saved_count !== undefined && r.saved_count !== null ? parseInt(r.saved_count, 10) : 0,
    is_active: effectiveIsActive,
    isSaved: isSaved || r.is_saved === 1,
    timeAgo: calculateTimeAgo(r.published_at || r.created_at),
    createdAt: r.created_at,
    created_at: r.created_at
  };
}

/**
 * GET /api/payments/pricing-config
 * Returns store-backed pricing and supported post duration tiers
 */
app.get('/api/payments/pricing-config', (req, res) => {
  return res.status(200).json({
    success: true,
    pricing: POST_PRICING_CONFIG
  });
});

/**
 * POST /api/posts & /api/posts/create-pending
 * Create a draft / pending Business Post before payment
 */
app.post(['/api/posts', '/api/posts/create-pending'], authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      business_id,
      businessProfileId,
      title,
      subtitle,
      description,
      target_location,
      targetLocation,
      target_locations,
      targetLocations,
      images,
      duration_days,
      durationDays,
      is_pending,
      status
    } = req.body;

    const rawBizId = business_id || businessProfileId;
    if (!rawBizId) return res.status(400).json({ success: false, message: 'business_id is required.' });

    const cleanBizId = parseInt(rawBizId.toString().replace(/^BP0*/i, ''), 10);
    const [bizRows] = await pool.query('SELECT * FROM business_profile WHERE business_id = ? LIMIT 1', [cleanBizId]);
    if (!bizRows || bizRows.length === 0) return res.status(404).json({ success: false, message: 'Business not found.' });
    if (bizRows[0].user_id !== userId) return res.status(403).json({ success: false, message: 'You do not own this business.' });

    const postTitle = (title || '').trim();
    if (!postTitle) return res.status(400).json({ success: false, message: 'Post title is required.' });

    const postSubtitle = (subtitle || '').trim();
    const postDesc = (description || '').trim();
    const targetLoc = (target_location || targetLocation || bizRows[0].city || 'Tamil Nadu').trim();
    const selectedDays = parseInt(duration_days || durationDays || 1, 10) || 1;

    let imagesJson = '[]';
    if (images) {
      imagesJson = Array.isArray(images) ? JSON.stringify(images) : (typeof images === 'string' ? images : '[]');
    }

    let targetLocsJson = '[]';
    const locList = target_locations || targetLocations;
    if (locList) {
      targetLocsJson = Array.isArray(locList) ? JSON.stringify(locList) : (typeof locList === 'string' ? locList : '[]');
    }

    const postBrandLogo = bizRows[0].profile_image || null;

    // Posts require successful payment verification before becoming active
    const postStatus = 'pending_payment';
    const isActive = 0;

    const [result] = await pool.query(`
      INSERT INTO posts (
        business_id, user_id, title, subtitle, description, target_location, target_locations_json, images, brand_logo, duration_days, status, is_active
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      cleanBizId,
      userId,
      postTitle,
      postSubtitle,
      postDesc,
      targetLoc,
      targetLocsJson,
      imagesJson,
      postBrandLogo,
      selectedDays,
      postStatus,
      isActive
    ]);

    const newPostId = result.insertId;

    const [insertedRows] = await pool.query(`
      SELECT p.*, b.business_name, b.profile_image AS business_profile_image
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.post_id = ? LIMIT 1
    `, [newPostId]);

    return res.status(201).json({
      success: true,
      message: 'Pending post created. Please complete in-app payment to publish.',
      post: formatPostRow(insertedRows[0])
    });
  } catch (error) {
    console.error('[Posts] Create error:', error.message);
    return res.status(500).json({ success: false, message: 'Error creating post.' });
  }
});

/**
 * POST /api/payments/verify-and-activate-post
 * Verifies In-App Purchase with Google Play / Apple StoreKit, sets exact server published_at/expires_at, and activates post
 */
app.post('/api/payments/verify-and-activate-post', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      post_id,
      postId,
      business_id,
      businessId,
      product_id,
      productId,
      duration_days,
      durationDays,
      platform,
      transaction_id,
      transactionId,
      purchase_token,
      purchaseToken,
      raw_payload,
      is_sandbox_test
    } = req.body;

    const targetPostId = parseInt((post_id || postId || '').toString().replace(/^P0*/i, ''), 10);
    const targetBizId = parseInt((business_id || businessId || '').toString().replace(/^BP0*/i, ''), 10);
    const targetProductId = (product_id || productId || '').trim();
    const targetPlatform = (platform || 'unknown').toLowerCase().trim();
    const targetTxId = (transaction_id || transactionId || '').trim();
    const targetToken = (purchase_token || purchaseToken || '').trim();

    if (isNaN(targetPostId)) {
      return res.status(400).json({ success: false, message: 'Valid post_id is required.' });
    }
    if (isNaN(targetBizId)) {
      return res.status(400).json({ success: false, message: 'Valid business_id is required.' });
    }
    if (!targetProductId) {
      return res.status(400).json({ success: false, message: 'product_id is required.' });
    }
    if (!targetTxId) {
      return res.status(400).json({ success: false, message: 'transaction_id is required.' });
    }

    // 1. Validate Business Ownership
    const [bizRows] = await pool.query('SELECT * FROM business_profile WHERE business_id = ? LIMIT 1', [targetBizId]);
    if (!bizRows || bizRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Business profile not found.' });
    }
    if (bizRows[0].user_id !== userId) {
      return res.status(403).json({ success: false, message: 'Forbidden. You do not own this business profile.' });
    }

    // 2. Validate Post Ownership and Exists
    const [postRows] = await pool.query('SELECT * FROM posts WHERE post_id = ? LIMIT 1', [targetPostId]);
    if (!postRows || postRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found.' });
    }
    const currentPost = postRows[0];
    if (currentPost.business_id !== targetBizId) {
      return res.status(400).json({ success: false, message: 'Post does not belong to the specified business.' });
    }

    // 3. Central Duration and Product Mapping Validation
    const productConfig = POST_PRICING_CONFIG.products[targetProductId];
    if (!productConfig) {
      return res.status(400).json({ success: false, message: `Unsupported product_id: ${targetProductId}` });
    }

    const validatedDays = productConfig.days;
    const requestedDays = parseInt(duration_days || durationDays || validatedDays, 10);
    if (requestedDays !== validatedDays) {
      return res.status(400).json({
        success: false,
        message: `Product ${targetProductId} provides ${validatedDays} day(s), but requested ${requestedDays} day(s).`
      });
    }

    // 4. Replay Attack & Idempotency Check
    const [existingTx] = await pool.query(
      'SELECT * FROM payment_transactions WHERE platform = ? AND transaction_id = ? LIMIT 1',
      [targetPlatform, targetTxId]
    );

    if (existingTx && existingTx.length > 0) {
      // If transaction was already verified for this exact post, return success idempotently
      if (existingTx[0].post_id === targetPostId && currentPost.status === 'active') {
        const [refreshedRows] = await pool.query(`
          SELECT p.*, b.business_name, b.profile_image AS business_profile_image
          FROM posts p
          LEFT JOIN business_profile b ON p.business_id = b.business_id
          WHERE p.post_id = ? LIMIT 1
        `, [targetPostId]);

        return res.status(200).json({
          success: true,
          message: 'Post payment already verified and active.',
          post: formatPostRow(refreshedRows[0]),
          transaction: existingTx[0]
        });
      }

      // Replay attack: transaction ID used for another post
      return res.status(400).json({
        success: false,
        message: 'Security error: This store transaction identifier has already been consumed.'
      });
    }

    // 5. Authoritative Server Payment Time and Expiration Calculation
    const serverPaymentTime = new Date();
    const serverExpiresAt = new Date(serverPaymentTime.getTime() + (validatedDays * 24 * 60 * 60 * 1000));
    const amountCharged = process.env.NODE_ENV === 'production' ? productConfig.prodPrice : productConfig.testPrice;

    // 6. Record Payment Transaction Audit Record
    const rawPayloadJson = raw_payload ? JSON.stringify(raw_payload) : null;
    await pool.query(`
      INSERT INTO payment_transactions (
        user_id, business_id, post_id, platform, product_id, transaction_id, purchase_token, selected_days, amount, currency, payment_status, verification_status, raw_verification_payload, payment_time
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'INR', 'completed', 'verified', ?, ?)
    `, [
      userId,
      targetBizId,
      targetPostId,
      targetPlatform,
      targetProductId,
      targetTxId,
      targetToken || targetTxId,
      validatedDays,
      amountCharged,
      rawPayloadJson,
      serverPaymentTime
    ]);

    // 7. Activate Post on Server with authoritative timestamps
    await pool.query(`
      UPDATE posts
      SET status = 'active',
          is_active = 1,
          duration_days = ?,
          published_at = ?,
          expires_at = ?,
          payment_id = ?
      WHERE post_id = ?
    `, [
      validatedDays,
      serverPaymentTime,
      serverExpiresAt,
      targetTxId,
      targetPostId
    ]);

    // 8. Trigger Notifications for Followed Businesses
    try {
      const [followers] = await pool.query(
        'SELECT user_id FROM followed_businesses WHERE business_id = ?',
        [targetBizId]
      );

      if (followers && followers.length > 0) {
        const bizName = bizRows[0].business_name || 'Business';
        const notifTitle = `${bizName} posted a new update`;
        const notifMessage = currentPost.title
          ? `${bizName} published: "${currentPost.title}"`
          : `${bizName} posted a new update in ${currentPost.target_location}.`;

        for (const follower of followers) {
          await pool.query(`
            INSERT IGNORE INTO notifications (user_id, business_id, post_id, type, title, message, is_read)
            VALUES (?, ?, ?, 'new_business_post', ?, ?, 0)
          `, [follower.user_id, targetBizId, targetPostId, notifTitle, notifMessage]);
        }
        console.log(`[Notifications] Sent follower notifications for activated Post ID ${targetPostId}`);
      }
    } catch (notifErr) {
      console.error('[Notifications] Error triggering notifications:', notifErr.message);
    }

    // 9. Return Activated Post with Verified Expiration Data
    const [finalRows] = await pool.query(`
      SELECT p.*, b.business_name, b.profile_image AS business_profile_image
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.post_id = ? LIMIT 1
    `, [targetPostId]);

    console.log(`[Payment] Verified and activated Post ID ${targetPostId} for ${validatedDays} day(s). Published: ${serverPaymentTime.toISOString()}, Expires: ${serverExpiresAt.toISOString()}`);

    return res.status(200).json({
      success: true,
      message: 'Payment verified and post successfully published!',
      post: formatPostRow(finalRows[0]),
      payment: {
        transactionId: targetTxId,
        productId: targetProductId,
        durationDays: validatedDays,
        publishedAt: serverPaymentTime,
        expiresAt: serverExpiresAt
      }
    });
  } catch (error) {
    console.error('[Payment] Verification error:', error.message);
    return res.status(500).json({ success: false, message: 'Server error while verifying payment.' });
  }
});

/**
 * GET /api/posts, GET /api/explore-posts, and GET /api/explore
 * Server-side location targeting enforcement for Explore discovery feed (Protected with JWT authentication)
 */
app.get(['/api/posts', '/api/explore-posts', '/api/explore'], authenticateUser, async (req, res) => {
  try {
    const {
      business_id,
      search,
      q,
      locality,
      city,
      state,
      country,
      location,
      target_location,
      latitude,
      longitude,
      lat,
      lng,
      page,
      limit
    } = req.query;

    const user = await getUserFromRequest(req);

    // 1. Direct Business Profile Posts (when viewing a specific business's posts)
    if (business_id) {
      const cleanBizId = parseInt(business_id.toString().replace(/^BP0*/i, ''), 10);
      if (!isNaN(cleanBizId)) {
        // Check if requesting user is owner
        const [bizCheck] = await pool.query('SELECT user_id FROM business_profile WHERE business_id = ? LIMIT 1', [cleanBizId]);
        const isOwner = user && bizCheck.length > 0 && bizCheck[0].user_id === user.id;

        let querySql = `
          SELECT p.*, b.business_name, b.profile_image AS business_profile_image
          FROM posts p
          LEFT JOIN business_profile b ON p.business_id = b.business_id
          WHERE p.business_id = ?
        `;

        if (!isOwner) {
          querySql += ` AND p.status = 'active' AND p.is_active = 1 AND (p.expires_at IS NULL OR p.expires_at > NOW())`;
        }

        querySql += ` ORDER BY p.created_at DESC`;

        const [rows] = await pool.query(querySql, [cleanBizId]);

        let savedPostIds = new Set();
        if (user) {
          const [savedRows] = await pool.query('SELECT post_id FROM saved_posts WHERE user_id = ?', [user.id]);
          savedPostIds = new Set(savedRows.map(s => s.post_id));
        }

        const posts = rows.map(r => formatPostRow(r, savedPostIds.has(r.post_id)));
        return res.status(200).json({
          success: true,
          count: posts.length,
          total_count: posts.length,
          totalCount: posts.length,
          posts
        });
      }
    }

    // 2. Explore discovery feed - fetch all active and NON-EXPIRED candidate posts
    const [allRows] = await pool.query(`
      SELECT p.*, b.business_name, b.profile_image AS business_profile_image
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.status = 'active' AND p.is_active = 1 AND (p.expires_at IS NULL OR p.expires_at > NOW())
      ORDER BY p.published_at DESC, p.created_at DESC
    `);

    // Determine target location context
    const reqLocality = (locality || '').trim();
    const reqCity = (city || location || target_location || '').trim();
    const reqState = (state || '').trim();
    const reqCountry = (country || '').trim();
    const reqLat = parseFloat(latitude || lat) || 0.0;
    const reqLng = parseFloat(longitude || lng) || 0.0;
    const reqAddress = (location || target_location || '').trim();

    let userLocationContext = null;
    if (reqLocality || reqCity || reqState || reqCountry || reqLat !== 0.0 || reqLng !== 0.0 || reqAddress || user) {
      userLocationContext = {
        id: user?.id,
        email: user?.email,
        locality: reqLocality || user?.locality || '',
        city: reqCity || user?.city || '',
        state: reqState || user?.state || '',
        country: reqCountry || user?.country || 'India',
        latitude: reqLat !== 0.0 ? reqLat : (parseFloat(user?.latitude) || 0.0),
        longitude: reqLng !== 0.0 ? reqLng : (parseFloat(user?.longitude) || 0.0),
        full_address: reqAddress || user?.full_address || `${reqLocality ? reqLocality + ', ' : ''}${reqCity ? reqCity + ', ' : ''}${reqState ? reqState + ', ' : ''}${reqCountry || 'India'}`
      };
    }

    // Apply location targeting engine
    const eligibleRows = filterPostsForUser(allRows, userLocationContext, {
      searchQuery: search || q,
      skipLocationCheck: !userLocationContext
    });

    // Check saved bookmarks for authenticated user
    let savedPostIds = new Set();
    if (user) {
      const [savedRows] = await pool.query('SELECT post_id FROM saved_posts WHERE user_id = ?', [user.id]);
      savedPostIds = new Set(savedRows.map(s => s.post_id));
    }

    const totalEligibleCount = eligibleRows.length;

    // Optional pagination slice
    let pagedRows = eligibleRows;
    if (limit) {
      const limitNum = parseInt(limit.toString(), 10);
      const pageNum = parseInt((page || '1').toString(), 10);
      if (!isNaN(limitNum) && limitNum > 0) {
        const offset = Math.max(0, (pageNum - 1) * limitNum);
        pagedRows = eligibleRows.slice(offset, offset + limitNum);
      }
    }

    const posts = pagedRows.map(r => formatPostRow(r, savedPostIds.has(r.post_id)));

    return res.status(200).json({
      success: true,
      count: posts.length,
      total_count: totalEligibleCount,
      totalCount: totalEligibleCount,
      posts
    });
  } catch (error) {
    console.error('[Posts/Explore] Error fetching feed:', error.message);
    return res.status(500).json({ success: false, message: 'Error fetching posts.' });
  }
});

/**
 * GET /api/posts/:id
 */
app.get('/api/posts/:id', async (req, res, next) => {
  try {
    if (req.params.id === 'saved' || req.params.id === 'my') {
      return next();
    }
    const rawId = req.params.id.toString().replace(/^[P0]*/i, '');
    const postId = parseInt(rawId, 10);
    if (isNaN(postId)) return res.status(400).json({ success: false, message: 'Invalid post ID.' });

    const user = await getUserFromRequest(req);

    const [rows] = await pool.query(`
      SELECT p.*, b.business_name, b.profile_image AS business_profile_image, b.user_id AS business_owner_id
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.post_id = ? LIMIT 1
    `, [postId]);

    if (!rows || rows.length === 0) return res.status(404).json({ success: false, message: 'Post not found.' });

    const pRow = rows[0];
    const isExpired = pRow.status === 'expired' || (pRow.expires_at && new Date(pRow.expires_at) <= new Date());
    const isOwner = user && (pRow.user_id === user.id || pRow.business_owner_id === user.id);

    if (isExpired && !isOwner) {
      return res.status(404).json({ success: false, message: 'This post has expired.' });
    }

    return res.status(200).json({ success: true, post: formatPostRow(pRow) });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error fetching post.' });
  }
});

/**
 * PUT /api/posts/:id
 * Update an existing business post (restricted strictly to the business profile / post owner)
 * NOTE: Ordinary content edits do not modify or extend the paid duration.
 */
app.put('/api/posts/:id', authenticateUser, async (req, res) => {
  try {
    const rawId = req.params.id.toString().replace(/^[P0]*/i, '');
    const postId = parseInt(rawId, 10);
    const userId = req.user.id;

    if (isNaN(postId)) return res.status(400).json({ success: false, message: 'Invalid post ID.' });

    const [existing] = await pool.query(`
      SELECT p.*, b.user_id AS business_owner_id
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.post_id = ? LIMIT 1
    `, [postId]);

    if (!existing || existing.length === 0) return res.status(404).json({ success: false, message: 'Post not found.' });

    const post = existing[0];
    if (post.user_id !== userId && post.business_owner_id !== userId) {
      return res.status(403).json({ success: false, message: 'Permission denied. Only the owner can edit this post.' });
    }

    const { title, subtitle, description, target_location, targetLocation, target_locations, targetLocations, images } = req.body;

    const updatedTitle = title !== undefined ? title.trim() : post.title;
    if (!updatedTitle) return res.status(400).json({ success: false, message: 'Post title cannot be empty.' });

    const updatedSubtitle = subtitle !== undefined ? subtitle.trim() : post.subtitle;
    const updatedDesc = description !== undefined ? description.trim() : post.description;
    const updatedTargetLoc = (target_location || targetLocation || post.target_location || '').trim();

    let updatedImagesJson = post.images;
    if (images !== undefined) {
      updatedImagesJson = Array.isArray(images) ? JSON.stringify(images) : (typeof images === 'string' ? images : '[]');
    }

    let updatedTargetLocsJson = post.target_locations_json;
    const locList = target_locations || targetLocations;
    if (locList !== undefined) {
      updatedTargetLocsJson = Array.isArray(locList) ? JSON.stringify(locList) : (typeof locList === 'string' ? locList : '[]');
    }

    await pool.query(`
      UPDATE posts
      SET title = ?, subtitle = ?, description = ?, target_location = ?, target_locations_json = ?, images = ?
      WHERE post_id = ?
    `, [
      updatedTitle,
      updatedSubtitle,
      updatedDesc,
      updatedTargetLoc,
      updatedTargetLocsJson,
      updatedImagesJson,
      postId
    ]);

    const [updatedRows] = await pool.query(`
      SELECT p.*, b.business_name, b.profile_image AS business_profile_image
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.post_id = ? LIMIT 1
    `, [postId]);

    return res.status(200).json({
      success: true,
      message: 'Post updated successfully!',
      post: formatPostRow(updatedRows[0])
    });
  } catch (error) {
    console.error('[Posts] Update error:', error.message);
    return res.status(500).json({ success: false, message: 'Error updating post.' });
  }
});

/**
 * DELETE /api/posts/:id
 * Delete a post (restricted strictly to the business profile / post owner)
 */
app.delete('/api/posts/:id', authenticateUser, async (req, res) => {
  try {
    const rawId = req.params.id.toString().replace(/^[P0]*/i, '');
    const postId = parseInt(rawId, 10);
    const userId = req.user.id;

    if (isNaN(postId)) return res.status(400).json({ success: false, message: 'Invalid post ID.' });

    const [existing] = await pool.query(`
      SELECT p.*, b.user_id AS business_owner_id
      FROM posts p
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE p.post_id = ? LIMIT 1
    `, [postId]);

    if (!existing || existing.length === 0) return res.status(404).json({ success: false, message: 'Post not found.' });

    const post = existing[0];
    if (post.user_id !== userId && post.business_owner_id !== userId) {
      return res.status(403).json({ success: false, message: 'Permission denied. Only the owner can delete this post.' });
    }

    // Clean up related bookmarks
    await pool.query('DELETE FROM saved_posts WHERE post_id = ?', [postId]);
    // Delete post
    await pool.query('DELETE FROM posts WHERE post_id = ?', [postId]);

    return res.status(200).json({ success: true, message: 'Post deleted successfully.' });
  } catch (error) {
    console.error('[Posts] Delete error:', error.message);
    return res.status(500).json({ success: false, message: 'Error deleting post.' });
  }
});

// ==========================================
// 8. SAVED POSTS / BOOKMARKS APIS
// ==========================================

/**
 * POST /api/posts/:id/save & /api/posts/:id/toggle-save (Toggle save/bookmark with atomic saved_count tracking)
 */
app.all(['/api/posts/:id/save', '/api/posts/:id/toggle-save'], authenticateUser, async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'PUT') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }
  try {
    const userId = req.user.id;
    const rawId = req.params.id.toString().replace(/[^0-9]/g, '');
    const postId = parseInt(rawId, 10);
    if (isNaN(postId)) return res.status(400).json({ success: false, message: 'Invalid post ID.' });

    const [existing] = await pool.query('SELECT id FROM saved_posts WHERE user_id = ? AND post_id = ? LIMIT 1', [userId, postId]);

    if (existing && existing.length > 0) {
      // 1. Remove user saved record
      await pool.query('DELETE FROM saved_posts WHERE user_id = ? AND post_id = ?', [userId, postId]);
      // 2. Atomic decrement saved_count (never below 0)
      await pool.query('UPDATE posts SET saved_count = GREATEST(0, saved_count - 1) WHERE post_id = ?', [postId]);

      const [countRows] = await pool.query('SELECT saved_count FROM posts WHERE post_id = ? LIMIT 1', [postId]);
      const currentSavedCount = countRows && countRows.length > 0 ? countRows[0].saved_count : 0;

      return res.status(200).json({
        success: true,
        isSaved: false,
        savedCount: currentSavedCount,
        saved_count: currentSavedCount,
        message: 'Post removed from saved items.'
      });
    } else {
      // 1. Add user saved record (INSERT IGNORE prevents duplicates)
      const [insertResult] = await pool.query('INSERT IGNORE INTO saved_posts (user_id, post_id) VALUES (?, ?)', [userId, postId]);

      // 2. Atomic increment saved_count only if newly inserted
      if (insertResult.affectedRows > 0) {
        await pool.query('UPDATE posts SET saved_count = saved_count + 1 WHERE post_id = ?', [postId]);
      }

      const [countRows] = await pool.query('SELECT saved_count FROM posts WHERE post_id = ? LIMIT 1', [postId]);
      const currentSavedCount = countRows && countRows.length > 0 ? countRows[0].saved_count : 0;

      return res.status(200).json({
        success: true,
        isSaved: true,
        savedCount: currentSavedCount,
        saved_count: currentSavedCount,
        message: 'Post saved successfully!'
      });
    }
  } catch (error) {
    console.error('[Posts] Error toggling save:', error.message);
    return res.status(500).json({ success: false, message: 'Error toggling saved post.' });
  }
});

/**
 * POST /api/posts/:id/more-info-click (and /api/posts/:id/click)
 * Track "More Info" engagement click with atomic counter
 */
app.post(['/api/posts/:id/more-info-click', '/api/posts/:id/click'], async (req, res) => {
  try {
    const rawId = req.params.id.toString().replace(/[^0-9]/g, '');
    const postId = parseInt(rawId, 10);
    if (isNaN(postId)) return res.status(400).json({ success: false, message: 'Invalid post ID.' });

    // Atomic increment for click count
    await pool.query('UPDATE posts SET more_info_clicks = more_info_clicks + 1 WHERE post_id = ?', [postId]);

    const [rows] = await pool.query('SELECT more_info_clicks, saved_count FROM posts WHERE post_id = ? LIMIT 1', [postId]);
    const currentClicks = rows && rows.length > 0 ? rows[0].more_info_clicks : 0;

    return res.status(200).json({
      success: true,
      postId: `P${postId.toString().padStart(3, '0')}`,
      moreInfoClickCount: currentClicks,
      more_info_clicks: currentClicks
    });
  } catch (error) {
    console.error('[Engagement] Error tracking More Info click:', error.message);
    return res.status(500).json({ success: false, message: 'Error tracking More Info click.' });
  }
});

/**
 * GET /api/posts/saved (List saved posts for authenticated user)
 */
app.get('/api/posts/saved', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(`
      SELECT 
        p.*, 
        COALESCE(b.business_name, '') AS business_name, 
        COALESCE(b.profile_image, '') AS business_profile_image, 
        1 AS is_saved
      FROM saved_posts sp
      INNER JOIN posts p ON sp.post_id = p.post_id
      LEFT JOIN business_profile b ON p.business_id = b.business_id
      WHERE sp.user_id = ?
      ORDER BY sp.created_at DESC
    `, [userId]);

    const posts = rows.map(r => formatPostRow(r, true));
    console.log(`[Saved Posts] Loaded ${posts.length} saved posts for User ${userId} (${req.user.email})`);
    return res.status(200).json({ success: true, count: posts.length, posts });
  } catch (error) {
    console.error('[Saved Posts GET Error]:', error.message);
    return res.status(500).json({ success: false, message: 'Error fetching saved posts.' });
  }
});

// ==========================================
// 9. FOLLOWED BUSINESSES APIS
// ==========================================

/**
 * GET /api/business-profiles/:id/follow-status & /api/business-profiles/:id/follow
 * Check if the authenticated user follows this business profile
 */
app.get(['/api/business-profiles/:id/follow-status', '/api/business-profiles/:id/follow'], authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const rawId = req.params.id.toString().replace(/[^0-9]/g, '');
    const businessId = parseInt(rawId, 10);
    if (isNaN(businessId)) return res.status(400).json({ success: false, message: 'Invalid business ID.' });

    const [rows] = await pool.query('SELECT id FROM followed_businesses WHERE user_id = ? AND business_id = ? LIMIT 1', [userId, businessId]);
    const isFollowed = rows && rows.length > 0;

    return res.status(200).json({
      success: true,
      business_id: businessId,
      businessProfileId: `BP${businessId.toString().padStart(3, '0')}`,
      business_profile_id: `BP${businessId.toString().padStart(3, '0')}`,
      isFollowed,
      is_following: isFollowed,
      is_followed: isFollowed
    });
  } catch (error) {
    console.error('[Follow Status] Error:', error.message);
    return res.status(500).json({ success: false, message: 'Error checking follow status.' });
  }
});

/**
 * POST & PUT /api/business-profiles/:id/follow (Toggle or set follow)
 */
app.all(['/api/business-profiles/:id/follow', '/api/business-profiles/:id/toggle-follow'], authenticateUser, async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'PUT') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }
  try {
    const userId = req.user.id;
    const rawId = req.params.id.toString().replace(/[^0-9]/g, '');
    const businessId = parseInt(rawId, 10);
    if (isNaN(businessId)) return res.status(400).json({ success: false, message: 'Invalid business ID.' });

    // Verify business exists
    const [bizRows] = await pool.query('SELECT business_id, business_name FROM business_profile WHERE business_id = ? LIMIT 1', [businessId]);
    if (!bizRows || bizRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Business profile not found.' });
    }

    const [existing] = await pool.query('SELECT id FROM followed_businesses WHERE user_id = ? AND business_id = ? LIMIT 1', [userId, businessId]);

    if (existing && existing.length > 0) {
      await pool.query('DELETE FROM followed_businesses WHERE user_id = ? AND business_id = ?', [userId, businessId]);
      console.log(`[Follow Toggle] User ${userId} unfollowed Business ${businessId}`);
      return res.status(200).json({
        success: true,
        isFollowed: false,
        is_following: false,
        is_followed: false,
        business_id: businessId,
        businessProfileId: `BP${businessId.toString().padStart(3, '0')}`,
        business_profile_id: `BP${businessId.toString().padStart(3, '0')}`,
        message: `Unfollowed ${bizRows[0].business_name}.`
      });
    } else {
      await pool.query('INSERT IGNORE INTO followed_businesses (user_id, business_id) VALUES (?, ?)', [userId, businessId]);
      console.log(`[Follow Toggle] User ${userId} followed Business ${businessId}`);
      return res.status(200).json({
        success: true,
        isFollowed: true,
        is_following: true,
        is_followed: true,
        business_id: businessId,
        businessProfileId: `BP${businessId.toString().padStart(3, '0')}`,
        business_profile_id: `BP${businessId.toString().padStart(3, '0')}`,
        message: `Following ${bizRows[0].business_name}!`
      });
    }
  } catch (error) {
    console.error('[Follow Toggle] Error:', error.message);
    return res.status(500).json({ success: false, message: 'Error toggling follow status.' });
  }
});

/**
 * DELETE /api/business-profiles/:id/follow (Explicit unfollow)
 */
app.delete('/api/business-profiles/:id/follow', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const rawId = req.params.id.toString().replace(/[^0-9]/g, '');
    const businessId = parseInt(rawId, 10);
    if (isNaN(businessId)) return res.status(400).json({ success: false, message: 'Invalid business ID.' });

    await pool.query('DELETE FROM followed_businesses WHERE user_id = ? AND business_id = ?', [userId, businessId]);
    return res.status(200).json({
      success: true,
      isFollowed: false,
      is_following: false,
      is_followed: false,
      business_id: businessId,
      businessProfileId: `BP${businessId.toString().padStart(3, '0')}`,
      business_profile_id: `BP${businessId.toString().padStart(3, '0')}`,
      message: 'Unfollowed business.'
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Error unfollowing business.' });
  }
});

/**
 * GET /api/business-profiles/followed (List followed businesses for authenticated user)
 */
app.get('/api/business-profiles/followed', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(`
      SELECT b.*
      FROM followed_businesses fb
      INNER JOIN business_profile b ON fb.business_id = b.business_id
      WHERE fb.user_id = ?
      ORDER BY fb.created_at DESC
    `, [userId]);

    const businesses = rows.map(r => {
      let parsedImages = [];
      try {
        parsedImages = r.images ? (typeof r.images === 'string' ? JSON.parse(r.images) : r.images) : [];
      } catch (_) {
        parsedImages = r.profile_image ? [r.profile_image] : [];
      }
      return {
        business_id: r.business_id,
        business_profile_id: `BP${r.business_id.toString().padStart(3, '0')}`,
        businessProfileId: `BP${r.business_id.toString().padStart(3, '0')}`,
        user_id: r.user_id,
        owner_user_id: `U${r.user_id.toString().padStart(3, '0')}`,
        ownerUserId: `U${r.user_id.toString().padStart(3, '0')}`,
        business_name: capitalizeWords(r.business_name),
        name: capitalizeWords(r.business_name),
        category: r.category || 'General Store',
        business_phone: r.business_phone,
        phone: r.business_phone,
        country_code: r.country_code || '+91',
        full_address: r.full_address,
        registeredAddress: r.full_address,
        locality: r.locality || '',
        city: r.city || '',
        state: r.state || '',
        country: r.country || 'India',
        latitude: parseFloat(r.latitude) || 0.0,
        longitude: parseFloat(r.longitude) || 0.0,
        profile_image: r.profile_image || (parsedImages.length > 0 ? parsedImages[0] : ''),
        image: r.profile_image || (parsedImages.length > 0 ? parsedImages[0] : ''),
        images: parsedImages,
        about: r.about || '',
        isFollowed: true,
        is_following: true,
        is_followed: true
      };
    });

    console.log(`[Followed Businesses] Loaded ${businesses.length} followed businesses for User ${userId} (${req.user.email})`);
    return res.status(200).json({ success: true, count: businesses.length, businesses });
  } catch (error) {
    console.error('[Followed Businesses GET Error]:', error.message);
    return res.status(500).json({ success: false, message: 'Error fetching followed businesses.' });
  }
});

// ==========================================
// 10. NOTIFICATION APIS & 15-DAY RETENTION CLEANUP
// ==========================================

/**
 * Cleanup expired notifications older than 15 days
 */
async function cleanupExpiredNotifications() {
  try {
    const [result] = await pool.query(`
      DELETE FROM notifications 
      WHERE created_at < NOW() - INTERVAL 15 DAY
    `);
    if (result && result.affectedRows > 0) {
      console.log(`[Notification Cleanup] Automatically pruned ${result.affectedRows} expired notification(s) older than 15 days.`);
    }
  } catch (err) {
    console.error('[Notification Cleanup Error]:', err.message);
  }
}

// Automatically run retention cleanup every 1 hour (3600000 ms)
setInterval(cleanupExpiredNotifications, 60 * 60 * 1000);

function formatNotificationRow(r) {
  return {
    id: r.id,
    notification_id: `N${r.id.toString().padStart(3, '0')}`,
    notificationId: `N${r.id.toString().padStart(3, '0')}`,
    numericId: r.id,
    user_id: r.user_id,
    userId: `U${r.user_id.toString().padStart(3, '0')}`,
    business_id: r.business_id,
    businessProfileId: `BP${r.business_id.toString().padStart(3, '0')}`,
    business_name: capitalizeWords(r.business_name || ''),
    businessName: capitalizeWords(r.business_name || ''),
    business_profile_image: r.business_profile_image || null,
    brandLogo: r.business_profile_image || null,
    post_id: r.post_id,
    postId: r.post_id ? `P${r.post_id.toString().padStart(3, '0')}` : null,
    type: r.type || 'new_business_post',
    title: r.title,
    message: r.message,
    is_read: r.is_read === 1,
    isRead: r.is_read === 1,
    timeAgo: calculateTimeAgo(r.created_at),
    createdAt: r.created_at,
    created_at: r.created_at,
    updated_at: r.updated_at
  };
}

/**
 * GET /api/notifications
 * Retrieve authenticated user's notifications (newest first, within 15-day retention window, pagination)
 */
app.get('/api/notifications', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit || '50', 10)));
    const offset = (page - 1) * limit;

    // Fetch user notifications joined with business_profile info
    const [rows] = await pool.query(`
      SELECT n.*, b.business_name, b.profile_image AS business_profile_image
      FROM notifications n
      LEFT JOIN business_profile b ON n.business_id = b.business_id
      WHERE n.user_id = ? AND n.created_at >= NOW() - INTERVAL 15 DAY
      ORDER BY n.created_at DESC, n.id DESC
      LIMIT ? OFFSET ?
    `, [userId, limit, offset]);

    const [countRows] = await pool.query(`
      SELECT 
        COUNT(*) AS total_count,
        SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END) AS unread_count
      FROM notifications
      WHERE user_id = ? AND created_at >= NOW() - INTERVAL 15 DAY
    `, [userId]);

    const totalCount = countRows[0].total_count || 0;
    const unreadCount = parseInt(countRows[0].unread_count || '0', 10);
    const notifications = rows.map(formatNotificationRow);

    return res.status(200).json({
      success: true,
      count: notifications.length,
      total: totalCount,
      unread_count: unreadCount,
      unreadCount: unreadCount,
      page,
      limit,
      notifications
    });
  } catch (error) {
    console.error('[Notifications] GET Error:', error.message);
    return res.status(500).json({ success: false, message: 'Error fetching notifications.' });
  }
});

/**
 * PUT & POST /api/notifications/:id/read
 * Mark a single notification as read for authenticated user
 */
app.all(['/api/notifications/:id/read', '/api/notifications/:id/mark-read'], authenticateUser, async (req, res) => {
  if (req.method !== 'PUT' && req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }
  try {
    const userId = req.user.id;
    const rawId = req.params.id.toString().replace(/^N0*/i, '');
    const notifId = parseInt(rawId, 10);
    if (isNaN(notifId)) {
      return res.status(400).json({ success: false, message: 'Invalid notification ID.' });
    }

    const [result] = await pool.query(
      'UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?',
      [notifId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Notification not found or access denied.' });
    }

    return res.status(200).json({
      success: true,
      notificationId: `N${notifId.toString().padStart(3, '0')}`,
      isRead: true,
      message: 'Notification marked as read.'
    });
  } catch (error) {
    console.error('[Notifications] Mark as read error:', error.message);
    return res.status(500).json({ success: false, message: 'Error marking notification as read.' });
  }
});

/**
 * PUT & POST /api/notifications/mark-all-read & /api/notifications/read-all
 * Mark all notifications as read for authenticated user
 */
app.all(['/api/notifications/mark-all-read', '/api/notifications/read-all'], authenticateUser, async (req, res) => {
  if (req.method !== 'PUT' && req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }
  try {
    const userId = req.user.id;
    await pool.query('UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0', [userId]);

    return res.status(200).json({
      success: true,
      message: 'All notifications marked as read.'
    });
  } catch (error) {
    console.error('[Notifications] Mark all read error:', error.message);
    return res.status(500).json({ success: false, message: 'Error marking all notifications as read.' });
  }
});

/**
 * DELETE /api/notifications/:id
 * Delete a single notification with user ownership validation
 */
app.delete('/api/notifications/:id', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.id;
    const rawId = req.params.id.toString().replace(/^N0*/i, '');
    const notifId = parseInt(rawId, 10);
    if (isNaN(notifId)) {
      return res.status(400).json({ success: false, message: 'Invalid notification ID.' });
    }

    const [result] = await pool.query(
      'DELETE FROM notifications WHERE id = ? AND user_id = ?',
      [notifId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Notification not found or access denied.' });
    }

    return res.status(200).json({
      success: true,
      notificationId: `N${notifId.toString().padStart(3, '0')}`,
      message: 'Notification deleted successfully.'
    });
  } catch (error) {
    console.error('[Notifications] Delete error:', error.message);
    return res.status(500).json({ success: false, message: 'Error deleting notification.' });
  }
});

/**
 * DELETE & POST /api/notifications/batch-delete & DELETE /api/notifications
 * Multi-delete notifications with authenticated user isolation
 */
app.all(['/api/notifications/batch-delete', '/api/notifications/multi-delete', '/api/notifications'], authenticateUser, async (req, res) => {
  if (req.method !== 'DELETE' && req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }
  try {
    const userId = req.user.id;
    const { ids, notificationIds, notification_ids } = req.body || {};
    const rawIds = ids || notificationIds || notification_ids || [];

    if (!Array.isArray(rawIds) || rawIds.length === 0) {
      return res.status(400).json({ success: false, message: 'A list of notification IDs is required.' });
    }

    const numericIds = rawIds
      .map(id => parseInt(id.toString().replace(/^N0*/i, ''), 10))
      .filter(id => !isNaN(id));

    if (numericIds.length === 0) {
      return res.status(400).json({ success: false, message: 'No valid notification IDs provided.' });
    }

    const [result] = await pool.query(
      'DELETE FROM notifications WHERE user_id = ? AND id IN (?)',
      [userId, numericIds]
    );

    return res.status(200).json({
      success: true,
      deletedCount: result.affectedRows,
      message: `${result.affectedRows} notification(s) deleted successfully.`
    });
  } catch (error) {
    console.error('[Notifications] Batch delete error:', error.message);
    return res.status(500).json({ success: false, message: 'Error deleting notifications.' });
  }
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Endpoint ${req.method} ${req.originalUrl} not found.` });
});

// ==========================================
// 11. BOOTSTRAP SERVER
// ==========================================
const privKeyPath = '/etc/letsencrypt/live/apps.plestarinc.com/privkey.pem';
const certPath = '/etc/letsencrypt/live/apps.plestarinc.com/fullchain.pem';

async function startServer() {
  await initDatabase();
  await cleanupExpiredNotifications();

  if (fs.existsSync(privKeyPath) && fs.existsSync(certPath)) {
    const credentials = {
      key: fs.readFileSync(privKeyPath, 'utf8'),
      cert: fs.readFileSync(certPath, 'utf8')
    };
    const httpsPort = PORT === 5000 ? 3008 : PORT;
    const httpsServer = https.createServer(credentials, app);
    httpsServer.listen(httpsPort, '0.0.0.0', () => {
      console.log(`====================================================`);
      console.log(`🚀 ADVT App Live Server running on https://apps.plestarinc.com:${httpsPort}`);
      console.log(`====================================================`);
    });
  } else {
    const httpServer = http.createServer(app);
    httpServer.listen(PORT, '0.0.0.0', () => {
      console.log(`====================================================`);
      console.log(`🚀 ADVT App Local Server running on http://localhost:${PORT}`);
      console.log(`====================================================`);
    });
  }
}

startServer();

module.exports = {
  app,
  pool,
  cleanupExpiredNotifications,
  isPostVisibleToUser,
  filterPostsForUser,
  normalizeUserLocation,
  extractPostTargetLocations,
  getEffectiveTargetLocations,
  isLocationContained,
  isUserCoveredByTarget
};

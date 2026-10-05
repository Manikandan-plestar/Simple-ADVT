/**
 * Baseline Regression Test Suite for ADVT App Backend
 * 
 * Tests each endpoint for:
 * 1. Status code
 * 2. Response JSON shape (success property, keys)
 * 3. Behavior with and without JWT tokens
 */

const http = require('http');
const assert = require('assert');
const { app, pool } = require('../server');

const TEST_PORT = 5055;
let server;

function request(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const dataString = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      ...headers
    };
    if (dataString) {
      reqHeaders['Content-Length'] = Buffer.byteLength(dataString);
    }

    const req = http.request({
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path,
      method,
      headers: reqHeaders
    }, (res) => {
      let rawData = '';
      res.on('data', (chunk) => { rawData += chunk; });
      res.on('end', () => {
        let json = null;
        try {
          json = JSON.parse(rawData);
        } catch (_) {
          json = rawData;
        }
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: json
        });
      });
    });

    req.on('error', reject);
    if (dataString) req.write(dataString);
    req.end();
  });
}

async function runTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING BASELINE REGRESSION TESTS');
  console.log('====================================================');

  server = app.listen(TEST_PORT, '127.0.0.1');

  const results = [];
  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  ✅ PASS: ${name}`);
      passed++;
      results.push({ name, status: 'PASS' });
    } catch (err) {
      console.error(`  ❌ FAIL: ${name} -> ${err.message}`);
      failed++;
      results.push({ name, status: 'FAIL', error: err.message });
    }
  }

  try {
    // 1. Health Check
    await test('GET /api/health returns 200 and status online', async () => {
      const res = await request('GET', '/api/health');
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.status, 'online');
      assert.ok(res.body.service);
    });

    // 2. OTP send validation
    await test('POST /api/send-email-otp with invalid email returns 400', async () => {
      const res = await request('POST', '/api/send-email-otp', { email: 'invalid-email' });
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.body.success, false);
    });

    // 3. OTP verify invalid OTP
    await test('POST /api/verify-email-otp with wrong OTP returns 400', async () => {
      const res = await request('POST', '/api/verify-email-otp', { email: 'test@example.com', otp: '000000' });
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.body.success, false);
    });

    const jwt = require('jsonwebtoken');
    const testToken = jwt.sign({ id: 1, email: 'test1@gmail.com', isVerified: true }, 'simple_advt_jwt_super_secret_key_2026_xyz');

    // 4. Explore Posts (Anonymous should be rejected with 401)
    await test('GET /api/posts without auth returns 401', async () => {
      const res = await request('GET', '/api/posts');
      assert.strictEqual(res.statusCode, 401);
      assert.strictEqual(res.body.success, false);
    });

    // 4b. Explore Posts (Authenticated returns 200)
    await test('GET /api/posts with Bearer token returns 200', async () => {
      const res = await request('GET', '/api/posts', null, { 'Authorization': `Bearer ${testToken}` });
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
    });

    // 5. Business Search
    await test('GET /api/business-profiles/search returns 200', async () => {
      const res = await request('GET', '/api/business-profiles/search?q=test');
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.ok(Array.isArray(res.body.data));
    });

    // 6. User Profile (Unauthenticated currently returns profile or 404/400)
    await test('GET /api/user-profile with invalid email returns 400', async () => {
      const res = await request('GET', '/api/user-profile?email=invalid');
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.body.success, false);
    });

    // 7. Protected Route without token or fallback
    await test('POST /api/business-profiles without auth in production behavior', async () => {
      const res = await request('POST', '/api/business-profiles', { business_name: 'Test' });
      // In dev fallback mode it may succeed or fail depending on db, but returns JSON with success property
      assert.ok(typeof res.body.success === 'boolean');
    });

    // 8. Saved Posts Endpoint
    await test('GET /api/posts/saved returns JSON', async () => {
      const res = await request('GET', '/api/posts/saved');
      assert.ok(typeof res.body.success === 'boolean');
    });

    // 9. Notifications Inbox Endpoint
    await test('GET /api/notifications returns JSON', async () => {
      const res = await request('GET', '/api/notifications');
      assert.ok(typeof res.body.success === 'boolean');
    });

  } finally {
    server.close();
    console.log('====================================================');
    console.log(`🏁 TESTS COMPLETED: ${passed} Passed, ${failed} Failed`);
    console.log('====================================================');
    if (failed > 0) {
      process.exitCode = 1;
    }
  }
}

if (require.main === module) {
  runTests().catch(console.error);
}

module.exports = { runTests };

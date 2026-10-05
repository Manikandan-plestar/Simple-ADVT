-- ========================================================
-- Migration: 001_initial_hardening.sql
-- Purpose: Additive database hardening for payment idempotency and post performance
-- Safe for execution on production (zero table drops, zero data loss)
-- ========================================================

-- 1. Ensure composite indexing on posts for location-based explore queries
CREATE INDEX IF NOT EXISTS idx_posts_status_expires ON posts (status, expires_at);
CREATE INDEX IF NOT EXISTS idx_posts_business_status ON posts (business_id, status);

-- 2. Ensure unique transaction_id index on payment_transactions for replay attack prevention
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_tx_platform_unique ON payment_transactions (platform, transaction_id);

-- 3. Ensure indexing on notifications for user inbox performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications (user_id, is_read, created_at);

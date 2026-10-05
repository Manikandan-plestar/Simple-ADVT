-- ========================================================
-- Rollback Migration: 001_initial_hardening_rollback.sql
-- Purpose: Safely removes added indexes if rollback is needed
-- ========================================================

DROP INDEX IF EXISTS idx_posts_status_expires ON posts;
DROP INDEX IF EXISTS idx_posts_business_status ON posts;
DROP INDEX IF EXISTS idx_payment_tx_platform_unique ON payment_transactions;
DROP INDEX IF EXISTS idx_notifications_user_unread ON notifications;

-- Clean up incomplete database state
DROP TABLE IF EXISTS transaction_logs CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS merchants CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;

DROP VIEW IF EXISTS merchant_transaction_summary CASCADE;
DROP VIEW IF EXISTS customer_transaction_history CASCADE;

DROP FUNCTION IF EXISTS create_test_transaction CASCADE;

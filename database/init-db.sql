-- ============================================================================
-- SAIF-PostgreSQL: Payment Gateway Database Initialization
-- ============================================================================
-- This script creates a realistic payment gateway schema with intentional
-- security vulnerabilities for educational purposes.
--
-- Schema Design: Payment Processing Gateway
-- - Customers: End users making payments
-- - Merchants: Businesses receiving payments
-- - Payment Methods: Stored payment instruments
-- - Transactions: Payment processing records
-- - Orders: E-commerce orders linked to transactions
-- ============================================================================

-- Enable UUID extension for transaction IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CUSTOMERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(3) DEFAULT 'USA',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended'))
);

CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_status ON customers(status);

COMMENT ON TABLE customers IS 'Customer accounts for payment gateway';
COMMENT ON COLUMN customers.customer_id IS 'Unique customer identifier';
COMMENT ON COLUMN customers.email IS 'Customer email address (unique, used for login)';

-- ============================================================================
-- MERCHANTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS merchants (
    merchant_id SERIAL PRIMARY KEY,
    merchant_name VARCHAR(255) NOT NULL,
    merchant_code VARCHAR(50) UNIQUE NOT NULL,
    business_type VARCHAR(100),
    api_key VARCHAR(255),  -- Intentionally stored in plaintext for demo
    webhook_url VARCHAR(500),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'pending')),
    fee_percentage DECIMAL(5, 3) DEFAULT 2.9,  -- Transaction fee (e.g., 2.9%)
    fee_fixed DECIMAL(10, 2) DEFAULT 0.30,     -- Fixed fee per transaction
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_merchants_code ON merchants(merchant_code);
CREATE INDEX idx_merchants_status ON merchants(status);

COMMENT ON TABLE merchants IS 'Merchant/vendor accounts receiving payments';
COMMENT ON COLUMN merchants.api_key IS 'API key for merchant integration (INSECURE: plaintext storage)';
COMMENT ON COLUMN merchants.fee_percentage IS 'Percentage fee charged per transaction';

-- ============================================================================
-- PAYMENT METHODS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS payment_methods (
    payment_method_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    method_type VARCHAR(50) NOT NULL CHECK (method_type IN ('credit_card', 'debit_card', 'bank_account', 'digital_wallet')),
    
    -- Card information (intentionally stored with minimal security for demo)
    card_last_four VARCHAR(4),
    card_brand VARCHAR(50) CHECK (card_brand IN ('Visa', 'Mastercard', 'American Express', 'Discover', 'JCB')),
    card_holder_name VARCHAR(255),
    expiry_month INTEGER CHECK (expiry_month BETWEEN 1 AND 12),
    expiry_year INTEGER CHECK (expiry_year >= 2024),
    
    -- Bank account information
    bank_name VARCHAR(255),
    account_last_four VARCHAR(4),
    routing_number_hint VARCHAR(4),
    
    -- Digital wallet information
    wallet_provider VARCHAR(50),
    wallet_identifier VARCHAR(255),
    
    is_default BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'invalid', 'removed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payment_methods_customer ON payment_methods(customer_id);
CREATE INDEX idx_payment_methods_type ON payment_methods(method_type);

COMMENT ON TABLE payment_methods IS 'Customer payment methods (cards, bank accounts, wallets)';
COMMENT ON COLUMN payment_methods.card_last_four IS 'Last 4 digits of card number (for display only)';

-- ============================================================================
-- TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id INTEGER REFERENCES customers(customer_id),
    merchant_id INTEGER NOT NULL REFERENCES merchants(merchant_id),
    payment_method_id INTEGER REFERENCES payment_methods(payment_method_id),
    
    -- Transaction amounts
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'USD',
    merchant_fee DECIMAL(10, 2),
    net_amount DECIMAL(10, 2),
    
    -- Transaction status and flow
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'authorized', 'captured', 'completed', 'failed', 'refunded', 'disputed')),
    failure_reason TEXT,
    
    -- Metadata
    description TEXT,
    customer_ip VARCHAR(45),
    user_agent TEXT,
    
    -- Timestamps for transaction lifecycle
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    authorized_at TIMESTAMP,
    captured_at TIMESTAMP,
    completed_at TIMESTAMP,
    refunded_at TIMESTAMP,
    
    -- Fraud detection flags (simplified for demo)
    risk_score INTEGER CHECK (risk_score BETWEEN 0 AND 100),
    is_flagged BOOLEAN DEFAULT FALSE,
    fraud_notes TEXT
);

CREATE INDEX idx_transactions_customer ON transactions(customer_id);
CREATE INDEX idx_transactions_merchant ON transactions(merchant_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC);
CREATE INDEX idx_transactions_amount ON transactions(amount);

COMMENT ON TABLE transactions IS 'Payment transaction records with full audit trail';
COMMENT ON COLUMN transactions.transaction_id IS 'UUID for globally unique transaction identification';
COMMENT ON COLUMN transactions.risk_score IS 'Fraud risk score (0-100, higher = more risky)';

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    merchant_id INTEGER NOT NULL REFERENCES merchants(merchant_id),
    transaction_id UUID REFERENCES transactions(transaction_id),
    
    -- Order details
    order_number VARCHAR(50) UNIQUE NOT NULL,
    order_total DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) DEFAULT 0.00,
    shipping_amount DECIMAL(10, 2) DEFAULT 0.00,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    
    -- Order status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
    
    -- Shipping information
    shipping_address_line1 VARCHAR(255),
    shipping_address_line2 VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(100),
    shipping_postal_code VARCHAR(20),
    shipping_country VARCHAR(3) DEFAULT 'USA',
    tracking_number VARCHAR(100),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_merchant ON orders(merchant_id);
CREATE INDEX idx_orders_transaction ON orders(transaction_id);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_orders_status ON orders(status);

COMMENT ON TABLE orders IS 'E-commerce orders linked to payment transactions';

-- ============================================================================
-- ORDER ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_sku VARCHAR(100),
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_sku ON order_items(product_sku);

COMMENT ON TABLE order_items IS 'Individual items within orders';

-- ============================================================================
-- TRANSACTION LOGS TABLE (Audit Trail)
-- ============================================================================
CREATE TABLE IF NOT EXISTS transaction_logs (
    log_id SERIAL PRIMARY KEY,
    transaction_id UUID NOT NULL REFERENCES transactions(transaction_id),
    log_type VARCHAR(50) NOT NULL,
    log_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transaction_logs_txn ON transaction_logs(transaction_id);
CREATE INDEX idx_transaction_logs_date ON transaction_logs(created_at DESC);

COMMENT ON TABLE transaction_logs IS 'Audit trail for transaction state changes';

-- ============================================================================
-- DEMO DATA INSERTION
-- ============================================================================

-- Insert demo customers
INSERT INTO customers (email, first_name, last_name, phone, city, state, country) VALUES
('john.doe@example.com', 'John', 'Doe', '+1-555-0101', 'Seattle', 'WA', 'USA'),
('jane.smith@example.com', 'Jane', 'Smith', '+1-555-0102', 'New York', 'NY', 'USA'),
('bob.johnson@example.com', 'Bob', 'Johnson', '+1-555-0103', 'San Francisco', 'CA', 'USA'),
('alice.williams@example.com', 'Alice', 'Williams', '+1-555-0104', 'Chicago', 'IL', 'USA'),
('charlie.brown@example.com', 'Charlie', 'Brown', '+1-555-0105', 'Austin', 'TX', 'USA')
ON CONFLICT (email) DO NOTHING;

-- Insert demo merchants
INSERT INTO merchants (merchant_name, merchant_code, business_type, api_key, contact_email, fee_percentage, fee_fixed) VALUES
('TechStore Inc', 'TECHSTORE001', 'Electronics', 'sk_test_4eC39HqLyjWDarjtT1zdp7dc', 'payments@techstore.com', 2.9, 0.30),
('Fashion Boutique', 'FASHIONBQ001', 'Retail', 'sk_test_BQokikJOvBiI2HlWgH4olfQ2', 'billing@fashionboutique.com', 2.5, 0.25),
('Global Marketplace', 'GLOBALMP001', 'Marketplace', 'sk_test_51HqLyjWDarjtT1zdp7dcRJB', 'finance@globalmp.com', 3.5, 0.50),
('Food Delivery Co', 'FOODDEL001', 'Food Services', 'sk_test_26PHem2AJTtqHYJznQZrBTBF', 'accounts@fooddelivery.com', 4.0, 0.40),
('Online Courses Ltd', 'ONLINECRS001', 'Education', 'sk_test_51JOvBiI2HlWgH4olfQ2KMJT', 'payments@onlinecourses.com', 2.0, 0.20)
ON CONFLICT (merchant_code) DO NOTHING;

-- Insert demo payment methods
INSERT INTO payment_methods (customer_id, method_type, card_last_four, card_brand, card_holder_name, expiry_month, expiry_year) VALUES
(1, 'credit_card', '4242', 'Visa', 'John Doe', 12, 2028),
(2, 'credit_card', '5555', 'Mastercard', 'Jane Smith', 06, 2027),
(3, 'debit_card', '4000', 'Visa', 'Bob Johnson', 03, 2026),
(4, 'credit_card', '3782', 'American Express', 'Alice Williams', 09, 2029),
(5, 'digital_wallet', NULL, NULL, NULL, NULL, NULL);

-- Update the digital wallet entry
UPDATE payment_methods 
SET wallet_provider = 'PayPal', wallet_identifier = 'charlie.brown@example.com'
WHERE customer_id = 5 AND method_type = 'digital_wallet';

-- Insert demo transactions (various statuses)
INSERT INTO transactions (customer_id, merchant_id, payment_method_id, amount, currency, status, merchant_fee, net_amount, description, customer_ip, risk_score) VALUES
(1, 1, 1, 299.99, 'USD', 'completed', 8.70, 291.29, 'Laptop purchase', '192.168.1.100', 15),
(2, 2, 2, 149.50, 'USD', 'completed', 4.34, 145.16, 'Designer handbag', '192.168.1.101', 10),
(3, 3, 3, 89.99, 'USD', 'completed', 2.61, 87.38, 'Office supplies bundle', '192.168.1.102', 8),
(4, 4, 4, 45.00, 'USD', 'processing', 1.31, 43.69, 'Food delivery order', '192.168.1.103', 12),
(5, 5, 5, 199.00, 'USD', 'completed', 3.98, 195.02, 'Online course subscription', '192.168.1.104', 5),
(1, 1, 1, 599.99, 'USD', 'failed', NULL, NULL, 'Monitor purchase - declined', '192.168.1.100', 75),
(2, 3, 2, 1299.00, 'USD', 'refunded', 37.67, 1261.33, 'Smartphone - returned', '192.168.1.101', 20);

-- Update timestamps for completed transactions
UPDATE transactions 
SET authorized_at = transaction_date + INTERVAL '5 seconds',
    captured_at = transaction_date + INTERVAL '30 seconds',
    completed_at = transaction_date + INTERVAL '1 minute'
WHERE status = 'completed';

-- Insert demo orders
INSERT INTO orders (customer_id, merchant_id, transaction_id, order_number, order_total, tax_amount, shipping_amount, status, shipping_city, shipping_state) VALUES
(1, 1, (SELECT transaction_id FROM transactions WHERE customer_id = 1 AND merchant_id = 1 AND status = 'completed' LIMIT 1), 'ORD-2025-001', 299.99, 24.00, 0.00, 'delivered', 'Seattle', 'WA'),
(2, 2, (SELECT transaction_id FROM transactions WHERE customer_id = 2 AND merchant_id = 2 LIMIT 1), 'ORD-2025-002', 149.50, 11.96, 9.99, 'delivered', 'New York', 'NY'),
(3, 3, (SELECT transaction_id FROM transactions WHERE customer_id = 3 AND merchant_id = 3 LIMIT 1), 'ORD-2025-003', 89.99, 7.20, 5.00, 'shipped', 'San Francisco', 'CA');

-- Insert order items
INSERT INTO order_items (order_id, product_sku, product_name, quantity, unit_price, total_price) VALUES
((SELECT order_id FROM orders WHERE order_number = 'ORD-2025-001'), 'LAPTOP-X1', 'High-Performance Laptop', 1, 299.99, 299.99),
((SELECT order_id FROM orders WHERE order_number = 'ORD-2025-002'), 'BAG-LUX-01', 'Designer Leather Handbag', 1, 149.50, 149.50),
((SELECT order_id FROM orders WHERE order_number = 'ORD-2025-003'), 'OFFICE-BUNDLE-5', 'Office Supplies Bundle', 1, 89.99, 89.99);

-- ============================================================================
-- VIEWS FOR ANALYTICS
-- ============================================================================

-- Transaction summary by merchant
CREATE OR REPLACE VIEW merchant_transaction_summary AS
SELECT 
    m.merchant_id,
    m.merchant_name,
    m.merchant_code,
    COUNT(t.transaction_id) AS total_transactions,
    COUNT(CASE WHEN t.status = 'completed' THEN 1 END) AS completed_transactions,
    COUNT(CASE WHEN t.status = 'failed' THEN 1 END) AS failed_transactions,
    SUM(CASE WHEN t.status = 'completed' THEN t.amount ELSE 0 END) AS total_revenue,
    SUM(CASE WHEN t.status = 'completed' THEN t.merchant_fee ELSE 0 END) AS total_fees,
    AVG(CASE WHEN t.status = 'completed' THEN t.amount END) AS avg_transaction_amount
FROM merchants m
LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.merchant_code;

-- Customer transaction history
CREATE OR REPLACE VIEW customer_transaction_history AS
SELECT 
    c.customer_id,
    c.email,
    c.first_name,
    c.last_name,
    t.transaction_id,
    t.amount,
    t.currency,
    t.status,
    t.transaction_date,
    m.merchant_name
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
LEFT JOIN merchants m ON t.merchant_id = m.merchant_id
ORDER BY t.transaction_date DESC;

-- ============================================================================
-- FUNCTIONS FOR TESTING
-- ============================================================================

-- Function to simulate payment transaction (for load testing)
-- ============================================================================
-- LOAD TESTING FUNCTIONS
-- ============================================================================

-- Function with parameters (for targeted testing)
CREATE OR REPLACE FUNCTION create_test_transaction(
    p_customer_id INTEGER,
    p_merchant_id INTEGER,
    p_amount DECIMAL(10, 2)
) RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
    v_merchant_fee DECIMAL(10, 2);
    v_net_amount DECIMAL(10, 2);
BEGIN
    -- Calculate fees
    SELECT (fee_percentage / 100) * p_amount + fee_fixed
    INTO v_merchant_fee
    FROM merchants
    WHERE merchant_id = p_merchant_id;
    
    v_net_amount := p_amount - v_merchant_fee;
    
    -- Insert transaction
    INSERT INTO transactions (
        customer_id,
        merchant_id,
        amount,
        merchant_fee,
        net_amount,
        status,
        risk_score
    ) VALUES (
        p_customer_id,
        p_merchant_id,
        p_amount,
        v_merchant_fee,
        v_net_amount,
        'completed',
        FLOOR(RANDOM() * 50)
    ) RETURNING transaction_id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- Parameterless function (for simple load testing)
CREATE OR REPLACE FUNCTION create_test_transaction()
RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
    v_customer_id INTEGER;
    v_merchant_id INTEGER;
    v_amount DECIMAL(10, 2);
    v_merchant_fee DECIMAL(10, 2);
    v_net_amount DECIMAL(10, 2);
BEGIN
    -- Select random active customer
    SELECT customer_id INTO v_customer_id
    FROM customers
    WHERE status = 'active'
    ORDER BY RANDOM()
    LIMIT 1;
    
    -- Select random active merchant
    SELECT merchant_id INTO v_merchant_id
    FROM merchants
    WHERE status = 'active'
    ORDER BY RANDOM()
    LIMIT 1;
    
    -- Generate random amount between $5 and $500
    v_amount := (RANDOM() * 495 + 5)::DECIMAL(10, 2);
    
    -- Calculate fees
    SELECT (fee_percentage / 100) * v_amount + fee_fixed
    INTO v_merchant_fee
    FROM merchants
    WHERE merchant_id = v_merchant_id;
    
    v_net_amount := v_amount - v_merchant_fee;
    
    -- Insert transaction
    INSERT INTO transactions (
        customer_id,
        merchant_id,
        amount,
        merchant_fee,
        net_amount,
        status,
        risk_score
    ) VALUES (
        v_customer_id,
        v_merchant_id,
        v_amount,
        v_merchant_fee,
        v_net_amount,
        'completed',
        FLOOR(RANDOM() * 50)
    ) RETURNING transaction_id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_test_transaction(INTEGER, INTEGER, DECIMAL) IS 'Creates a test transaction with specified parameters for load testing';
COMMENT ON FUNCTION create_test_transaction() IS 'Creates a test transaction with random parameters for load testing';

-- ============================================================================
-- PERMISSIONS (For demo - overly permissive)
-- ============================================================================

-- Grant all permissions to the application user (intentionally insecure for demo)
-- Note: In production, use principle of least privilege

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SAIF-PostgreSQL Database Initialized';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Tables created: 8';
    RAISE NOTICE 'Views created: 2';
    RAISE NOTICE 'Functions created: 2 (load testing)';
    RAISE NOTICE 'Demo customers: 5';
    RAISE NOTICE 'Demo merchants: 5';
    RAISE NOTICE 'Demo transactions: 7';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Load Testing:';
    RAISE NOTICE '  SELECT create_test_transaction();';
    RAISE NOTICE '  (Creates transaction with random data)';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'WARNING: This database contains';
    RAISE NOTICE 'intentional security vulnerabilities';
    RAISE NOTICE 'for educational purposes only.';
    RAISE NOTICE '========================================';
END $$;

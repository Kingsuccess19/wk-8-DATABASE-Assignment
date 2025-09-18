/*
  ecommerce_schema.sql
  Complete relational schema for an E-commerce Store (MySQL/InnoDB).
  - Use case includes Customers, Products, Categories, Suppliers, Orders, Payments, Addresses, Reviews.
  - Relationships: One-to-One, One-to-Many, Many-to-Many where appropriate.
  - Constraints: PRIMARY KEY, FOREIGN KEY, NOT NULL, UNIQUE, CHECKs, indexes.
  - Created for MySQL 8+ (InnoDB).
*/

-- Drop DB if exists (uncomment if you want to reset)
-- DROP DATABASE IF EXISTS ecommerce_store;
CREATE DATABASE IF NOT EXISTS ecommerce_store
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
USE ecommerce_store;

-- ----------------------------------------------------------------
-- Enable strict mode (recommended). If running from client, ensure session SQL_MODE includes STRICT_TRANS_TABLES
-- SET sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';

-- ----------------------------------------------------------------
-- Table: users (authentication / account info)
-- one account may be a customer; administrators can use same table.
-- ----------------------------------------------------------------
CREATE TABLE users (
  user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  role ENUM('customer','admin','seller') NOT NULL DEFAULT 'customer',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: customers (one-to-one with users)
-- Demonstrates one-to-one: customers.user_id unique FK to users.user_id
-- ----------------------------------------------------------------
CREATE TABLE customers (
  customer_id BIGINT UNSIGNED PRIMARY KEY, -- we'll store same value as user_id (one-to-one)
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  date_of_birth DATE,
  loyalty_points INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_customers_users FOREIGN KEY (customer_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: categories (product classification) - hierarchical (self-referencing)
-- ----------------------------------------------------------------
CREATE TABLE categories (
  category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL UNIQUE,
  slug VARCHAR(200) NOT NULL UNIQUE,
  parent_id INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories(category_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: suppliers
-- ----------------------------------------------------------------
CREATE TABLE suppliers (
  supplier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  contact_email VARCHAR(255),
  phone VARCHAR(30),
  address TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: products
-- ----------------------------------------------------------------
CREATE TABLE products (
  product_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(12,2) NOT NULL CHECK (price >= 0),
  weight_kg DECIMAL(8,3) DEFAULT NULL CHECK (weight_kg >= 0),
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: product_categories (many-to-many)
-- Many products can belong to many categories
-- ----------------------------------------------------------------
CREATE TABLE product_categories (
  product_id BIGINT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (product_id, category_id),
  CONSTRAINT fk_pc_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
  CONSTRAINT fk_pc_category FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: product_suppliers (many-to-many)
-- Products may have multiple suppliers; suppliers supply multiple products
-- ----------------------------------------------------------------
CREATE TABLE product_suppliers (
  product_id BIGINT UNSIGNED NOT NULL,
  supplier_id INT UNSIGNED NOT NULL,
  supplier_sku VARCHAR(128),
  cost_price DECIMAL(12,2) CHECK (cost_price >= 0),
  PRIMARY KEY (product_id, supplier_id),
  CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
  CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: product_inventory (one-to-one-ish per product variant)
-- For simplicity using product-level inventory (can be extended for variants)
-- ----------------------------------------------------------------
CREATE TABLE product_inventory (
  product_id BIGINT UNSIGNED PRIMARY KEY,
  quantity INT UNSIGNED NOT NULL DEFAULT 0,
  re_order_level INT UNSIGNED NOT NULL DEFAULT 10,
  is_backorder_allowed TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: product_images
-- ----------------------------------------------------------------
CREATE TABLE product_images (
  image_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  url VARCHAR(1024) NOT NULL,
  alt_text VARCHAR(255),
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_images_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_product_images_product ON product_images (product_id);

-- ----------------------------------------------------------------
-- Table: addresses (customers can have many addresses)
-- ----------------------------------------------------------------
CREATE TABLE addresses (
  address_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id BIGINT UNSIGNED NOT NULL,
  label VARCHAR(50) DEFAULT 'Home', -- e.g., Home, Work
  street VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100),
  postal_code VARCHAR(30),
  country VARCHAR(100) NOT NULL,
  is_default_shipping TINYINT(1) NOT NULL DEFAULT 0,
  is_default_billing TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_addresses_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_addresses_customer ON addresses (customer_id);

-- ----------------------------------------------------------------
-- Table: orders
-- One-to-Many: customer -> orders
-- ----------------------------------------------------------------
CREATE TABLE orders (
  order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id BIGINT UNSIGNED NOT NULL,
  order_number VARCHAR(64) NOT NULL UNIQUE,
  order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status ENUM('pending','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending',
  shipping_address_id BIGINT UNSIGNED,
  billing_address_id BIGINT UNSIGNED,
  subtotal DECIMAL(12,2) NOT NULL CHECK (subtotal >= 0),
  shipping DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (shipping >= 0),
  tax DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
  total DECIMAL(12,2) NOT NULL CHECK (total >= 0),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
  CONSTRAINT fk_orders_ship_addr FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL,
  CONSTRAINT fk_orders_bill_addr FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_order_date ON orders (order_date);

-- ----------------------------------------------------------------
-- Table: order_items (many-to-many between orders and products with extra fields)
-- ----------------------------------------------------------------
CREATE TABLE order_items (
  order_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  sku_snapshot VARCHAR(64) NOT NULL,
  name_snapshot VARCHAR(255) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
  quantity INT UNSIGNED NOT NULL CHECK (quantity > 0),
  line_total DECIMAL(12,2) NOT NULL CHECK (line_total >= 0),
  CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
  CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);

-- ----------------------------------------------------------------
-- Table: payments
-- ----------------------------------------------------------------
CREATE TABLE payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  payment_method ENUM('card','paypal','bank_transfer','wallet') NOT NULL DEFAULT 'card',
  payment_status ENUM('pending','completed','failed','refunded') NOT NULL DEFAULT 'pending',
  paid_amount DECIMAL(12,2) NOT NULL CHECK (paid_amount >= 0),
  transaction_reference VARCHAR(255) UNIQUE,
  paid_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_payments_order ON payments (order_id);

-- ----------------------------------------------------------------
-- Table: product_reviews (customers review products)
-- ----------------------------------------------------------------
CREATE TABLE product_reviews (
  review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title VARCHAR(200),
  body TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
  CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
  UNIQUE KEY ux_customer_product_review (product_id, customer_id) -- one review per customer per product
) ENGINE=InnoDB;

CREATE INDEX idx_reviews_product ON product_reviews (product_id);

-- ----------------------------------------------------------------
-- Table: carts and cart_items (optional - quick shopping cart)
-- ----------------------------------------------------------------
CREATE TABLE carts (
  cart_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_carts_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cart_items (
  cart_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cart_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL CHECK (quantity > 0),
  added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id) REFERENCES carts(cart_id) ON DELETE CASCADE,
  CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
  UNIQUE KEY ux_cart_product (cart_id, product_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Sample views and supporting objects (optional, but helpful)
-- ----------------------------------------------------------------
-- View: order_summary (simple aggregated view)
DROP VIEW IF EXISTS v_order_summary;
CREATE VIEW v_order_summary AS
SELECT o.order_id, o.order_number, o.customer_id, o.order_date, o.status, o.total,
       COALESCE(p.payment_status, 'no_payment') AS payment_status
FROM orders o
LEFT JOIN payments p ON p.order_id = o.order_id
;

-- ----------------------------------------------------------------
-- Triggers (optional, ensure totals consistency)
-- Example: maintain orders.total as subtotal + shipping + tax on insert/update
-- (Note: application should generally compute totals; trigger included as protection)
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_orders_totals_before_insert;
DELIMITER $$
CREATE TRIGGER trg_orders_totals_before_insert
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
  IF NEW.subtotal IS NULL THEN
    SET NEW.subtotal = 0;
  END IF;
  IF NEW.shipping IS NULL THEN
    SET NEW.shipping = 0;
  END IF;
  IF NEW.tax IS NULL THEN
    SET NEW.tax = 0;
  END IF;
  SET NEW.total = (NEW.subtotal + NEW.shipping + NEW.tax);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_orders_totals_before_update;
DELIMITER $$
CREATE TRIGGER trg_orders_totals_before_update
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
  IF NEW.subtotal IS NULL THEN
    SET NEW.subtotal = 0;
  END IF;
  IF NEW.shipping IS NULL THEN
    SET NEW.shipping = 0;
  END IF;
  IF NEW.tax IS NULL THEN
    SET NEW.tax = 0;
  END IF;
  SET NEW.total = (NEW.subtotal + NEW.shipping + NEW.tax);
END$$
DELIMITER ;

-- ----------------------------------------------------------------
-- Helpful seed data (commented out). Uncomment to add sample entries.
-- ----------------------------------------------------------------
/*
INSERT INTO users (email, password_hash, role) VALUES
('alice@example.com','$2y$...hashed...','customer'),
('bob@example.com','$2y$...hashed...','admin');

-- Make Alice a customer (one-to-one)
INSERT INTO customers (customer_id, first_name, last_name, phone) VALUES
(1, 'Alice', 'Smith', '+2348012345678');

INSERT INTO categories (name, slug) VALUES
('Electronics','electronics'), ('Books','books'), ('Phones','phones');

INSERT INTO suppliers (name, contact_email) VALUES
('Acme Supplies', 'supply@acme.example');

INSERT INTO products (sku, name, description, price) VALUES
('SKU-001', 'Smartphone A1', 'A powerful smartphone', 299.99),
('SKU-002', 'USB-C Cable', 'Durable cable', 9.99);

INSERT INTO product_categories (product_id, category_id) VALUES (1,1), (1,3), (2,1);

INSERT INTO product_inventory (product_id, quantity) VALUES (1, 50), (2, 500);

INSERT INTO addresses (customer_id, street, city, country, is_default_shipping, is_default_billing)
VALUES (1, '12 Main St', 'Lagos', 'Nigeria', 1, 1);

-- Place an order
INSERT INTO orders (customer_id, order_number, subtotal, shipping, tax)
VALUES (1, 'ORD-20250918-0001', 309.98, 5.00, 15.50);

-- Add order items for order_id 1
INSERT INTO order_items (order_id, product_id, sku_snapshot, name_snapshot, unit_price, quantity, line_total)
VALUES (1,1,'SKU-001','Smartphone A1',299.99,1,299.99),
       (1,2,'SKU-002','USB-C Cable',9.99,1,9.99);

-- Add payment
INSERT INTO payments (order_id, payment_method, payment_status, paid_amount, transaction_reference, paid_at)
VALUES (1,'card','completed',314.98,'txn_abc123',NOW());
*/

-- ----------------------------------------------------------------
-- Final notes:
-- - Extend product variants (size/color/SKU) by adding product_variants table and linking inventory to variants.
-- - Consider partitioning very large tables, adding fulltext indexes on product descriptions, and caching frequently used queries.
-- ----------------------------------------------------------------

-- End of schema

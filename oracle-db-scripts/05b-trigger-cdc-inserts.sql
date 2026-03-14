-- =============================================================================
-- Trigger CDC by inserting new rows (high IDs to avoid conflicts)
-- Run as: ordermgmt - triggers CDC for all 13 tables
-- =============================================================================

INSERT INTO regions (region_id, region_name) VALUES (90, 'CDC-Test-Region');
INSERT INTO countries VALUES ('XX', 'CDC Test Country', 90);
INSERT INTO locations (location_id, address, city, country_id) VALUES (90, 'CDC Test Addr', 'CDC City', 'XX');
INSERT INTO warehouses (warehouse_id, warehouse_name, location_id) VALUES (90, 'CDC Warehouse', 90);
INSERT INTO product_categories (category_id, category_name) VALUES (90, 'CDC-Test-Cat');
INSERT INTO customers (customer_id, name, address, credit_limit) VALUES (90, 'CDC Test Customer', 'Test Addr', 500);
INSERT INTO employees (employee_id, first_name, last_name, email, phone, hire_date, job_title)
VALUES (90, 'CDC', 'Test', 'cdc@test.com', '555-9999', SYSDATE, 'Tester');
INSERT INTO products (product_id, product_name, category_id, list_price) VALUES (90, 'CDC Test Product', 90, 9.99);
INSERT INTO contacts (contact_id, first_name, last_name, email, customer_id) VALUES (90, 'CDC', 'Contact', 'contact@cdc.test', 90);
INSERT INTO orders (order_id, customer_id, status, salesman_id, order_date) VALUES (90, 90, 'Pending', 90, SYSDATE);
INSERT INTO order_items (order_id, item_id, product_id, quantity, unit_price) VALUES (90, 1, 90, 1, 9.99);
INSERT INTO inventories (product_id, warehouse_id, quantity) VALUES (90, 90, 10);
INSERT INTO notes (note_id, note) VALUES (90, 'CDC test note');
COMMIT;

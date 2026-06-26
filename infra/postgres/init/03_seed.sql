-- Carga inicial mínima para validar el pipeline end-to-end
INSERT INTO customers (email, full_name, country, segment) VALUES
 ('ana@example.com','Ana Gómez','CO','premium'),
 ('luis@example.com','Luis Pérez','MX','standard'),
 ('mia@example.com','Mia Rossi','IT','premium');

INSERT INTO products (sku, name, category, unit_price) VALUES
 ('SKU-1001','Teclado mecánico','peripherals',89.90),
 ('SKU-1002','Monitor 27 4K','displays',329.00),
 ('SKU-1003','Mouse ergonómico','peripherals',45.50);

INSERT INTO orders (customer_id, status, total_amount) VALUES
 (1,'paid',135.40),(2,'created',329.00);

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
 (1,1,1,89.90),(1,3,1,45.50),(2,2,1,329.00);

create table customers (
    customer_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100) unique not null,
    balance numeric(10,2) default 0
);

create table products (
    product_id serial primary key,
    product_name varchar(100) not null,
    price numeric(10,2) not null,
    stock_quantity int not null
);

create table orders (
    order_id serial primary key,
    customer_id int references customers(customer_id),
    order_date timestamp default current_timestamp,
    total_amount numeric(10,2) default 0
);

create table order_items (
    order_item_id serial primary key,
    order_id int references orders(order_id),
    product_id int references products(product_id),
    quantity int not null,
    price numeric(10,2) not null
);

create table order_log (
    log_id serial primary key,
    order_id int,
    customer_id int,
    action varchar(50),
    log_date timestamp default current_timestamp
);


--1. Task 1 — Function: Calculate Order Total
CREATE FUNCTION calculate_order_total(p_order_id int)
RETURNS NUMERIC(10, 2) AS $$
DECLARE 
	v_total NUMERIC(10, 2);
BEGIN
	SELECT sum(quantity * price)
	INTO v_total
	FROM order_items
	WHERE order_id = p_order_id;
	RETURN coalesce(v_total, 0.00);
END;
$$ LANGUAGE plpgsql;


--2. Task 2 — Procedure: Create New Order
CREATE PROCEDURE create_order(p_customer_id int)
AS $$
DECLARE 
	v_customer_exists boolean;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM customers
		WHERE customer_id = p_customer_id
	) INTO v_customer_exists;

	IF NOT v_customer_exists THEN
		RAISE EXCEPTION 'Customer with ID % does not exist.', p_customer_id;
	END IF;
	
	INSERT INTO orders(customer_id, order_date, total_amount)
	VALUES (p_customer_id, current_timestamp, 0.00);
END;
$$ LANGUAGE plpgsql;


--3. Task 3 — Procedure: Add Product to Order
CREATE PROCEDURE add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
AS $$
DECLARE
	v_product_price numeric(10, 2);
	v_stock_quantity int;
BEGIN
	IF p_quantity <= 0 THEN
		RAISE EXCEPTION 'Quantity must be greater than zero. Provided: %', p_quantity;
	END IF;
	
	SELECT price, stock_quantity
	INTO v_product_price, v_stock_quantity
	FROM products
	WHERE product_id = p_product_id;
	
	IF v_product_price IS NULL THEN
		RAISE EXCEPTION 'Product with ID % does not exist.', p_product_id;
	END IF;
	
	IF v_stock_quantity < p_quantity THEN
		RAISE EXCEPTION 'Not enough stock for product ID %. Available: %, Requested: %', p_product_id, v_stock_quantity, p_quantity;
	END IF;
	
	INSERT INTO order_items(order_id, product_id, quantity, price)
	VALUES (p_order_id, p_product_id, p_quantity, v_product_price);
	
	UPDATE products
	SET stock_quantity = stock_quantity - p_quantity
	WHERE product_id = p_product_id;
END;
$$ LANGUAGE plpgsql;


--4. Task 4 — Trigger: Update Order Total
CREATE FUNCTION trigger_update_order_total()
RETURNS TRIGGER AS $$
DECLARE 
	v_order_id int;
BEGIN
	IF tg_op = 'DELETE' THEN
		v_order_id := old.order_id;
	ELSE 
		v_order_id := new.order_id; --if tg_op = 'INSERT'
	END IF;

	UPDATE orders
	SET total_amount = calculate_order_total(v_order_id)
	WHERE order_id = v_order_id;
	
	IF tg_op = 'UPDATE' AND old.order_id != new.order_id THEN
		UPDATE orders
		SET total_amount = calculate_order_total(old.order_id)
		WHERE order_id = old.order_id;
	END IF;
	
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_items_changes
AFTER INSERT OR DELETE OR UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION trigger_update_order_total();


--5. Task 5 — Trigger: Order Audit Log
CREATE OR REPLACE function trigger_log_new_order()
RETURNS TRIGGER AS $$
BEGIN
	INSERT INTO order_log(order_id, customer_id, "action", log_date)
	VALUES (NEW.order_id, NEW.customer_id, 'CREATED', current_timestamp);
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_orders_audit_log
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION trigger_log_new_order();




--Task 6 — Testing--

--1. calculate_order_total(p_order_id int):

SELECT calculate_order_total(1); --returns 1,250
SELECT calculate_order_total(999); --returns 0


--2. create_order(p_customer_id int):

CALL create_order(1);
SELECT * FROM orders ORDER BY order_id DESC LIMIT 1; --видає новий запис в таблиці orders

CALL create_order(999); --показує ексепшн


--3. add_product_to_order(p_order_id int, p_product_id int, p_quantity int):

CALL add_product_to_order(1, 1, -3) --error: Quantity must be greater than zero. Provided: -3

CALL add_product_to_order(1, 1, 999) --error: Not enough stock for product (999)


SELECT stock_quantity FROM products WHERE product_id = 1; -- check quantity: Laptop - 9

CALL add_product_to_order(1, 1, 1);

SELECT stock_quantity FROM products WHERE product_id = 1; -- check for changes in stock: Laptop - 8

SELECT * FROM order_items WHERE order_id = 1; -- check changes in order items: +last row (6	1	1	1	1,200)


--4. trigger_update_order_total():

SELECT * FROM orders WHERE order_id = 1; --check order state now: 1	1	2026-06-26 12:42:53.348	1250.00

CALL add_product_to_order(1, 3, 2); --add 2 keyboards

SELECT * FROM orders WHERE order_id = 1; --check again: 1 1	  2026-06-26 12:42:53.348	2590.00


--5. trigger_log_new_order()

CALL create_order(2);

SELECT * FROM order_log ORDER BY log_id DESC LIMIT 1; -- 1	9	2	CREATED	2026-06-26 15:38:04.910


--Bonus Task 3 — Query Analysis

explain analyze
select
    oi.order_id,
    p.product_name,
    oi.quantity,
    oi.price,
    oi.quantity * oi.price as item_total
from order_items oi
join products p on oi.product_id = p.product_id
where oi.order_id = 1;


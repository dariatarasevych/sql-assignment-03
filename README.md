# Practice Assignment 3

## Topic
Create a small database system for managing orders in an online store.

The goal of this assignment is to practice:

* SQL functions;
* SQL procedures;
* triggers;
* audit logging;
* testing database logic;
* basic Git workflow;
* basic query analysis with EXPLAIN ANALYZE.

---

## Structure:

There are 5 tables:
* `customers` — customer profile details and their current financial balance.
* `products` — product catalog, including prices and available stock quantities.
* `orders` — order data (customer id, order date, and total amount).
* `order_items` — shopping cart (list of items for each order).
* `order_log` — audit table used to automatically log whenever a new order is created.

---

## Main Tasks:

1. **Function** `calculate_order_total(p_order_id)` — The function returns the total value of an order. The total is calculated using data from order_items. If the order has no products, returns `0`.
2. **Procedure** `create_order(p_customer_id)` — The procedure creates a new order for the selected customer.
3. **Procedure** `add_product_to_order(p_order_id, p_product_id, p_quantity)` — The procedure add a product to an order. Prevent adding a product if there is not enough stock. Prevent adding zero or negative quantity.
4. **Trigger** `trigger_items_changes` — A trigger automatically recalculates orders.total_amount whenever data in order_items changes.
5. **Trigger** `trigger_orders_audit_log` — A trigger writes a record into the order_log table after a new order is created.

---

## Testing:

1. Follow `Task 6 — Testing` in Script-5.sql

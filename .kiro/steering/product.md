# Product

Food Store is a PostgreSQL database schema project for a food retail application, developed as coursework for UTN's Base de Datos 2 (Database 2) course.

The schema models the core data layer of a food store: product catalog organized by categories, customer records, orders with payment method tracking, and order line items.

## Domain Entities

- **categoria** – product categories (soft-deletable via `activa` flag)
- **cliente** – customers identified by unique email
- **producto** – items for sale with price, stock, and category
- **pedido** – customer orders with payment method (`forma_pago` enum)
- **detalle_pedido** – order line items (N:M join between `pedido` and `producto`)

## Business Rules

- Payment methods are restricted to: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`
- Product prices and stock cannot be negative
- Line item subtotal is a derived value (`cantidad * precio_unitario`) — never stored
- Deleting a parent record is blocked if child records reference it (`ON DELETE RESTRICT`)

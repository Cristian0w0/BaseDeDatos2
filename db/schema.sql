-- schema.sql
-- Food Store - PostgreSQL
-- Esquema definitivo derivado de las Partes 2 y 3.

-- ============================================================
-- 1. Dominios cerrados
-- ============================================================

CREATE TYPE forma_pago AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

-- ============================================================
-- 2. Tablas principales
-- ============================================================

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    apellido VARCHAR(80) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_cliente_email_no_vacio
        CHECK (length(trim(email)) > 0)
);

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    precio NUMERIC(12,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    categoria_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id)
        REFERENCES categoria (id_categoria)
        ON DELETE RESTRICT,

    CONSTRAINT ck_producto_precio_no_negativo
        CHECK (precio >= 0),

    CONSTRAINT ck_producto_stock_no_negativo
        CHECK (stock >= 0)
);

CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id BIGINT NOT NULL,
    fecha_pedido TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago NOT NULL,

    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES cliente (id_cliente)
        ON DELETE RESTRICT
);

-- ============================================================
-- 3. Tabla intermedia de la relación N:M
-- ============================================================

CREATE TABLE detalle_pedido (
    pedido_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_detalle_pedido
        PRIMARY KEY (pedido_id, producto_id),

    CONSTRAINT fk_detalle_pedido_pedido
        FOREIGN KEY (pedido_id)
        REFERENCES pedido (id_pedido)
        ON DELETE RESTRICT,

    CONSTRAINT fk_detalle_pedido_producto
        FOREIGN KEY (producto_id)
        REFERENCES producto (id_producto)
        ON DELETE RESTRICT,

    CONSTRAINT ck_detalle_cantidad_positiva
        CHECK (cantidad > 0),

    CONSTRAINT ck_detalle_precio_no_negativo
        CHECK (precio_unitario >= 0)
);

-- No se almacena subtotal: es un atributo derivado de
-- cantidad * precio_unitario y puede calcularse al consultar.

-- ============================================================
-- 4. Índices
-- ============================================================

-- Acelera la consulta de los pedidos pertenecientes a un cliente,
-- por ejemplo: SELECT ... FROM pedido WHERE cliente_id = ?.
CREATE INDEX idx_pedido_cliente
    ON pedido (cliente_id);

-- Acelera el listado/búsqueda de productos de una categoría,
-- especialmente al consultar productos vigentes de esa categoría.
CREATE INDEX idx_producto_categoria_activo
    ON producto (categoria_id, activo);

-- Índice útil para localizar rápidamente las líneas de pedido
-- asociadas a un producto en consultas de historial de ventas.
CREATE INDEX idx_detalle_pedido_producto
    ON detalle_pedido (producto_id);

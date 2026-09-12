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

    CONSTRAINT uq_producto_categoria_nombre
        UNIQUE (categoria_id, nombre),

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

-- ============================================================
-- 5. Reglas de integridad complejas (Triggers)
-- ============================================================

-- Función de validación para garantizar que todo pedido posea al menos un detalle
CREATE OR REPLACE FUNCTION fn_validar_pedido_tiene_detalle()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_TABLE_NAME = 'pedido') THEN
        IF NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE pedido_id = NEW.id_pedido) THEN
            RAISE EXCEPTION 'El pedido % debe contener al menos un detalle.', NEW.id_pedido;
        END IF;
        RETURN NEW;

    ELSIF (TG_TABLE_NAME = 'detalle_pedido') THEN
        IF EXISTS (SELECT 1 FROM pedido WHERE id_pedido = OLD.pedido_id) THEN
            IF NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE pedido_id = OLD.pedido_id) THEN
                RAISE EXCEPTION 'El pedido % no puede quedarse sin detalles.', OLD.pedido_id;
            END IF;
        END IF;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger posponible al realizar COMMIT tras insertar o actualizar un pedido
CREATE CONSTRAINT TRIGGER trg_validar_pedido_con_detalle
    AFTER INSERT OR UPDATE ON pedido
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_pedido_tiene_detalle();

-- Trigger posponible al realizar COMMIT tras eliminar o modificar un detalle
CREATE CONSTRAINT TRIGGER trg_validar_detalle_minimo
    AFTER DELETE OR UPDATE ON detalle_pedido
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_pedido_tiene_detalle();

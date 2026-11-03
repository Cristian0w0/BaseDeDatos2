-- ============================================================================
-- Archivo: db/tp7_clase1_prerrequisitos.sql
-- Descripción: Objetos de base de datos requeridos por la Clase 1 de la Unidad 5
--              (usuarios, vistas complementarias, extensión criptográfica y
--              procedimiento sp_crear_pedido).
-- Motor: PostgreSQL 16+
-- ============================================================================

SET search_path TO public;

-- 1. Extensión criptográfica para almacenamiento seguro de contraseñas
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Tipo enumerado para roles de negocio (capa de aplicación)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol') THEN
        CREATE TYPE rol AS ENUM ('ADMIN', 'USUARIO');
    END IF;
END $$;

-- 3. Tabla usuario (conforme a especificaciones de U5 Clase 1 y Clase 2)
CREATE TABLE IF NOT EXISTS usuario (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    apellido VARCHAR(80) NOT NULL,
    mail VARCHAR(254) NOT NULL UNIQUE,
    celular VARCHAR(30),
    contrasena TEXT NOT NULL,
    rol rol NOT NULL DEFAULT 'USUARIO',
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_usuario_mail_no_vacio
        CHECK (length(trim(mail)) > 0)
);

-- Poblado inicial básico de usuarios para pruebas si la tabla está vacía
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol)
SELECT
    'Administrador', 'General', 'admin@foodstore.com', '1144332211',
    crypt('Admin2026!Segura', gen_salt('bf')), 'ADMIN'::rol
WHERE NOT EXISTS (SELECT 1 FROM usuario WHERE mail = 'admin@foodstore.com');

INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol)
SELECT
    'Juan', 'Perez', 'juan.perez@foodstore.com', '1155667788',
    crypt('Usuario2026!Pass', gen_salt('bf')), 'USUARIO'::rol
WHERE NOT EXISTS (SELECT 1 FROM usuario WHERE mail = 'juan.perez@foodstore.com');

INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol)
SELECT
    'Maria', 'Gomez', 'maria.gomez@foodstore.com', '1199887766',
    crypt('Maria2026!Pass', gen_salt('bf')), 'USUARIO'::rol
WHERE NOT EXISTS (SELECT 1 FROM usuario WHERE mail = 'maria.gomez@foodstore.com');

-- 4. Vistas complementarias requeridas por los roles de la Clase 1

-- Vista de categorías vigentes (para rol_app_lectura)
CREATE OR REPLACE VIEW v_categorias_vigentes AS
SELECT
    id_categoria,
    nombre,
    created_at
FROM categoria
WHERE activa = TRUE;

-- Vista pública de usuarios (para rol_soporte: sin contraseña ni celular)
CREATE OR REPLACE VIEW v_usuarios_publico AS
SELECT
    id,
    nombre,
    apellido,
    mail,
    rol
FROM usuario
WHERE eliminado = FALSE;

-- Vista resumen de pedidos (para rol_soporte)
CREATE OR REPLACE VIEW v_pedidos_resumen AS
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago,
    COUNT(dp.producto_id) AS total_items,
    COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0) AS total_pedido
FROM pedido p
LEFT JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
GROUP BY p.id_pedido, p.cliente_id, p.fecha_pedido, p.forma_pago;

-- Vista analítica de ventas por categoría y mes (para rol_reportes)
CREATE OR REPLACE VIEW mv_ventas_categoria_mes AS
SELECT
    to_char(p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM') AS periodo_mes,
    pr.categoria_id,
    c.nombre AS nombre_categoria,
    SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.categoria_id
GROUP BY
    to_char(p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM'),
    pr.categoria_id,
    c.nombre;

-- 5. Procedimiento almacenado sp_crear_pedido
-- Requerido para el privilegio EXECUTE otorgado a rol_app_escritura
CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    p_cliente_id BIGINT,
    p_forma_pago forma_pago,
    p_items JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_pedido BIGINT;
    v_item RECORD;
    v_precio_actual NUMERIC(12,2);
    v_stock_actual INTEGER;
BEGIN
    -- Validar existencia del cliente
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = p_cliente_id) THEN
        RAISE EXCEPTION 'El cliente con ID % no existe.', p_cliente_id;
    END IF;

    -- Validar que la lista de items contenga elementos
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El pedido debe incluir al menos un producto.';
    END IF;

    -- 1. Insertar cabecera del pedido
    INSERT INTO pedido (cliente_id, fecha_pedido, forma_pago)
    VALUES (p_cliente_id, now(), p_forma_pago)
    RETURNING id_pedido INTO v_id_pedido;

    -- 2. Procesar e insertar cada item
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(producto_id BIGINT, cantidad INTEGER)
    LOOP
        -- Consultar stock y precio actual
        SELECT precio, stock
        INTO v_precio_actual, v_stock_actual
        FROM producto
        WHERE id_producto = v_item.producto_id AND activo = TRUE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto ID % no disponible o inactivo.', v_item.producto_id;
        END IF;

        IF v_stock_actual < v_item.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para el producto ID %. Disponible: %, Solicitado: %',
                v_item.producto_id, v_stock_actual, v_item.cantidad;
        END IF;

        -- Insertar línea de detalle
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
        VALUES (v_id_pedido, v_item.producto_id, v_item.cantidad, v_precio_actual);

        -- Actualizar stock
        UPDATE producto
        SET stock = stock - v_item.cantidad
        WHERE id_producto = v_item.producto_id;
    END LOOP;
END;
$$;

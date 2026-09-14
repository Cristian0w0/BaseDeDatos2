-- ============================================================================
-- Trabajo Práctico 3 - Base de Datos 2 (Food Store)
-- Script de Generación Masiva de Datos para Copia de Trabajo (bd2_tp3)
-- Archivo: db/generador_datos_tp3.sql
-- ============================================================================
-- NOTA: Este script está preparado para ejecutarse dentro de un bloque
-- transaccional (BEGIN ... ROLLBACK o COMMIT).
-- NO realiza operaciones DDL ni modifica la estructura de las tablas.
--
-- ESTADO INICIAL DE LA BASE (1 registro por tabla principal):
--  - 1 categoría (id_categoria = 3, 'Bebidas')
--  - 1 cliente
--  - 1 producto
--  - 1 pedido
--  - 1 detalle
--
-- REGISTROS A INSERTAR (cantidades exactas faltantes):
--  - 19.999 clientes        -> Total resultante:  20.000 clientes
--  - 49.999 productos       -> Total resultante:  50.000 productos
--  - 199.999 pedidos        -> Total resultante: 200.000 pedidos
--  - 199.999 detalles       -> Total resultante: 200.000 detalles
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Inserción de Clientes (19.999 registros nuevos)
-- ============================================================================
-- Se generan emails con dominio interno exclusivo '@tp3-carga.foodstore.internal'
-- y un hash unívoco por iterador.
-- Prevención explícita de colisión mediante cláusula WHERE NOT EXISTS contra la
-- tabla cliente para descartar cualquier email preexistente.
-- id_cliente se genera automáticamente por PostgreSQL (GENERATED ALWAYS AS IDENTITY).
-- ============================================================================

INSERT INTO cliente (nombre, apellido, email, created_at)
SELECT
    (ARRAY['Juan', 'María', 'Carlos', 'Ana', 'Pedro', 'Lucía', 'Diego', 'Sofía', 'Martín', 'Laura',
           'Federico', 'Valentina', 'Gonzalo', 'Camila', 'Joaquín', 'Florencia', 'Mateo', 'Julieta', 'Lucas', 'Agustina'])[(i % 20) + 1] AS nombre,
    (ARRAY['Gómez', 'Rodríguez', 'Pérez', 'González', 'Fernández', 'López', 'Martínez', 'Díaz', 'Romero', 'Álvarez',
           'Torres', 'Ruiz', 'Ramírez', 'Flores', 'Benítez', 'Acosta', 'Medina', 'Herrera', 'Suárez', 'Castro'])[(i % 20) + 1] AS apellido,
    'cliente_tp3_' || i || '_' || md5(i::text || 'tp3_seed') || '@tp3-carga.foodstore.internal' AS email,
    now() - ((i % 730) || ' days')::INTERVAL - ((i % 86400) || ' seconds')::INTERVAL AS created_at
FROM generate_series(1, 19999) AS g(i)
WHERE NOT EXISTS (
    SELECT 1
    FROM cliente c_exist
    WHERE c_exist.email = 'cliente_tp3_' || i || '_' || md5(i::text || 'tp3_seed') || '@tp3-carga.foodstore.internal'
);

-- ============================================================================
-- 2. Inserción de Productos (49.999 registros nuevos)
-- ============================================================================
-- Todos los productos nuevos utilizan la categoría existente id_categoria = 3 ('Bebidas').
-- Nombres únicos garantizados por 'Producto Bebida TP3 #' || i dentro de categoria_id = 3.
-- Precios y stock estrictamente no negativos (cumpliendo CHECKs).
-- id_producto se genera automáticamente por PostgreSQL.
-- ============================================================================

INSERT INTO producto (nombre, precio, stock, activo, categoria_id, created_at)
SELECT
    'Producto Bebida TP3 #' || i AS nombre,
    (50.00 + ((i * 17) % 15000) * 0.50)::NUMERIC(12,2) AS precio,
    ((i * 13) % 500)::INTEGER AS stock,
    (i % 15 <> 0) AS activo,
    3 AS categoria_id,
    now() - ((i % 730) || ' days')::INTERVAL - ((i % 86400) || ' seconds')::INTERVAL AS created_at
FROM generate_series(1, 49999) AS g(i);

-- ============================================================================
-- 3. Inserción de Pedidos y Detalles de Pedido (199.999 pedidos + 199.999 detalles)
-- ============================================================================
-- Se utiliza un CTE con INSERT ... RETURNING id_pedido para capturar los IDs reales
-- generados por PostgreSQL para los 199.999 pedidos nuevos.
--
-- Los clientes se asignan consultando todos los clientes reales existentes (incluyendo
-- los recién insertados) mediante ROW_NUMBER(), asegurando integridad referencial
-- sin asumir IDs correlativos o iniciales.
--
-- De igual manera, para los detalles se consultan los productos reales disponibles,
-- asignando a cada pedido exactamente un detalle con precio unitario válido y cantidad > 0.
--
-- Esto garantiza:
--  - Integridad referencial (FKs válidas hacia cliente, pedido y producto).
--  - Unicidad en PK (pedido_id, producto_id).
--  - Cumplimiento estricto del trigger DEFERRABLE trg_validar_pedido_con_detalle.
-- ============================================================================

WITH clientes_disponibles AS (
    SELECT
        id_cliente,
        ROW_NUMBER() OVER (ORDER BY id_cliente) AS rn,
        COUNT(*) OVER () AS total
    FROM cliente
),
productos_disponibles AS (
    SELECT
        id_producto,
        precio,
        ROW_NUMBER() OVER (ORDER BY id_producto) AS rn,
        COUNT(*) OVER () AS total
    FROM producto
),
nuevos_pedidos AS (
    INSERT INTO pedido (cliente_id, fecha_pedido, forma_pago)
    SELECT
        c.id_cliente,
        now() - ((g.i % 365) || ' days')::INTERVAL - ((g.i % 86400) || ' seconds')::INTERVAL AS fecha_pedido,
        (ARRAY['EFECTIVO'::forma_pago, 'TARJETA'::forma_pago, 'TRANSFERENCIA'::forma_pago])[(g.i % 3) + 1] AS forma_pago
    FROM generate_series(1, 199999) AS g(i)
    JOIN clientes_disponibles c
        ON c.rn = ((g.i - 1) % c.total) + 1
    RETURNING id_pedido
),
pedidos_numerados AS (
    SELECT
        id_pedido,
        ROW_NUMBER() OVER (ORDER BY id_pedido) AS rn
    FROM nuevos_pedidos
)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
    pn.id_pedido,
    pd.id_producto,
    ((pn.rn % 10) + 1)::INTEGER AS cantidad,
    pd.precio AS precio_unitario
FROM pedidos_numerados pn
JOIN productos_disponibles pd
    ON pd.rn = ((pn.rn - 1) % pd.total) + 1;

-- ============================================================================
-- 4. Consultas de Verificación y Validación de Integridad
-- ============================================================================

-- 4.1. Conteo total por tabla (Totales esperados: 1 categoria, 20.000 clientes, 50.000 productos, 200.000 pedidos, 200.000 detalles)
SELECT 'categoria' AS tabla, COUNT(*) AS total_filas, 1 AS total_esperado FROM categoria
UNION ALL
SELECT 'cliente', COUNT(*), 20000 FROM cliente
UNION ALL
SELECT 'producto', COUNT(*), 50000 FROM producto
UNION ALL
SELECT 'pedido', COUNT(*), 200000 FROM pedido
UNION ALL
SELECT 'detalle_pedido', COUNT(*), 200000 FROM detalle_pedido;

-- 4.2. Validación de pedidos huérfanos (pedidos sin detalles)
-- Debe devolver 0 filas
SELECT COUNT(*) AS pedidos_sin_detalle
FROM pedido p
LEFT JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
WHERE dp.pedido_id IS NULL;

-- 4.3. Validación de integridad referencial: Pedidos con cliente inexistente
-- Debe devolver 0 filas
SELECT COUNT(*) AS pedidos_con_cliente_invalido
FROM pedido p
LEFT JOIN cliente c ON p.cliente_id = c.id_cliente
WHERE c.id_cliente IS NULL;

-- 4.4. Validación de integridad referencial: Detalles con producto inexistente
-- Debe devolver 0 filas
SELECT COUNT(*) AS detalles_con_producto_invalido
FROM detalle_pedido dp
LEFT JOIN producto pr ON dp.producto_id = pr.id_producto
WHERE pr.id_producto IS NULL;

-- 4.5. Validación de integridad referencial: Detalles con pedido inexistente
-- Debe devolver 0 filas
SELECT COUNT(*) AS detalles_con_pedido_invalido
FROM detalle_pedido dp
LEFT JOIN pedido p ON dp.pedido_id = p.id_pedido
WHERE p.id_pedido IS NULL;

-- 4.6. Validación de productos con categoría inexistente o distinta de 3
-- Debe devolver 0 filas
SELECT COUNT(*) AS productos_categoria_invalida
FROM producto
WHERE categoria_id <> 3;

-- 4.7. Validación de restricciones CHECK (valores inválidos)
-- Todos los conteos deben ser 0
SELECT
    (SELECT COUNT(*) FROM cliente WHERE length(trim(email)) = 0) AS clientes_email_vacio,
    (SELECT COUNT(*) FROM producto WHERE precio < 0) AS productos_precio_negativo,
    (SELECT COUNT(*) FROM producto WHERE stock < 0) AS productos_stock_negativo,
    (SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0) AS detalles_cantidad_invalida,
    (SELECT COUNT(*) FROM detalle_pedido WHERE precio_unitario < 0) AS detalles_precio_negativo;

-- 4.8. Validación de duplicados en detalle_pedido (pedido_id, producto_id)
-- Debe devolver 0 filas
SELECT pedido_id, producto_id, COUNT(*) AS duplicados
FROM detalle_pedido
GROUP BY pedido_id, producto_id
HAVING COUNT(*) > 1;

-- ============================================================================
-- FIN DEL SCRIPT
-- Para pruebas iniciales, mantener ROLLBACK.
-- Para confirmar la carga tras validar, cambiar por COMMIT.
-- ============================================================================
COMMIT;

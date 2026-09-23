-- ============================================================
-- TPI - Primera entrega parcial
-- Pruebas reproducibles
-- ============================================================

-- Base de datos esperada:
-- bd2_tpi_parcial1

-- ============================================================
-- 1. Procedimiento almacenado y borrado lógico
-- ============================================================

-- Selección de un producto activo para la prueba.
SELECT
    id_producto,
    nombre,
    activo
FROM producto
WHERE activo = TRUE
ORDER BY id_producto
LIMIT 1;

-- La operación se prueba dentro de una transacción para no
-- modificar permanentemente los datos de la base de trabajo.
BEGIN;

CALL sp_desactivar_producto(5);

-- El producto debe conservarse, pero quedar inactivo.
SELECT
    id_producto,
    nombre,
    activo
FROM producto
WHERE id_producto = 5;

-- La vista de productos vigentes no debe devolver el producto
-- desactivado.
SELECT
    id_producto,
    nombre
FROM v_productos_vigentes
WHERE id_producto = 5;

-- Se revierte la prueba para conservar los datos originales.
ROLLBACK;

-- Verificación final: el producto vuelve a estar activo.
SELECT
    id_producto,
    nombre,
    activo
FROM producto
WHERE id_producto = 5;

-- ============================================================
-- 2. Verificación del procedimiento en el catálogo
-- ============================================================

SELECT
    p.proname AS nombre,
    pg_get_function_identity_arguments(p.oid) AS argumentos,
    pg_get_function_result(p.oid) AS retorno,
    l.lanname AS lenguaje
FROM pg_proc p
JOIN pg_language l
    ON l.oid = p.prolang
WHERE p.proname = 'sp_desactivar_producto';

-- ============================================================
-- 3. Regla de negocio: todo pedido debe tener al menos un detalle
-- ============================================================

-- La siguiente operación debe fallar al hacer COMMIT porque el
-- pedido se crea sin detalles. El trigger es DEFERRABLE
-- INITIALLY DEFERRED, por lo que la validación ocurre al confirmar
-- la transacción.

BEGIN;

INSERT INTO pedido (
    cliente_id,
    fecha_pedido,
    forma_pago
)
VALUES (
    1,
    now(),
    'EFECTIVO'
);

COMMIT;

-- Si el COMMIT falla con la excepción de la función
-- fn_validar_pedido_tiene_detalle(), ejecutar ROLLBACK para
-- finalizar la transacción abortada y dejar la base sin cambios.
ROLLBACK;

-- ============================================================
-- 4. Verificación de vistas
-- ============================================================

-- Cantidad de productos activos expuestos por la vista.
SELECT COUNT(*) AS productos_vigentes
FROM v_productos_vigentes;

-- La vista de pedidos debe relacionar cada pedido con su cliente.
SELECT COUNT(*) AS pedidos_con_cliente
FROM v_pedidos_con_cliente;

-- La vista de detalle debe conservar el historial de productos,
-- incluso cuando un producto se encuentre inactivo.
SELECT COUNT(*) AS detalles_con_producto
FROM v_detalle_pedido_con_producto;

-- La vista materializada debe contener el resumen de gasto
-- calculado por cliente.
SELECT COUNT(*) AS clientes_resumidos
FROM v_resumen_gasto_cliente;

-- Verificación de que la vista materializada posee el índice
-- único requerido para REFRESH CONCURRENTLY.
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'v_resumen_gasto_cliente';

-- ============================================================
-- 5. Borrado lógico y efecto sobre las consultas
-- ============================================================

-- Se selecciona el producto 5, utilizado en la prueba del procedimiento.
SELECT
    id_producto,
    nombre,
    activo
FROM producto
WHERE id_producto = 5;

BEGIN;

-- El procedimiento realiza el borrado lógico.
CALL sp_desactivar_producto(5);

-- El registro físico permanece, pero queda inactivo.
SELECT
    id_producto,
    nombre,
    activo
FROM producto
WHERE id_producto = 5;

-- La consulta de productos vigentes ya no debe devolverlo.
SELECT
    id_producto,
    nombre
FROM v_productos_vigentes
WHERE id_producto = 5;

ROLLBACK;

-- Se verifica que la prueba no modificó permanentemente los datos.
SELECT
    id_producto,
    nombre,
    activo
FROM producto
WHERE id_producto = 5;

-- ============================================================
-- 6. Verificación de restricciones de integridad
-- ============================================================

-- Se obtiene una categoría existente para evitar depender
-- de un ID o nombre específico.
SELECT
    id_categoria,
    nombre
FROM categoria
ORDER BY id_categoria
LIMIT 1;

-- CHECK: el precio de un producto no puede ser negativo.
-- Esta sentencia debe generar una violación de CHECK.
INSERT INTO producto (
    nombre,
    precio,
    stock,
    activo,
    categoria_id
)
VALUES (
    'PRUEBA_CHECK_PRECIO',
    -1,
    10,
    TRUE,
    (SELECT id_categoria FROM categoria ORDER BY id_categoria LIMIT 1)
);

-- CHECK: el stock de un producto no puede ser negativo.
-- Esta sentencia debe generar una violación de CHECK.
INSERT INTO producto (
    nombre,
    precio,
    stock,
    activo,
    categoria_id
)
VALUES (
    'PRUEBA_CHECK_STOCK',
    100,
    -1,
    TRUE,
    (SELECT id_categoria FROM categoria ORDER BY id_categoria LIMIT 1)
);

-- UNIQUE: se intenta reutilizar el nombre de una categoría existente.
-- Esta sentencia debe generar una violación de UNIQUE.
INSERT INTO categoria (nombre, activa)
SELECT nombre, TRUE
FROM categoria
ORDER BY id_categoria
LIMIT 1;

-- FK: un producto no puede referenciar una categoría inexistente.
-- Esta sentencia debe generar una violación de FOREIGN KEY.
INSERT INTO producto (
    nombre,
    precio,
    stock,
    activo,
    categoria_id
)
VALUES (
    'PRUEBA_FK',
    100,
    10,
    TRUE,
    999999999
);

-- ============================================================
-- 7. Verificación de índices
-- ============================================================

-- Inventario de índices del esquema público.
-- Permite verificar PK, UNIQUE e índices de optimización.
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Verificación específica de los índices parciales aceptados
-- durante TP5.
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
      'idx_pedido_tarjeta_fecha',
      'idx_producto_activo_precio'
  )
ORDER BY indexname;

-- ============================================================
-- 8. Verificación del motor y transacciones
-- ============================================================

-- La consigna requiere PostgreSQL 16 o superior.
SELECT version();

-- Verificación básica de una transacción con ROLLBACK.
BEGIN;

UPDATE producto
SET stock = stock + 1
WHERE id_producto = 5;

-- El cambio es visible dentro de la transacción.
SELECT
    id_producto,
    stock
FROM producto
WHERE id_producto = 5;

-- Se revierte el cambio para conservar los datos originales.
ROLLBACK;

-- El stock vuelve al valor previo a la prueba.
SELECT
    id_producto,
    stock
FROM producto
WHERE id_producto = 5;

-- ============================================================
-- 9. Verificación de consultas del proyecto
-- ============================================================

-- Las consultas completas desarrolladas durante TP3 y TP4 se
-- conservan en:
--   db/consultas_tp4_parte3.sql
--   db/generador_datos_tp3.sql
--   db/generador_datos_tp3_carga.sql
--
-- El siguiente ejemplo combina JOIN, agregación, GROUP BY,
-- HAVING y función de ventana.

SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total,
    RANK() OVER (
        ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC
    ) AS posicion_ranking
FROM cliente c
JOIN pedido p
    ON p.cliente_id = c.id_cliente
JOIN detalle_pedido dp
    ON dp.pedido_id = p.id_pedido
GROUP BY
    c.id_cliente,
    c.nombre,
    c.apellido
HAVING COUNT(DISTINCT p.id_pedido) > 1
ORDER BY gasto_total DESC, c.id_cliente
LIMIT 10;

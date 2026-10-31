-- ============================================================================
-- TP6 - Base de Datos 2 - Food Store
-- Punto 5.2 e) - Auditoría de sincronización de la vista materializada
-- Archivo: db/tp6_auditoria_ventas.sql
-- ============================================================================
-- Objetivo:
--   Verificar que el dato redundante total_ventas de mv_ventas_categoria_dia
--   coincida con su fuente de verdad (pedido, detalle_pedido y producto) para
--   todo el histórico, no solo para el día actual.
--
-- Carácter de la auditoría:
--   Solo lectura. No crea, modifica ni refresca objetos ni datos.
--   La consulta principal devuelve únicamente discrepancias: un resultado
--   vacío (0 filas) significa que la vista coincide con las tablas originales.
--
-- Ejecución en DBeaver sobre la base bd2_tp6:
--   1. Ejecutar la consulta opcional de la Sección 1 para comprobar que la
--      vista está poblada (ispopulated = true).
--   2. Ejecutar la consulta principal de la Sección 2 (Ctrl+Enter).
--   3. Esperar 0 filas si la vista está sincronizada.
--
-- Ejecución por consola (opcional):
--   psql -U <usuario> -d bd2_tp6 -f db/tp6_auditoria_ventas.sql
--
-- Condiciones para esperar un resultado vacío:
--   - La vista materializada está poblada (ispopulated = true).
--   - Su definición coincide con la de db/tp6_vista_materializada_ventas.sql:
--     misma expresión de fecha con zona horaria, mismo SUM y mismo GROUP BY.
--   - Se ejecutó REFRESH MATERIALIZED VIEW después del último cambio en
--     pedido, detalle_pedido o producto.categoria_id.
--   - No hay ventas nuevas o modificadas sin refrescar entre el último
--     refresco y esta auditoría; en ese caso la diferencia es una
--     desactualización esperada, no una inconsistencia de la vista.
-- ============================================================================

SET search_path TO public;


-- ----------------------------------------------------------------------------
-- 1. Consulta opcional de estado (ejecutar por separado)
-- ----------------------------------------------------------------------------
-- Comprueba que la vista exista y esté poblada. No forma parte de la
-- auditoría principal: devuelve una fila aunque todo esté sincronizado.
--
-- Si ispopulated = false, la consulta principal fallará porque la vista no
-- puede leerse. En ese caso se debe poblar con un refresco normal (operación
-- que NO forma parte de esta auditoría de solo lectura):
--   REFRESH MATERIALIZED VIEW public.mv_ventas_categoria_dia;

SELECT
    schemaname,
    matviewname,
    ispopulated,
    hasindexes
FROM pg_matviews
WHERE schemaname = 'public'
  AND matviewname = 'mv_ventas_categoria_dia';


-- ----------------------------------------------------------------------------
-- 2. Auditoría principal: comparación de todo el histórico
-- ----------------------------------------------------------------------------
-- Recalcula los totales desde las tablas originales usando exactamente la
-- misma expresión de fecha y zona horaria que la vista materializada y los
-- compara contra mv_ventas_categoria_dia con FULL OUTER JOIN.
--
-- Casos detectados:
--   FALTA_EN_VISTA    -> combinación (fecha, categoria_id) presente en las
--                        tablas originales pero ausente en la vista.
--   SOBRA_EN_VISTA    -> combinación presente en la vista pero sin respaldo
--                        actual en las tablas originales.
--   IMPORTE_DISTINTO  -> la combinación existe en ambos lados, pero el total
--                        no coincide.
--
-- Un resultado vacío indica que la vista coincide con las tablas originales.

WITH base AS (
    SELECT
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha,
        pr.categoria_id,
        SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
    FROM pedido AS p
    JOIN detalle_pedido AS dp
        ON dp.pedido_id = p.id_pedido
    JOIN producto AS pr
        ON pr.id_producto = dp.producto_id
    GROUP BY
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
        pr.categoria_id
),
vista AS (
    SELECT
        mv.fecha,
        mv.categoria_id,
        mv.total_ventas
    FROM mv_ventas_categoria_dia AS mv
)
SELECT
    COALESCE(b.fecha, v.fecha)               AS fecha,
    COALESCE(b.categoria_id, v.categoria_id) AS categoria_id,
    b.total_ventas                           AS total_base,
    v.total_ventas                           AS total_vista,
    b.total_ventas - v.total_ventas          AS diferencia,
    CASE
        WHEN v.fecha IS NULL THEN 'FALTA_EN_VISTA'
        WHEN b.fecha IS NULL THEN 'SOBRA_EN_VISTA'
        ELSE 'IMPORTE_DISTINTO'
    END                                      AS tipo_discrepancia
FROM base AS b
FULL OUTER JOIN vista AS v
    ON v.fecha = b.fecha
   AND v.categoria_id = b.categoria_id
WHERE b.fecha IS NULL
   OR v.fecha IS NULL
   OR b.total_ventas IS DISTINCT FROM v.total_ventas
ORDER BY fecha, categoria_id;

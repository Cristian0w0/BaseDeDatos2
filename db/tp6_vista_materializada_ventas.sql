-- ============================================================================
-- TP6 - Base de Datos 2 - Food Store
-- Punto 5.2 c) - Estructura desnormalizada y mecanismo de sincronización
-- Archivo sugerido: db/tp6_vista_materializada_ventas.sql
-- ============================================================================
-- Guía de ejecución según el escenario:
--
-- ESCENARIO 1: Primera ejecución (Creación inicial)
--   Ejecutar la Sección 1 (CREATE MATERIALIZED VIEW ... WITH DATA) y la
--   Sección 2 (CREATE UNIQUE INDEX). La vista queda poblada y lista para usarse.
--   Nota: 'CREATE UNIQUE INDEX IF NOT EXISTS' evita un error de sintaxis si el
--   nombre ya existe, pero NO verifica que un índice preexistente con ese mismo
--   nombre tenga la definición correcta sobre (fecha, categoria_id).
--
-- ESCENARIO 2: La vista ya existe y está poblada (ispopulated = true)
--   NO volver a ejecutar la creación DDL ('IF NOT EXISTS' no actualiza la
--   definición de una vista o índice preexistente).
--   Antes de usar 'REFRESH MATERIALIZED VIEW CONCURRENTLY', se debe verificar
--   que exista un índice UNIQUE válido sobre (fecha, categoria_id), definido
--   sobre columnas simples y que cubra todas las filas de la vista.
--   Para actualizar los datos, ejecutar únicamente:
--     REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_dia;
--
-- ESCENARIO 3: La vista existe pero está vacía (ispopulated = false / WITH NO DATA)
--   'REFRESH CONCURRENTLY' fallará si la vista no posee un poblado previo.
--   Se debe ejecutar primero un refresco normal (no concurrente):
--     REFRESH MATERIALIZED VIEW mv_ventas_categoria_dia;
--   Una vez poblada (y verificado el índice UNIQUE válido), los refrescos
--   posteriores pueden ser concurrentes.
-- ============================================================================

SET search_path TO public;

-- ----------------------------------------------------------------------------
-- 1. Creación inicial de la vista materializada
-- ----------------------------------------------------------------------------
-- Agrupa las ventas por fecha local ('America/Argentina/Buenos_Aires') y categoría.
-- 'WITH DATA' realiza el poblado inicial inmediato durante la primera creación.

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_ventas_categoria_dia AS
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
WITH DATA;

-- ----------------------------------------------------------------------------
-- 2. Índice único obligatorio para el refresco concurrente
-- ----------------------------------------------------------------------------
-- Requerido obligatoriamente por REFRESH MATERIALIZED VIEW CONCURRENTLY para
-- permitir actualizaciones sin bloquear las lecturas del panel.

CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_ventas_categoria_dia_fecha_categoria
    ON mv_ventas_categoria_dia (fecha, categoria_id);


-- ----------------------------------------------------------------------------
-- 3. Instrucciones de refresco periódico posterior
-- ----------------------------------------------------------------------------
-- NO ejecutar inmediatamente después del CREATE con WITH DATA (es redundante).
-- Ejecutar periódicamente desde el planificador externo.
-- NO ejecutar dentro de un bloque de transacción explícito (BEGIN ... COMMIT).

-- Refresco concurrente (uso habitual cuando ispopulated = true):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_dia;

-- Refresco normal (solo si la vista estuviera vacía / ispopulated = false):
-- REFRESH MATERIALIZED VIEW mv_ventas_categoria_dia;


-- ============================================================================
-- 4. Consulta optimizada del panel (Top 5 del día actual)
-- ============================================================================

SELECT
    c.nombre AS categoria,
    mv.total_ventas
FROM mv_ventas_categoria_dia AS mv
JOIN categoria AS c
    ON c.id_categoria = mv.categoria_id
WHERE mv.fecha = (CURRENT_TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
ORDER BY mv.total_ventas DESC, c.nombre
LIMIT 5;


-- ============================================================================
-- 5. Consultas de verificación
-- ============================================================================

-- A. Estado de la vista (verificar que ispopulated = true)
SELECT
    schemaname,
    matviewname,
    ispopulated,
    hasindexes
FROM pg_matviews
WHERE schemaname = 'public'
  AND matviewname = 'mv_ventas_categoria_dia';

-- B. Existencia del índice único obligatorio
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'mv_ventas_categoria_dia';

-- C. Verificación de ausencia de duplicados para (fecha, categoria_id)
SELECT fecha, categoria_id, COUNT(*) AS filas
FROM mv_ventas_categoria_dia
GROUP BY fecha, categoria_id
HAVING COUNT(*) > 1;

-- D. Conteo de filas y rango de fechas materializadas
SELECT
    COUNT(*) AS total_filas_materializadas,
    MIN(fecha) AS primera_fecha,
    MAX(fecha) AS ultima_fecha
FROM mv_ventas_categoria_dia;

-- E. Comparación punto a punto contra las tablas base para el día actual
-- (Devuelve 0 filas si la vista está exactamente sincronizada en el instante de la prueba)
WITH hoy AS (
    SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha
),
base AS (
    SELECT
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha,
        pr.categoria_id,
        SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
    FROM pedido AS p
    JOIN detalle_pedido AS dp
        ON dp.pedido_id = p.id_pedido
    JOIN producto AS pr
        ON pr.id_producto = dp.producto_id
    JOIN hoy
        ON (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date = hoy.fecha
    GROUP BY
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
        pr.categoria_id
),
mv_hoy AS (
    SELECT mv.fecha, mv.categoria_id, mv.total_ventas
    FROM mv_ventas_categoria_dia AS mv
    JOIN hoy
        ON mv.fecha = hoy.fecha
)
SELECT
    COALESCE(b.fecha, m.fecha) AS fecha,
    COALESCE(b.categoria_id, m.categoria_id) AS categoria_id,
    b.total_ventas AS total_base,
    m.total_ventas AS total_mv
FROM base AS b
FULL OUTER JOIN mv_hoy AS m
    ON m.fecha = b.fecha
   AND m.categoria_id = b.categoria_id
WHERE b.fecha IS NULL
   OR m.fecha IS NULL
   OR b.total_ventas IS DISTINCT FROM m.total_ventas;


-- ============================================================================
-- 6. Programación del refresco externo (Windows / PowerShell)
-- ============================================================================
-- PostgreSQL estándar no incluye un programador de tareas interno (sin pg_cron).
--
-- Para automatizar el refresco en un entorno Windows, se utiliza el
-- Programador de tareas (Task Scheduler) configurando una acción que ejecute
-- PowerShell con la herramienta 'psql.exe'.
--
-- Comando de ejemplo para PowerShell:
--
--   $env:PGPASSWORD = "<tu_contraseña>"
--   & "C:\Program Files\PostgreSQL\<version>\bin\psql.exe" `
--     -h "localhost" -p 5432 -U "<usuario>" -d "bd2_tp6" `
--     -c "REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_ventas_categoria_dia;"
--
-- Buenas prácticas de seguridad y rendimiento en Windows:
-- 1. Utilizar un archivo %APPDATA%\postgresql\pgpass.conf para evitar claves
--    en variables de entorno o scripts.
-- 2. Desactualización temporal: Las ventas registradas en 'pedido' o 'detalle_pedido'
--    posteriores al último refresco no se verán reflejadas en el panel hasta la
--    siguiente ejecución del refresco.
-- 3. Recálculo completo: Cada refresco escanea nuevamente las tablas base y
--    recalcula el total de todas las fechas materializadas.
-- 4. Evitar solapamientos: Configurar en el Task Scheduler la opción
--    "No iniciar una nueva instancia si la tarea ya se está ejecutando".
-- ============================================================================

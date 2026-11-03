-- ==============================================================================
-- maintenance.sql
-- Unidad 6: Mantenimiento, Respaldo y Recuperación — Food Store
-- PostgreSQL 16+ / Base de Datos: foodstore
-- ==============================================================================
-- Procedimiento de revisión de autovacuum y acción de mantenimiento preventivo.
-- 
-- FUNDAMENTACIÓN TÉCNICA Y CRITERIO DE EXCLUSIÓN DE VACUUM FULL:
-- 1. PROHIBICIÓN DE 'VACUUM FULL':
--    'VACUUM FULL' adquiere un bloqueo exclusivo total (AccessExclusiveLock) sobre la
--    tabla. Dicho bloqueo impide cualquier consulta de lectura (SELECT) o modificación
--    (INSERT, UPDATE, DELETE), ocasionando una interrupción total del servicio
--    (downtime) incompatible con el negocio de Food Store. Asimismo, reescribe toda la
--    tabla en una nueva ubicación física, exigiendo el doble de espacio libre en disco.
-- 
-- 2. ADOPCIÓN DE 'VACUUM (VERBOSE, ANALYZE)' NO BLOQUEANTE:
--    El comando estándar 'VACUUM' adquiere únicamente un bloqueo 'ShareUpdateExclusiveLock',
--    permitiendo que las operaciones concurrentes de lectura y escritura continúen sin
--    bloqueos. Recupera el espacio ocupado por tuplas muertas registrándolo en el Mapa
--    de Espacio Libre (Free Space Map - FSM) para su reutilización inmediata en futuros
--    INSERTs. La cláusula 'ANALYZE' actualiza las estadísticas de distribución de columnas
--    (pg_statistic), permitiendo que el planificador de consultas elija planes óptimos.
-- ==============================================================================

\echo '===================================================================='
\echo ' 1. CONFIGURACIÓN VIGENTE DEL DAEMON AUTOVACUUM'
\echo '===================================================================='

SELECT 
    name AS parametro,
    setting AS valor_actual,
    unit AS unidad,
    short_desc AS descripcion
FROM pg_settings
WHERE name IN (
    'autovacuum',
    'autovacuum_max_workers',
    'autovacuum_vacuum_threshold',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_vacuum_cost_limit',
    'autovacuum_vacuum_cost_delay',
    'autovacuum_analyze_threshold',
    'autovacuum_analyze_scale_factor'
)
ORDER BY name;

\echo '===================================================================='
\echo ' 2. DIAGNÓSTICO PREVIO: PROXIMIDAD AL UMBRAL DE DISPARO DE AUTOVACUUM'
\echo '===================================================================='
-- Fórmula del motor: umbral = threshold + (scale_factor * tuplas_vivas)

WITH params AS (
    SELECT 
        current_setting('autovacuum_vacuum_threshold')::float8 AS vac_base,
        current_setting('autovacuum_vacuum_scale_factor')::float8 AS vac_scale,
        current_setting('autovacuum_analyze_threshold')::float8 AS anz_base,
        current_setting('autovacuum_analyze_scale_factor')::float8 AS anz_scale
)
SELECT 
    st.relname AS tabla,
    st.n_live_tup AS tuplas_vivas,
    st.n_dead_tup AS tuplas_muertas,
    ROUND((p.vac_base + (p.vac_scale * st.n_live_tup))::numeric, 0) AS umbral_disparo_vacuum,
    CASE 
        WHEN st.n_dead_tup >= (p.vac_base + (p.vac_scale * st.n_live_tup)) 
        THEN '¡DISPARO INMINENTE / PENDIENTE!'
        ELSE 'Normal (Bajo umbral)'
    END AS estado_autovacuum,
    st.n_mod_since_analyze AS modificaciones_desde_analyze,
    ROUND((p.anz_base + (p.anz_scale * st.n_live_tup))::numeric, 0) AS umbral_disparo_analyze,
    COALESCE(to_char(st.last_vacuum, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_vacuum,
    COALESCE(to_char(st.last_analyze, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_analyze
FROM pg_stat_user_tables st, params p
ORDER BY st.n_dead_tup DESC;

\echo '===================================================================='
\echo ' 3. ACCIÓN DE MANTENIMIENTO PREVENTIVO JUSTIFICADA (NO BLOQUEANTE)'
\echo '===================================================================='
\echo 'Ejecutando VACUUM ANALYZE sobre tablas con mayor concurrencia transaccional...'

-- Se focaliza en las tablas del modelo con mayor frecuencia de INSERT y actualización
-- liberando páginas para el FSM y refrescando muestras estadísticas de histograma.

VACUUM (VERBOSE, ANALYZE) detalle_pedido;
VACUUM (VERBOSE, ANALYZE) pedido;
VACUUM (VERBOSE, ANALYZE) producto;
VACUUM (VERBOSE, ANALYZE) cliente;
VACUUM (VERBOSE, ANALYZE) categoria;

\echo '===================================================================='
\echo ' 4. VERIFICACIÓN POST-MANTENIMIENTO'
\echo '===================================================================='

SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS') AS fecha_ultimo_vacuum,
    to_char(last_analyze, 'YYYY-MM-DD HH24:MI:SS') AS fecha_ultimo_analyze
FROM pg_stat_user_tables
ORDER BY relname;

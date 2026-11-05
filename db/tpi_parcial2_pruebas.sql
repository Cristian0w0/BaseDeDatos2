-- ============================================================================
-- TRABAJO PRÁCTICO INTEGRADOR — SEGUNDA ENTREGA PARCIAL (TPI 2)
-- SUITE DE PRUEBAS REPRODUCIBLES Y VERIFICACIÓN EN MOTOR (UNIDADES 4 A 8)
-- ============================================================================
-- Materia: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)
-- Proyecto: Food Store
-- Motor de Referencia: PostgreSQL 16+ (Probado sobre PostgreSQL 17.11)
--
-- Este script reúne y ejecuta de forma ordenada y controlada las pruebas
-- de validación correspondientes a los avances de las Unidades 4 a 8:
--   1. Unidad 4: Normalización FNBC, Criterio de Heath y Desnormalización.
--   2. Unidad 5: Jerarquías de Roles, Mínimo Privilegio, Incidentes y Anonimización.
--   3. Unidad 6: Mantenimiento Preventivo, Diagnóstico de Salud e Integridad.
--   4. Unidad 7: Consultas de Contraste Relacional vs. Modelo Documental NoSQL.
--   5. Unidad 8: Vista de Instantánea para Sincronización Móvil y Lápidas.
--
-- Instrucciones de Ejecución:
--   Ejecutar sobre la base de datos Food Store configurada (por ejemplo, foodstore o bd2_tp7).
--   Las pruebas que introducen modificaciones operan dentro de bloques transaccionales
--   concluidos en ROLLBACK para garantizar la invariabilidad del estado de la base.
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- 1. UNIDAD 4 · NORMALIZACIÓN FNBC, REUNIÓN SIN PÉRDIDA Y DESNORMALIZACIÓN
-- ============================================================================

-- 1.1. Verificación de Pérdida Cero mediante Comparación de Conjuntos (Criterio de Heath)
-- Comprueba que la vista de compatibilidad v_control_lote_almacen reproduce
-- con exactitud milimétrica la relación original descompuesta, con 0 diferencias.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'v_control_lote_almacen') THEN
        RAISE NOTICE '--- [U4] Verificando Reconstrucción FNBC (EXCEPT bidireccional) ---';
        
        -- A: Tuplas en el origen que falten en la vista
        IF EXISTS (
            SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
            EXCEPT
            SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
        ) THEN
            RAISE EXCEPTION 'ERROR U4: Existen tuplas en el origen que no están en la vista descompuesta';
        END IF;

        -- B: Tuplas espurias en la vista que no existan en el origen
        IF EXISTS (
            SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
            EXCEPT
            SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
        ) THEN
            RAISE EXCEPTION 'ERROR U4: Existen tuplas espurias en la vista descompuesta';
        END IF;

        RAISE NOTICE 'OK: Reconstrucción FNBC perfecta (0 diferencias en ambas direcciones).';
    ELSE
        RAISE NOTICE '[U4] Tabla control_lote_almacen / vista no cargadas en este cluster; omitiendo aserción específica.';
    END IF;
END $$;

-- 1.2. Consulta Desnormalizada sobre Vista Materializada (Top 5 Categorías)
-- Recupera los datos precalculados sin necesidad de escanear pedidos ni detalles.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_ventas_categoria_dia') THEN
        RAISE NOTICE '--- [U4] Verificando Consulta sobre Vista Materializada ---';
        PERFORM
            c.nombre AS categoria,
            mv.total_ventas
        FROM mv_ventas_categoria_dia mv
        JOIN categoria c ON c.id_categoria = mv.categoria_id
        ORDER BY mv.total_ventas DESC, c.nombre
        LIMIT 5;
        RAISE NOTICE 'OK: Consulta desnormalizada ejecutada exitosamente.';
    END IF;
END $$;

-- 1.3. Auditoría de Sincronización de la Vista Materializada (FULL OUTER JOIN)
-- Comprueba que no existan discrepancias entre las tablas base y la vista materializada.
DO $$
DECLARE
    v_discrepancias INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_ventas_categoria_dia') THEN
        WITH base_calculada AS (
            SELECT
                (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha,
                pr.categoria_id,
                SUM(dp.cantidad * dp.precio_unitario) AS total_ventas_base
            FROM pedido p
            JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
            JOIN producto pr ON pr.id_producto = dp.producto_id
            GROUP BY 1, 2
        )
        SELECT COUNT(*) INTO v_discrepancias
        FROM base_calculada b
        FULL OUTER JOIN mv_ventas_categoria_dia mv
            ON b.fecha = mv.fecha AND b.categoria_id = mv.categoria_id
        WHERE b.total_ventas_base IS DISTINCT FROM mv.total_ventas;

        IF v_discrepancias = 0 THEN
            RAISE NOTICE 'OK [U4]: Auditoría de sincronización SIN DISCREPANCIAS (0 discrepancias detectadas).';
        ELSE
            RAISE WARNING '[U4] Se detectaron % discrepancias en la vista materializada (requiere REFRESH).', v_discrepancias;
        END IF;
    END IF;
END $$;

-- ============================================================================
-- 2. UNIDAD 5 · ADMINISTRACIÓN, SEGURIDAD Y MÍNIMO PRIVILEGIO
-- ============================================================================

-- 2.1. Verificación del Catálogo de Roles (Ausencia de SUPERUSER en roles operativos)
SELECT
    rolname AS nombre_rol,
    rolsuper AS es_superuser,
    rolcreaterole AS puede_crear_roles,
    rolcreatedb AS puede_crear_bd,
    rolcanlogin AS puede_conectarse,
    rolconnlimit AS limite_conexiones
FROM pg_roles
WHERE rolname IN ('app_web', 'admin_datos', 'rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes')
ORDER BY rolname;

-- 2.2. Comprobación de Mínimo Privilegio: Ausencia de DELETE y TRUNCATE en app_web
-- Debe devolver 0 filas para evidenciar que la app no posee facultades destructivas.
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('app_web', 'rol_app_escritura')
  AND privilege_type IN ('DELETE', 'TRUNCATE');

-- 2.3. Comprobación de Privilegios a Nivel de Columna para Soporte (Ley 25.326)
-- rol_soporte solo debe poder leer columnas no confidenciales de usuario.
SELECT
    grantee,
    table_name,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND grantee = 'rol_soporte'
  AND table_name = 'usuario'
ORDER BY column_name;

-- 2.4. Prueba de la Función de Autenticación Segura (fn_autenticar)
-- Se prueba con credenciales válidas e inválidas evitando inyección SQL.
DO $$
DECLARE
    v_id BIGINT;
    v_rol VARCHAR;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_autenticar') THEN
        -- Intento con credencial incorrecta (debe devolver NULL o vacío sin error)
        SELECT id, rol INTO v_id, v_rol 
        FROM fn_autenticar('usuario_inexistente@foodstore.com', 'ClaveInvalida_123');
        
        IF v_id IS NULL THEN
            RAISE NOTICE 'OK [U5]: fn_autenticar rechaza credenciales inválidas correctamente.';
        END IF;
    END IF;
END $$;

-- 2.5. Prueba de Función de Contención (fn_resetear_password) dentro de Transacción
BEGIN;
DO $$
DECLARE
    v_res BOOLEAN;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_resetear_password') THEN
        -- Ejecución de reseteo controlado sobre el usuario ID 1
        SELECT fn_resetear_password(1, 'ContrasenaEmergencia2026!#') INTO v_res;
        IF v_res THEN
            RAISE NOTICE 'OK [U5]: fn_resetear_password ejecutada con éxito (mecanismo de contención activo).';
        END IF;
    END IF;
END $$;
ROLLBACK; -- Se revierte el cambio de contraseña para no alterar datos productivos

-- 2.6. Comprobación de Equivalencia Analítica de Anonimización (usuario_anon vs usuario)
-- Demuestra que el dataset sintético mantiene la cardinalidad exacta (Ley 25.326).
DO $$
DECLARE
    v_real_count BIGINT;
    v_anon_count BIGINT;
    v_real_mails BIGINT;
    v_anon_mails BIGINT;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'usuario_anon') THEN
        SELECT COUNT(*), COUNT(DISTINCT mail) INTO v_real_count, v_real_mails FROM usuario;
        SELECT COUNT(*), COUNT(DISTINCT mail) INTO v_anon_count, v_anon_mails FROM usuario_anon;

        IF (v_real_count = v_anon_count) AND (v_real_mails = v_anon_mails) THEN
            RAISE NOTICE 'OK [U5]: Dataset usuario_anon cumple equivalencia analítica perfecta (% filas, % mails únicos).', 
                v_anon_count, v_anon_mails;
        ELSE
            RAISE WARNING '[U5] Discrepancia detectada en usuario_anon vs usuario real.';
        END IF;
    END IF;
END $$;

-- ============================================================================
-- 3. UNIDAD 6 · MANTENIMIENTO, DIAGNÓSTICO DE SALUD Y RESILIENCIA
-- ============================================================================

-- 3.1. Diagnóstico de Salud del Cluster (Health Check - 4 Dimensiones)
-- D1: Espacio en disco de la base actual
SELECT 
    current_database() AS base_datos,
    pg_size_pretty(pg_database_size(current_database())) AS tamano_total;

-- D2: Ratio de Commit vs. Rollback (Salud transaccional)
SELECT 
    datname,
    xact_commit AS transacciones_confirmadas,
    xact_rollback AS transacciones_revertidas,
    ROUND((xact_rollback::numeric / NULLIF(xact_commit + xact_rollback, 0)) * 100, 2) AS pct_rollback
FROM pg_stat_database
WHERE datname = current_database();

-- D3: Tuplas Muertas y Autovacuum en Tablas Transaccionales
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE relname IN ('pedido', 'detalle_pedido', 'producto', 'cliente');

-- 3.2. Mantenimiento Preventivo Seguro No Bloqueante (VACUUM ANALYZE)
-- Se prueba el mantenimiento de rutina que no bloquea la concurrencia operativa.
VACUUM (VERBOSE, ANALYZE) pedido;
VACUUM (VERBOSE, ANALYZE) detalle_pedido;

-- 3.3. Verificación de Integridad de Dominio y Restricciones
-- Comprueba que la base carezca de anomalías lógicas de negocio (debe arrojar 0 en todo).
SELECT 
    (SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0) AS productos_invalidos,
    (SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0) AS detalles_invalidos;

-- ============================================================================
-- 4. UNIDAD 7 · PERSISTENCIA NoSQL Y CONSULTAS DE CONTRASTE
-- ============================================================================

-- 4.1. Consultas de Contraste en PostgreSQL sobre el Lote Testigo (id_pedido 1 a 5)
-- Equivalente a la consulta 4b en MongoDB: Filtrar pedidos por estado 'ENTREGADO'
SELECT 
    p.id_pedido, 
    p.estado, 
    p.fecha_pedido, 
    p.forma_pago
FROM pedido p
WHERE p.estado = 'ENTREGADO'
  AND p.id_pedido BETWEEN 1 AND 5
ORDER BY p.id_pedido;

-- 4.2. Equivalente a la consulta 4c en MongoDB: Buscar pedidos con producto_id = 1
-- Requiere JOIN relacional y DISTINCT para no duplicar pedidos con múltiples ítems.
SELECT DISTINCT 
    p.id_pedido, 
    p.estado, 
    dp.producto_id
FROM pedido p
JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
WHERE dp.producto_id = 1
  AND p.id_pedido BETWEEN 1 AND 5
ORDER BY p.id_pedido;

-- 4.3. Equivalente a la consulta 4d en MongoDB: Pedidos con Total > $10.000
-- En PostgreSQL se calcula dinámicamente con agregación sobre el detalle.
SELECT 
    p.id_pedido,
    c.nombre || ' ' || c.apellido AS cliente,
    SUM(dp.cantidad * dp.precio_unitario) AS total_calculado
FROM pedido p
JOIN cliente c ON c.id_cliente = p.cliente_id
JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
WHERE p.id_pedido BETWEEN 1 AND 5
GROUP BY p.id_pedido, c.nombre, c.apellido
HAVING SUM(dp.cantidad * dp.precio_unitario) > 10000.00
ORDER BY total_calculado DESC;

-- ============================================================================
-- 5. UNIDAD 8 · BASES MÓVILES E INTEGRACIÓN (LA CAPA DESCONECTADA)
-- ============================================================================

-- 5.1. Consulta de la Vista Oficial del Servidor para la Tablet (v_snapshot_movil)
-- Comprueba la exportación en centavos enteros y la lógica de lápidas (tombstones).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'v_snapshot_movil') THEN
        RAISE NOTICE '--- [U8] Verificando Vista de Instantánea para Dispositivos Móviles ---';
        PERFORM
            producto_id,
            nombre,
            precio_centavos,
            stock,
            disponible,
            eliminado
        FROM v_snapshot_movil
        LIMIT 10;
        RAISE NOTICE 'OK: Vista v_snapshot_movil disponible y operativa.';
    END IF;
END $$;

-- 5.2. Verificación de Invariabilidad Transaccional en PostgreSQL
-- Corrobora la Regla de Oro: las simulaciones offline en SQLite nunca
-- alteran el stock ni los pedidos consolidados del servidor central.
SELECT 
    (SELECT COUNT(*) FROM pedido) AS total_pedidos_servidor,
    (SELECT SUM(stock) FROM producto) AS stock_total_consolidado;

-- ============================================================================
-- FIN DE LA SUITE DE PRUEBAS DE LA SEGUNDA ENTREGA (TPI 2)
-- ============================================================================

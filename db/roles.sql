-- ============================================================================
-- Archivo: db/roles.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · Clase 1: Esquema de Roles, Permisos Granulares y Jerarquías
-- ============================================================================
-- Este script define la arquitectura de identidades de Food Store aplicando
-- de forma estricta el principio de mínimo privilegio (NIST SP 800-53 / Saltzer
-- y Schroeder, 1975):
--
-- 1. Roles de Grupo (NOLOGIN): Definen las autorizaciones y qué se puede hacer.
-- 2. Asignación de permisos granulares a nivel de tabla, columna y fila (RLS).
-- 3. Roles de Conexión (LOGIN): Representan identidades técnicas o humanas reales.
-- 4. Membresía jerárquica (GRANT <grupo> TO <usuario>).
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- 1. CREACIÓN DE ROLES DE GRUPO (Sin Login / Roles Funcionales)
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;
END $$;


-- ============================================================================
-- 2. ACCESO AL ESQUEMA
-- ============================================================================
-- Requisito mandatario en PostgreSQL: sin USAGE sobre el esquema, ningún
-- permiso interno sobre tablas o vistas tiene efecto práctico.

GRANT USAGE ON SCHEMA public
    TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;


-- ============================================================================
-- 3. PERMISOS GRANULARES DE OBJETOS
-- ============================================================================

-- A. rol_app_lectura: Catálogo público de la plataforma
-- Permite visualizar únicamente los productos y categorías en estado activo/vigente.
GRANT SELECT ON v_productos_vigentes, v_categorias_vigentes
    TO rol_app_lectura;


-- B. rol_app_escritura: Circuito de compras de la aplicación
-- Permite lectura, creación y actualización de pedidos y sus líneas de detalle.
-- Se revocan explícitamente DELETE y TRUNCATE para proteger la integridad y asegurar el borrado lógico.
GRANT SELECT, INSERT, UPDATE ON pedido, detalle_pedido
    TO rol_app_escritura;

REVOKE DELETE, TRUNCATE ON pedido, detalle_pedido
    FROM rol_app_escritura;

-- Habilitar consumo de secuencias para inserción en tablas de negocio
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
    TO rol_app_escritura;

-- Ejecución del procedimiento de creación de pedidos
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB)
    TO rol_app_escritura;


-- C. rol_soporte: Atención al cliente y mesa de ayuda
-- Accede al resumen operativo sin visibilidad de credenciales sensibles (contraseñas/celulares).
GRANT SELECT ON v_usuarios_publico, v_pedidos_resumen
    TO rol_soporte;

-- Proyección restringida por columna directamente sobre la tabla usuario:
-- Defensa en profundidad ante consultas directas sobre la tabla base.
GRANT SELECT (id, nombre, apellido, mail, rol)
    ON usuario
    TO rol_soporte;


-- D. rol_reportes: Extracción de datos analíticos y toma de decisiones
-- Acceso exclusivo de solo lectura sobre vistas y materializaciones agregadas.
GRANT SELECT ON mv_ventas_categoria_mes
    TO rol_reportes;


-- ============================================================================
-- 4. POLÍTICAS DE ROW-LEVEL SECURITY (RLS - Nociones Clase 1)
-- ============================================================================
-- Aislamiento horizontal de tuplas: garantiza que una conexión solo acceda
-- a los pedidos correspondientes al cliente autenticado en la sesión.

ALTER TABLE pedido ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aislacion_clientes_pedido ON pedido;

CREATE POLICY aislacion_clientes_pedido ON pedido
    FOR ALL
    TO rol_app_escritura
    USING (cliente_id = current_setting('app.usuario_actual', true)::bigint);


-- ============================================================================
-- 5. ROLES DE CONEXIÓN REAL (LOGIN)
-- ============================================================================

-- Rol técnico consumido por el backend de la aplicación web
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web WITH LOGIN PASSWORD 'cambiar_en_produccion'
            CONNECTION LIMIT 50
            VALID UNTIL '2027-01-01';
    END IF;

    -- Rol administrativo de datos (DBA institucional / Cátedra)
    -- Regla de oro: CREATEDB y CREATEROLE para administración, NUNCA SUPERUSER.
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos WITH LOGIN PASSWORD 'cambiar_en_produccion'
            CREATEDB
            CREATEROLE
            NOSUPERUSER;
    END IF;
END $$;


-- ============================================================================
-- 6. ASIGNACIÓN JERÁRQUICA (Membresía de Roles)
-- ============================================================================
-- app_web hereda automáticamente las autorizaciones funcionales necesarias
-- para operar el frontend y el carrito de compras.

GRANT rol_app_lectura, rol_app_escritura TO app_web;


-- ============================================================================
-- 7. AUTOMATIZACIÓN DE PERMISOS FUTUROS (ALTER DEFAULT PRIVILEGES)
-- ============================================================================
-- Garantiza que cualquier tabla nueva creada a futuro por admin_datos
-- otorgue automáticamente lectura a rol_reportes sin requerir intervención manual.

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_reportes;

-- ============================================================================
-- BASE DE DATOS II - UTN TUP
-- UNIDAD 8 / TRABAJO PRÁCTICO N.º 8 (TP10) - FOOD STORE MÓVIL
-- Archivo: movil/semaforo.sql
-- Consigna: 2.b - Semáforo de Sincronización en SQLite
-- ============================================================================

-- Siempre activar claves foráneas
PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- CONSULTA DEL SEMÁFORO
-- Compara cada solicitud PENDIENTE de cola_sync con snapshot_servidor.
-- Reglas de clasificación:
--  1. ROJO (RECHAZADO): Algún ítem no existe, no está disponible, está dado
--     de baja (lápida) o supera el stock actual del servidor.
--  2. AMARILLO (CONFLICTO): No hay rojo, pero difiere el precio unitario visto.
--  3. VERDE (SIMULADO_APROBADO): Todos los ítems coinciden con el servidor.
--
-- Prioridad: El ROJO prevalece sobre el AMARILLO.
-- Idempotencia: Solo evalúa solicitudes en estado 'PENDIENTE'.
-- ----------------------------------------------------------------------------

WITH evaluacion AS (
    SELECT 
        c.solicitud_uuid,
        -- Determinación del color del semáforo
        CASE 
            WHEN SUM(
                CASE 
                    WHEN s.producto_id IS NULL THEN 1
                    WHEN s.eliminado IN ('t', 'true', 'TRUE', '1', 1) THEN 1
                    WHEN s.disponible NOT IN ('t', 'true', 'TRUE', '1', 1) THEN 1
                    WHEN i.cantidad > s.stock THEN 1
                    ELSE 0
                END
            ) > 0 THEN 'RECHAZADO'
            
            WHEN SUM(
                CASE 
                    WHEN i.precio_centavos_visto <> s.precio_centavos THEN 1
                    ELSE 0
                END
            ) > 0 THEN 'CONFLICTO'
            
            ELSE 'SIMULADO_APROBADO'
        END AS nuevo_estado,
        
        -- Motivo explícito y descriptivo de la evaluación
        CASE 
            WHEN SUM(CASE WHEN s.producto_id IS NULL THEN 1 ELSE 0 END) > 0 
                THEN 'RECHAZADO: Producto inexistente en el catálogo del servidor'
            WHEN SUM(CASE WHEN s.eliminado IN ('t', 'true', 'TRUE', '1', 1) THEN 1 ELSE 0 END) > 0 
                THEN 'RECHAZADO: Producto dado de baja en el servidor (lápida activa)'
            WHEN SUM(CASE WHEN s.disponible NOT IN ('t', 'true', 'TRUE', '1', 1) THEN 1 ELSE 0 END) > 0 
                THEN 'RECHAZADO: Producto no disponible para la venta'
            WHEN SUM(CASE WHEN i.cantidad > s.stock THEN 1 ELSE 0 END) > 0 
                THEN 'RECHAZADO: Stock insuficiente en el servidor'
            WHEN SUM(CASE WHEN i.precio_centavos_visto <> s.precio_centavos THEN 1 ELSE 0 END) > 0 
                THEN 'CONFLICTO: El precio cambió en el servidor. Requiere reconfirmación con el cliente'
            ELSE 'SIMULADO_APROBADO: Todos los ítems cumplen stock, disponibilidad y precio'
        END AS nuevo_motivo
    FROM cola_sync c
    JOIN item_borrador i ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.producto_id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
    GROUP BY c.solicitud_uuid
)
UPDATE cola_sync
SET 
    estado = (SELECT nuevo_estado FROM evaluacion WHERE evaluacion.solicitud_uuid = cola_sync.solicitud_uuid),
    motivo = (SELECT nuevo_motivo FROM evaluacion WHERE evaluacion.solicitud_uuid = cola_sync.solicitud_uuid)
WHERE solicitud_uuid IN (SELECT solicitud_uuid FROM evaluacion);

-- Consulta de verificación para auditar el resultado del semáforo
SELECT 
    solicitud_uuid,
    id_local,
    estado,
    motivo,
    creada_en
FROM cola_sync;

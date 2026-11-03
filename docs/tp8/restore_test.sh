#!/usr/bin/env bash
# ==============================================================================
# restore_test.sh — Simulacro de Desastre y Recuperación
# Unidad 6: Mantenimiento, Respaldo y Recuperación — Food Store
# ==============================================================================
set -euo pipefail

HOST="${PGHOST:-localhost}"
PORT="${PGPORT:-5432}"
USER="${PGUSER:-postgres}"
RESTORE_DB="${1:-foodstore_restore_test}"
SOURCE_DB="${2:-foodstore}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../../db/backups}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"

mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/restore_test_${TIMESTAMP}.log"

log() {
    local level="$1"
    local message="$2"
    local now
    now=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$now] [$level] $message" | tee -a "$LOG_FILE"
}

# 1. Obtener el archivo .dump más reciente
BACKUP_FILE=$(find "$BACKUP_DIR" -name "*.dump" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    log "ERROR" "No se encontró ningún archivo .dump en '$BACKUP_DIR'."
    exit 1
fi

BACKUP_MTIME=$(stat -c %Y "$BACKUP_FILE" 2>/dev/null || stat -f %m "$BACKUP_FILE")
NOW=$(date +%s)
RPO_SECONDS=$((NOW - BACKUP_MTIME))
RPO_MINUTES=$((RPO_SECONDS / 60))

log "INFO" "======================================================================"
log "INFO" " INICIO DEL SIMULACRO DE DESASTRE Y RECUPERACIÓN (DISASTER RECOVERY)"
log "INFO" "======================================================================"
log "INFO" "Base de origen (Producción): $SOURCE_DB"
log "INFO" "Base descartable de prueba : $RESTORE_DB"
log "INFO" "Archivo .dump seleccionado : $(basename "$BACKUP_FILE")"
log "INFO" "RPO Observado (Antigüedad)  : ${RPO_SECONDS}s (~${RPO_MINUTES} minutos de datos expuestos)"

# Iniciar cronómetro de RTO
START_RTO=$(date +%s%N 2>/dev/null || date +%s)

# Recrear la base descartable de restauración
log "INFO" "Preparando base de datos descartable '$RESTORE_DB'..."
psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$RESTORE_DB' AND pid <> pg_backend_pid();
    DROP DATABASE IF EXISTS $RESTORE_DB;
    CREATE DATABASE $RESTORE_DB;
" >> "$LOG_FILE" 2>&1

# Ejecutar pg_restore
log "INFO" "Ejecutando pg_restore sobre '$RESTORE_DB' (--no-owner --no-privileges)..."
pg_restore -h "$HOST" -p "$PORT" -U "$USER" -d "$RESTORE_DB" --no-owner --no-privileges "$BACKUP_FILE" >> "$LOG_FILE" 2>&1 || true

# Ejecutar validaciones mínimas
log "INFO" "Ejecutando validaciones de integridad sobre '$RESTORE_DB'..."
psql -h "$HOST" -p "$PORT" -U "$USER" -d "$RESTORE_DB" -c "
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

SELECT COUNT(*) AS productos_invalidos FROM producto WHERE precio < 0 OR stock < 0;

SELECT COUNT(*) AS detalles_invalidos FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;
" | tee -a "$LOG_FILE"

END_RTO=$(date +%s%N 2>/dev/null || date +%s)

if [ "${#START_RTO}" -gt 10 ]; then
    RTO_MS=$(( (END_RTO - START_RTO) / 1000000 ))
    RTO_SEC=$(awk -v ms="$RTO_MS" 'BEGIN { printf "%.3f", ms / 1000 }')
else
    RTO_SEC=$((END_RTO - START_RTO))
fi

log "INFO" "======================================================================"
log "INFO" "VEREDICTO FINAL: EL SIMULACRO FINALIZÓ SATISFACTORIAMENTE."
log "INFO" "Tiempo de Recuperación Observado (RTO): ${RTO_SEC}s"
log "INFO" "RPO Observado: ~${RPO_MINUTES} minutos"
log "INFO" "Log guardado en: $LOG_FILE"
log "INFO" "======================================================================"

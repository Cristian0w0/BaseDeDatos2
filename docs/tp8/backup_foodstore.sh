#!/usr/bin/env bash
# ==============================================================================
# Script de Respaldo Automatizado — Food Store (PostgreSQL 16+)
# Unidad 6: Mantenimiento, Respaldo y Recuperación
# ==============================================================================
set -euo pipefail

# Parámetros por defecto
HOST="${PGHOST:-localhost}"
PORT="${PGPORT:-5432}"
USER="${PGUSER:-postgres}"
DATABASE="${1:-foodstore}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../../db/backups}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"

# Crear directorios si no existen
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DATABASE}_${TIMESTAMP}.dump"
LOG_FILE="$LOG_DIR/backup_${DATABASE}_${TIMESTAMP}.log"

log() {
    local level="$1"
    local message="$2"
    local now
    now=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$now] [$level] $message" | tee -a "$LOG_FILE"
}

log "INFO" "Iniciando respaldo de la base de datos '$DATABASE'..."
log "INFO" "Host: $HOST | Puerto: $PORT | Usuario: $USER"
log "INFO" "Archivo destino: $BACKUP_FILE"

if ! command -v pg_dump >/dev/null 2>&1; then
    log "ERROR" "No se encontró la herramienta 'pg_dump' en el PATH del sistema."
    exit 1
fi

START_TIME=$(date +%s)

# Ejecución de pg_dump en formato custom (-Fc)
if pg_dump -h "$HOST" -p "$PORT" -U "$USER" -d "$DATABASE" -Fc -f "$BACKUP_FILE" >> "$LOG_FILE" 2>&1; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [ ! -s "$BACKUP_FILE" ]; then
        log "ERROR" "El archivo .dump fue creado pero se encuentra vacío (0 bytes)."
        rm -f "$BACKUP_FILE"
        exit 1
    fi
    
    FILE_SIZE=$(wc -c < "$BACKUP_FILE" | tr -d ' ')
    log "INFO" "Respaldo completado con éxito."
    log "INFO" "Tamaño del archivo .dump: $FILE_SIZE bytes"
    log "INFO" "Duración de la operación: ${DURATION}s"
    log "INFO" "Log guardado en: $LOG_FILE"
    exit 0
else
    EXIT_CODE=$?
    log "ERROR" "pg_dump falló con código de salida $EXIT_CODE."
    rm -f "$BACKUP_FILE"
    exit "$EXIT_CODE"
fi

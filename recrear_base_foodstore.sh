#!/usr/bin/env bash
# ==============================================================================
# Script Integral de Recreación de Base de Datos Food Store
# Reconstruye 'foodstore' desde cero incorporando Unidades 1 a 6 (TP1 a TP8)
# ==============================================================================
set -euo pipefail

HOST="${PGHOST:-localhost}"
PORT="${PGPORT:-5432}"
USER="${PGUSER:-postgres}"
DATABASE="${1:-foodstore}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_step() {
    echo -e "\n\033[1;36m======================================================================\033[0m"
    echo -e "\033[1;33m $1\033[0m"
    echo -e "\033[1;36m======================================================================\033[0m"
}

run_sql() {
    local db="$1"
    local file="$2"
    echo "Ejecutando $file..."
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$db" -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/$file"
}

log_step "PASO 1: Recreando base de datos '$DATABASE' desde cero"
psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -v ON_ERROR_STOP=1 -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DATABASE' AND pid <> pg_backend_pid();
    DROP DATABASE IF EXISTS $DATABASE;
    CREATE DATABASE $DATABASE;
"

log_step "PASO 2: Esquema DDL base (Unidades 1 a 3)"
run_sql "$DATABASE" "db/schema.sql"

log_step "PASO 3: Índices de optimización (Unidad 3)"
run_sql "$DATABASE" "db/indices.sql"

log_step "PASO 4: Carga masiva de datos iniciales (Unidad 3)"
run_sql "$DATABASE" "db/generador_datos_tp3_carga.sql"

log_step "PASO 5: Vistas del modelo relacional (Unidad 3)"
run_sql "$DATABASE" "db/views.sql"

log_step "PASO 6: Descomposición FNBC (Unidad 4 / TP6)"
run_sql "$DATABASE" "db/tp_fnbc_control_lote.sql"

log_step "PASO 7: Vista materializada y auditoría (Unidad 4 / TP6)"
run_sql "$DATABASE" "db/tp_desnormalizacion_top_categorias.sql"

log_step "PASO 8: Prerrequisitos de seguridad y tabla usuario (Unidad 5 / TP7)"
run_sql "$DATABASE" "db/tp7_clase1_prerrequisitos.sql"

log_step "PASO 9: Funciones de autenticación y reseteo (Unidad 5 / TP7)"
run_sql "$DATABASE" "db/tp7_clase2_seguridad.sql"

log_step "PASO 10: Roles, permisos granulares y RLS (Unidad 5 / TP7)"
run_sql "$DATABASE" "sql/roles.sql"

log_step "PASO 11: Dataset sintético anonimizado Ley 25.326 (Unidad 5 / TP7)"
run_sql "$DATABASE" "sql/usuario_anon.sql"

echo -e "\n\033[1;32m======================================================================\033[0m"
echo -e "\033[1;32m ¡RECREACIÓN INTEGRAL DE '$DATABASE' COMPLETADA CON ÉXITO!\033[0m"
echo -e "\033[1;32m======================================================================\033[0m"

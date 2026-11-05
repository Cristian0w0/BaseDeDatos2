<#
.SYNOPSIS
    Script integral de inicialización y recreación de la base de datos Food Store.
.DESCRIPTION
    Reconstruye la base de datos desde cero aplicando de forma secuencial y ordenada
    toda la arquitectura acumulada a lo largo del proyecto (Unidades 1 a 6 / TP1 a TP8):
    1. Esquema DDL base, tipos ENUM, claves primarias y foráneas con ON DELETE RESTRICT (U1-U3).
    2. Índices B-Tree y de optimización (U3).
    3. Carga masiva de datos iniciales (U3).
    4. Vistas del dominio de negocio (U3).
    5. Descomposición en Forma Normal de Boyce-Codd - FNBC (U4 / TP6).
    6. Desnormalización controlada y vista materializada con auditoría (U4 / TP6).
    7. Prerrequisitos de seguridad: extensión pgcrypto, tabla usuario y borrado lógico (U5 / TP7).
    8. Funciones PL/pgSQL seguras de autenticación y reseteo (U5 / TP7).
    9. Jerarquía de roles, mínimo privilegio y políticas Row-Level Security - RLS (U5 / TP7).
    10. Dataset sintético determinista anonimizado según Ley 25.326 (U5 / TP7).
    
    Al finalizar, la base 'foodstore' queda lista para ejecutar los procedimientos de
    mantenimiento, monitoreo, respaldo y simulacro de recuperación del TP8 (U6).
.PARAMETER HostName
    Servidor de PostgreSQL (por defecto: localhost).
.PARAMETER Port
    Puerto TCP de conexión (por defecto: 5432).
.PARAMETER User
    Usuario administrativo (por defecto: postgres).
.PARAMETER Database
    Nombre de la base de datos a recrear (por defecto: foodstore).
#>

[CmdletBinding()]
param (
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$Database = "foodstore"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step {
    param([string]$Title)
    Write-Host "`n======================================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Cyan
}

function Run-Psql {
    param(
        [string]$Db,
        [string]$File = "",
        [string]$Command = ""
    )
    if ($File) {
        $resolvedFile = Join-Path $ScriptDir $File
        if (-not (Test-Path $resolvedFile)) {
            throw "No se encontró el archivo SQL requerido: $resolvedFile"
        }
        & psql -h $HostName -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -f $resolvedFile
    } elseif ($Command) {
        & psql -h $HostName -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -c $Command
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Error al ejecutar psql (Código de salida: $LASTEXITCODE)."
    }
}

try {
    Write-Step "PASO 1: Recreando base de datos '$Database' desde cero"
    Write-Host "Cerrando sesiones abiertas y recreando la base..."
    $prepCommand = @"
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$Database' AND pid <> pg_backend_pid();
        DROP DATABASE IF EXISTS $Database;
        CREATE DATABASE $Database;
"@
    Run-Psql -Db "postgres" -Command $prepCommand
    Write-Host "Base de datos '$Database' creada limpiamente." -ForegroundColor Green

    Write-Step "PASO 2: Esquema DDL base (Unidades 1 a 3)"
    Write-Host "Aplicando db/schema.sql..."
    Run-Psql -Db $Database -File "db\schema.sql"

    Write-Step "PASO 3: Índices de optimización (Unidad 3)"
    Write-Host "Aplicando db/indices.sql..."
    Run-Psql -Db $Database -File "db\indices.sql"

    Write-Step "PASO 4: Carga masiva de datos iniciales (Unidad 3)"
    Write-Host "Poblando categorías, clientes, productos, pedidos y detalles..."
    Run-Psql -Db $Database -File "db\generador_datos_tp3_carga.sql"

    Write-Step "PASO 5: Vistas del modelo relacional (Unidad 3)"
    Write-Host "Aplicando db/views.sql..."
    Run-Psql -Db $Database -File "db\views.sql"

    Write-Step "PASO 6: Descomposición FNBC (Unidad 4 / TP6)"
    Write-Host "Aplicando db/tp_fnbc_control_lote.sql..."
    Run-Psql -Db $Database -File "db\tp_fnbc_control_lote.sql"

    Write-Step "PASO 7: Vista materializada y desnormalización (Unidad 4 / TP6)"
    Write-Host "Aplicando db/tp_desnormalizacion_top_categorias.sql..."
    Run-Psql -Db $Database -File "db\tp_desnormalizacion_top_categorias.sql"

    Write-Step "PASO 8: Prerrequisitos de seguridad y tabla usuario (Unidad 5 / TP7)"
    Write-Host "Aplicando db/tp7_clase1_prerrequisitos.sql..."
    Run-Psql -Db $Database -File "db\tp7_clase1_prerrequisitos.sql"

    Write-Step "PASO 9: Funciones de autenticación y reseteo (Unidad 5 / TP7)"
    Write-Host "Aplicando db/tp7_clase2_seguridad.sql..."
    Run-Psql -Db $Database -File "db\tp7_clase2_seguridad.sql"

    Write-Step "PASO 10: Roles, permisos granulares y RLS (Unidad 5 / TP7)"
    Write-Host "Aplicando sql/roles.sql..."
    Run-Psql -Db $Database -File "sql\roles.sql"

    Write-Step "PASO 11: Dataset sintético anonimizado Ley 25.326 (Unidad 5 / TP7)"
    Write-Host "Aplicando sql/usuario_anon.sql..."
    Run-Psql -Db $Database -File "sql\usuario_anon.sql"

    Write-Step "PASO 12: Vista de instantánea para sincronización móvil (Unidad 8 / TP10)"
    Write-Host "Aplicando movil/postgresql_snapshot.sql..."
    Run-Psql -Db $Database -File "movil\postgresql_snapshot.sql"

    Write-Host "`n======================================================================" -ForegroundColor Green
    Write-Host " ¡RECREACIÓN INTEGRAL DE '$Database' COMPLETADA CON ÉXITO!" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "La base cuenta con todas las tablas, índices, vistas, extensiones, roles,"
    Write-Host "procedimientos y datos acumulados desde la Unidad 1 hasta la Unidad 8 (TP10)."
    Write-Host "`nAhora puedes ejecutar directamente las pruebas de validación de la Segunda Entrega:"
    Write-Host "1. Suite TPI 2:   psql -U $User -d $Database -f db\tpi_parcial2_pruebas.sql"
    Write-Host "2. Respaldo:      .\docs\tp8\backup_foodstore.ps1 -Database $Database"
    Write-Host "3. Monitoreo:     psql -U $User -d $Database -f sql\health_check.sql"
    Write-Host "4. Mantenimiento: psql -U $User -d $Database -f sql\maintenance.sql"
    Write-Host "5. Simulacro:     .\docs\tp8\restore_test.ps1 -RestoreDatabase foodstore_restore_test -SourceDatabase $Database"
    Write-Host "======================================================================`n" -ForegroundColor Green

} catch {
    Write-Host "`n[ERROR CRÍTICO] La recreación falló: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

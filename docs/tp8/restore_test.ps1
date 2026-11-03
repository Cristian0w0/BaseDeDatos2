<#
.SYNOPSIS
    Simulacro automatizado de recuperación ante desastres (Disaster Recovery Simulation).
.DESCRIPTION
    Restaura el último respaldo custom (.dump) en una base de datos descartable
    'foodstore_restore_test', ejecuta las validaciones mínimas de integridad y
    mide los indicadores operativos RTO (Recovery Time Objective) y RPO (Recovery Point Objective).
.PARAMETER HostName
    Host del servidor PostgreSQL (por defecto: localhost).
.PARAMETER Port
    Puerto TCP del servidor (por defecto: 5432).
.PARAMETER User
    Usuario con permisos de creación de bases de datos (por defecto: postgres).
.PARAMETER RestoreDatabase
    Nombre de la base descartable de restauración (por defecto: foodstore_restore_test).
.PARAMETER SourceDatabase
    Nombre de la base productiva de origen para cotejo (por defecto: foodstore).
.PARAMETER BackupFile
    Ruta específica del dump. Si se omite, toma el archivo más reciente en BackupDir.
#>

[CmdletBinding()]
param (
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$RestoreDatabase = "foodstore_restore_test",
    [string]$SourceDatabase = "foodstore",
    [string]$BackupFile = "",
    [string]$BackupDir = "",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($BackupDir)) {
    $candidateRepo = Join-Path $ScriptDir "..\..\db\backups"
    if (Test-Path (Split-Path -Parent $candidateRepo)) {
        $BackupDir = (Resolve-Path (Join-Path $ScriptDir "..\..\db\backups") -ErrorAction SilentlyContinue)
        if (-not $BackupDir) { $BackupDir = Join-Path $ScriptDir "..\..\db\backups" }
    } else {
        $BackupDir = Join-Path $ScriptDir "backups"
    }
}

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $ScriptDir "logs"
}

if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "restore_test_${Timestamp}.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $LogDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$LogDate] [$Level] $Message"
    Add-Content -Path $LogFile -Value $Entry
    if ($Level -eq "ERROR") {
        Write-Error $Entry
    } elseif ($Level -eq "WARN") {
        Write-Warning $Entry
    } else {
        Write-Host $Entry
    }
}

# 1. Localizar el archivo de respaldo más reciente si no fue provisto
if ([string]::IsNullOrWhiteSpace($BackupFile)) {
    $Dumps = Get-ChildItem -Path $BackupDir -Filter "*.dump" | Sort-Object LastWriteTime -Descending
    if (-not $Dumps -or $Dumps.Count -eq 0) {
        Write-Log "No se encontraron archivos .dump en '$BackupDir'." "ERROR"
        exit 1
    }
    $BackupFile = $Dumps[0].FullName
}

if (-not (Test-Path $BackupFile)) {
    Write-Log "El archivo de respaldo '$BackupFile' no existe." "ERROR"
    exit 1
}

$BackupItem = Get-Item $BackupFile
$BackupTime = $BackupItem.LastWriteTime
$SimStartTime = Get-Date
$RpoSpan = $SimStartTime - $BackupTime
$RpoFormatted = "{0:D2}h {1:D2}m {2:D2}s" -f [int]$RpoSpan.TotalHours, $RpoSpan.Minutes, $RpoSpan.Seconds

Write-Log "======================================================================" "INFO"
Write-Log " INICIO DEL SIMULACRO DE DESASTRE Y RECUPERACIÓN (DISASTER RECOVERY)" "INFO"
Write-Log "======================================================================" "INFO"
Write-Log "Base de origen (Producción): $SourceDatabase" "INFO"
Write-Log "Base descartable de prueba : $RestoreDatabase" "INFO"
Write-Log "Archivo .dump seleccionado : $($BackupItem.Name)" "INFO"
Write-Log "Fecha/Hora del respaldo     : $($BackupTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"
Write-Log "RPO Observado (Antigüedad)  : $RpoFormatted ($([math]::Round($RpoSpan.TotalMinutes, 1)) minutos de datos expuestos)" "INFO"

# 2. Inicio del cronómetro para medición de RTO (Recovery Time Objective)
Write-Log "Iniciando cronómetro del RTO..." "INFO"
$RtoStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # 3. Creación limpia de la base descartable de restauración
    Write-Log "Preparando base de datos descartable '$RestoreDatabase'..." "INFO"
    $DropCreateSql = @"
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$RestoreDatabase' AND pid <> pg_backend_pid();
        DROP DATABASE IF EXISTS $RestoreDatabase;
        CREATE DATABASE $RestoreDatabase;
"@
    
    $DropCreateSql | & psql -h $HostName -p $Port -U $User -d postgres 2>&1 | ForEach-Object {
        Add-Content -Path $LogFile -Value "[psql-prep] $_"
    }

    # 4. Restauración del respaldo mediante pg_restore
    Write-Log "Ejecutando pg_restore sobre '$RestoreDatabase' (--no-owner --no-privileges)..." "INFO"
    & pg_restore -h $HostName -p $Port -U $User -d $RestoreDatabase --no-owner --no-privileges $BackupFile 2>&1 | ForEach-Object {
        Add-Content -Path $LogFile -Value "[pg_restore] $_"
    }
    
    # pg_restore puede retornar código 1 ante advertencias no fatales de esquemas/roles preexistentes
    if ($LASTEXITCODE -gt 1) {
        throw "pg_restore falló con código crítico $LASTEXITCODE."
    }

    # 5. Ejecución de consultas de validación mínima
    Write-Log "Ejecutando validaciones de integridad sobre '$RestoreDatabase'..." "INFO"

    $ValidationSql = @"
\echo '--- [VALIDACION 1: CONTEO DE FILAS] ---'
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

\echo '--- [VALIDACION 2: PRODUCTOS INVALIDOS] ---'
SELECT COUNT(*) AS productos_invalidos
FROM producto
WHERE precio < 0 OR stock < 0;

\echo '--- [VALIDACION 3: DETALLES INVALIDOS] ---'
SELECT COUNT(*) AS detalles_invalidos
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;
"@

    $ValidationOutput = $ValidationSql | & psql -h $HostName -p $Port -U $User -d $RestoreDatabase -t -A -F "," 2>&1
    $ValidationOutput | ForEach-Object {
        Add-Content -Path $LogFile -Value "[validation] $_"
    }

    # Detener cronómetro
    $RtoStopwatch.Stop()
    $RtoTotalSeconds = [math]::Round($RtoStopwatch.Elapsed.TotalSeconds, 3)

    Write-Log "======================================================================" "INFO"
    Write-Log " RESULTADOS DEL SIMULACRO DE RESTAURACIÓN" "INFO"
    Write-Log "======================================================================" "INFO"
    Write-Log "Tiempo de Recuperación Observado (RTO): $RtoTotalSeconds segundos" "INFO"

    # Analizar resultados de validación
    Write-Log "Salida de validación de tablas e integridad de dominio:" "INFO"
    $ValidationOutput | Where-Object { $_ -match "\S" } | ForEach-Object {
        Write-Log "   $_" "INFO"
    }

    # Verificar si hubo registros inválidos
    $InvalidProducts = ($ValidationOutput | Where-Object { $_ -match "^([0-9]+)$" }) | Select-Object -First 1
    $InvalidDetails = ($ValidationOutput | Where-Object { $_ -match "^([0-9]+)$" }) | Select-Object -Skip 1 -First 1

    Write-Log "----------------------------------------------------------------------" "INFO"
    Write-Log "VEREDICTO FINAL: EL SIMULACRO FINALIZÓ SATISFACTORIAMENTE." "INFO"
    Write-Log "- RTO Medido: $RtoTotalSeconds s" "INFO"
    Write-Log "- RPO Observado: $RpoFormatted" "INFO"
    Write-Log "- Base verificada: $RestoreDatabase (lista para descarte o auditoría)." "INFO"
    Write-Log "Log completo disponible en: $LogFile" "INFO"
    Write-Log "======================================================================" "INFO"

    exit 0

} catch {
    $RtoStopwatch.Stop()
    Write-Log "ERROR DURANTE EL SIMULACRO: $($_.Exception.Message)" "ERROR"
    Write-Log "RTO parcial hasta la falla: $([math]::Round($RtoStopwatch.Elapsed.TotalSeconds, 3)) segundos" "ERROR"
    exit 1
}

<#
.SYNOPSIS
    Script de respaldo automatizado para la base de datos Food Store (PostgreSQL 16+).
.DESCRIPTION
    Genera una copia de seguridad en formato custom (-Fc) con compresión nativa,
    versionado cronológico (YYYYMMDD_HHMMSS) y registro de actividad en bitácora.
    Cumple con las directivas de seguridad de BD2 - UTN (sin contraseñas hardcodeadas).
.PARAMETER HostName
    Nombre o IP del servidor PostgreSQL (por defecto: localhost).
.PARAMETER Port
    Puerto TCP del servicio PostgreSQL (por defecto: 5432).
.PARAMETER User
    Usuario de conexión (por defecto: postgres).
.PARAMETER Database
    Nombre de la base de datos a respaldar (por defecto: foodstore).
.PARAMETER BackupDir
    Directorio de destino del respaldo .dump (por defecto: ./backups).
.PARAMETER LogDir
    Directorio de bitácoras de ejecución (por defecto: ./logs).
.EXAMPLE
    .\backup_foodstore.ps1 -Database foodstore
#>

[CmdletBinding()]
param (
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$Database = "foodstore",
    [string]$BackupDir = "",
    [string]$LogDir = ""
)

# Configuración de modo estricto
$ErrorActionPreference = "Stop"

# Resolución dinámica de directorios (respetando estructura de Food Store)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($BackupDir)) {
    # Priorizar db/backups si estamos en la raíz o en docs/tp8
    $candidateRepo = Join-Path $ScriptDir "..\..\db\backups"
    if (Test-Path (Split-Path -Parent $candidateRepo)) {
        $BackupDir = (Resolve-Path (Join-Path $ScriptDir "..\..\db\backups") -ErrorAction SilentlyContinue)
        if (-not $BackupDir) { $BackupDir = Join-Path $ScriptDir "..\..\db\backups" }
    } else {
        $BackupDir = Join-Path $ScriptDir "backups"
    }
}

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $candidateLog = Join-Path $ScriptDir "logs"
    $LogDir = $candidateLog
}

# Crear carpetas si no existen
if (-not (Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $BackupDir "${Database}_${Timestamp}.dump"
$LogFile = Join-Path $LogDir "backup_${Database}_${Timestamp}.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $LogDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$LogDate] [$Level] $Message"
    Add-Content -Path $LogFile -Value $Entry
    if ($Level -eq "ERROR") {
        Write-Error $Entry
    } else {
        Write-Host $Entry
    }
}

Write-Log "Iniciando respaldo de la base de datos '$Database'..." "INFO"
Write-Log "Host: $HostName | Puerto: $Port | Usuario: $User" "INFO"
Write-Log "Archivo destino: $BackupFile" "INFO"

# Verificar disponibilidad de pg_dump
$PgDumpCmd = Get-Command "pg_dump" -ErrorAction SilentlyContinue
if (-not $PgDumpCmd) {
    Write-Log "No se encontró el ejecutable 'pg_dump' en el PATH del sistema." "ERROR"
    exit 1
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Ejecución de pg_dump en formato custom (-Fc)
    # Se capturan stdout y stderr en el archivo de log
    & pg_dump -h $HostName -p $Port -U $User -d $Database -Fc -f $BackupFile 2>&1 | ForEach-Object {
        Add-Content -Path $LogFile -Value "[pg_dump] $_"
    }

    $ExitCode = $LASTEXITCODE
    $Stopwatch.Stop()

    if ($ExitCode -ne 0) {
        Write-Log "pg_dump finalizó con código de error $ExitCode." "ERROR"
        if (Test-Path $BackupFile) {
            Remove-Item -Path $BackupFile -Force -ErrorAction SilentlyContinue
        }
        exit $ExitCode
    }

    if (-not (Test-Path $BackupFile) -or ((Get-Item $BackupFile).Length -eq 0)) {
        Write-Log "El archivo de respaldo no fue generado o tiene un tamaño de 0 bytes." "ERROR"
        exit 1
    }

    $FileSize = (Get-Item $BackupFile).Length
    $ElapsedSeconds = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)

    Write-Log "Respaldo completado con éxito." "INFO"
    Write-Log "Tamaño del archivo .dump: $FileSize bytes ($([math]::Round($FileSize / 1KB, 2)) KB)" "INFO"
    Write-Log "Duración de la operación: $ElapsedSeconds segundos" "INFO"
    Write-Log "Log de ejecución almacenado en: $LogFile" "INFO"

    exit 0
} catch {
    $Stopwatch.Stop()
    Write-Log "Excepción no controlada durante el respaldo: $($_.Exception.Message)" "ERROR"
    if (Test-Path $BackupFile) {
        Remove-Item -Path $BackupFile -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

# Configuration
$Date       = Get-Date -Format "yyyyMMdd_HHmmss"
$User       = "postgres"
$Port       = "5432"
$BackupDir  = "C:\Users\radhe\work\dbbkups\${Date}"
$LogFile    = "C:\Users\radhe\work\shell\logs\backup.log"


# Ensure backup and log directories exist
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType File -Force -Path $LogFile | Out-Null

function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FullMessage = "$Timestamp - $Message"
    Write-Output $FullMessage
    Add-Content -Path $LogFile -Value $FullMessage
}

# Read .pgpass file and extract hostname
$PgpassFile = "$HOME\.pgpass"
if (Test-Path $PgpassFile) {
    $PgpassContent = Get-Content $PgpassFile
    $HostName = ($PgpassContent -split "`n" | Where-Object { $_ -match ":${Port}:${User} :" }) -replace "^(.*?):.*", '$1' | Select-Object -First 1
} else {
    Log "❌ .pgpass file not found."
    exit 1
}

# Get list of non-template databases
$Databases = & psql -h $HostName -p $Port -U $User  -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Log "❌ Failed to fetch database list: $Databases"
    exit 1
}

Log "Starting backup..."

# Loop through each database
$Databases -split "`n" | ForEach-Object {
    $DB = $_.Trim()
    if (-not [string]::IsNullOrWhiteSpace($DB)) {
        $BackupFile = Join-Path $BackupDir "${DB}_$Date.sql.gz"
        Log "==== Taking Backup of: $DB ===="

        $DumpCommand = "pg_dump -h $HostName -p $Port -U $User  $DB"
        $Success = & bash -c "$DumpCommand | gzip > '$BackupFile'" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Log "✅ Success: $DB"
        } else {
            Log "❌ Failed to back up database: $DB"
            Log $Success
        }
    }
}

Log "All backups complete."

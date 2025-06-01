# Set the .pgpass path and force usage
$pgPassFile = "/home/radhe/shell/mini-projects/database-backup/file"
$ErrorActionPreference = "Stop"

# Set configuration
$port = "5432"
$date = Get-Date -Format "dd-MMM-yyyy"
$backupRoot = "backed-up\db-dumps\$date"
$logFile = "dbbackup_logs\pg_backup_$date.log"

# Ensure directories exist
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
New-Item -ItemType File -Path $logFile -Force | Out-Null

function Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Extract unique, valid hostnames and usernames from .pgpass
$pgpassEntries = Get-Content $pgPassFile | Where-Object { $_ -notmatch '^(#|$)' -and ($_ -split ':').Count -ge 5 }

# Create a hashtable to map hostnames to usernames
$hostUserMap = @{}
foreach ($entry in $pgpassEntries) {
    $parts = $entry -split ':'
    $hostname = $parts[0]
    $username = $parts[3]
    $hostUserMap[$hostname] = $username
}

Log "Found hosts and their respective users in .pgpass:"
foreach ($_ in $hostUserMap.Keys) {
    Log "  → Host: $_, User: $($hostUserMap[$_])"
}

Log "Starting backup from listed hosts..."
foreach ($hostName in $hostUserMap.Keys) {
    $user = $hostUserMap[$hostName]
    Log "Connecting to host: $hostName with user: $user"

    $backupDir = Join-Path -Path $backupRoot -ChildPath $hostName
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Get databases excluding templates
    $databases = psql -h $hostName -p $port -U $user -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'quartz', 'support');"

    foreach ($db in $databases) {
        $db = $db.Trim()
        if ([string]::IsNullOrWhiteSpace($db)) {
            continue
        }
        $backupFile = Join-Path -Path $backupDir -ChildPath "$db.sql.gz"

        Log "Backing up database '$db' from host '$hostName'"
        try {
            pg_dump -h $hostName -p $port -U $user $db | gzip > $backupFile
            Log "Success: $db on $hostName"
        } catch {
            Log "Failed: $db on $hostName"
        }
    }
}

Log "All backups from all hosts complete."
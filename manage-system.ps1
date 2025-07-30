# manage-system.ps1
param(
    [string]$Action = ""
)

# Import utilities with full path
$utilsPath = Join-Path $PSScriptRoot "scripts\utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    Write-Host "Error: Could not find utils.ps1 at $utilsPath" -ForegroundColor Red
    exit 1
}

Show-Header "Multi-Agent Observability System Manager"

# Check if action was provided as parameter
if ($Action) {
    switch ($Action.ToLower()) {
        "start" { 
            $startScript = Join-Path $PSScriptRoot "scripts\start-services.ps1"
            & $startScript
            exit 
        }
        "stop" { 
            $stopScript = Join-Path $PSScriptRoot "scripts\stop-services.ps1"
            & $stopScript
            exit 
        }
        "status" { 
            $statusScript = Join-Path $PSScriptRoot "scripts\check-status.ps1"
            & $statusScript
            exit 
        }
        "restart" { 
            $stopScript = Join-Path $PSScriptRoot "scripts\stop-services.ps1"
            $startScript = Join-Path $PSScriptRoot "scripts\start-services.ps1"
            & $stopScript
            Start-Sleep 2
            & $startScript
            exit 
        }
        default { 
            Write-Host "Invalid action. Use: start, stop, status, restart" -ForegroundColor Red
            exit 1
        }
    }
}

# Interactive menu if no action provided
$status = Get-SystemStatusAdvanced

if ($status.ServerRunning -or $status.ClientRunning) {
    Write-Host ""
    if ($status.ActualClientPort -ne "5173") {
        Write-Host "Note: Client is running on port $($status.ActualClientPort)" -ForegroundColor Yellow
    }
    Write-Host "System appears to be already running!" -ForegroundColor Yellow
    Write-Host "What would you like to do?"
    Write-Host "1. Restart (stop existing and start new)"
    Write-Host "2. Check status and logs"
    Write-Host "3. Stop system"
    Write-Host "4. Cancel and exit"
    Write-Host "5. Force start anyway (may cause conflicts)"
    
    $choice = Read-Host "Enter choice (1-5)"
    
    switch ($choice) {
        "1" { 
            $stopScript = Join-Path $PSScriptRoot "scripts\stop-services.ps1"
            $startScript = Join-Path $PSScriptRoot "scripts\start-services.ps1"
            & $stopScript
            Start-Sleep 2
            & $startScript
        }
        "2" { 
            $statusScript = Join-Path $PSScriptRoot "scripts\check-status.ps1"
            & $statusScript 
        }
        "3" { 
            $stopScript = Join-Path $PSScriptRoot "scripts\stop-services.ps1"
            & $stopScript 
        }
        "4" { Write-Host "Cancelled. Exiting..." -ForegroundColor Yellow; exit }
        "5" { 
            $startScript = Join-Path $PSScriptRoot "scripts\start-services.ps1"
            & $startScript 
        }
        default { Write-Host "Invalid choice. Exiting..." -ForegroundColor Red; exit }
    }
} else {
    Write-Host "System is not running. Starting now..." -ForegroundColor Green
    $startScript = Join-Path $PSScriptRoot "scripts\start-services.ps1"
    & $startScript
}
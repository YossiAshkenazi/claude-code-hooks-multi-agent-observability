# manage-system.ps1
param(
    [string]$Action = ""
)

# Import utilities
. "$PSScriptRoot\scripts\utils.ps1"

Show-Header "Multi-Agent Observability System Manager"

# Check if action was provided as parameter
if ($Action) {
    switch ($Action.ToLower()) {
        "start" { & "$PSScriptRoot\scripts\start-services.ps1"; exit }
        "stop" { & "$PSScriptRoot\scripts\stop-services.ps1"; exit }
        "status" { & "$PSScriptRoot\scripts\check-status.ps1"; exit }
        "restart" { 
            & "$PSScriptRoot\scripts\stop-services.ps1"
            Start-Sleep 2
            & "$PSScriptRoot\scripts\start-services.ps1"
            exit 
        }
        default { 
            Write-Host "Invalid action. Use: start, stop, status, restart" -ForegroundColor Red
            exit 1
        }
    }
}

# Interactive menu if no action provided
$status = Get-SystemStatus

if ($status.ServerRunning -or $status.ClientRunning) {
    Write-Host ""
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
            & "$PSScriptRoot\scripts\stop-services.ps1"
            Start-Sleep 2
            & "$PSScriptRoot\scripts\start-services.ps1"
        }
        "2" { & "$PSScriptRoot\scripts\check-status.ps1" }
        "3" { & "$PSScriptRoot\scripts\stop-services.ps1" }
        "4" { Write-Host "Cancelled. Exiting..." -ForegroundColor Yellow; exit }
        "5" { & "$PSScriptRoot\scripts\start-services.ps1" }
        default { Write-Host "Invalid choice. Exiting..." -ForegroundColor Red; exit }
    }
} else {
    Write-Host "System is not running. Starting now..." -ForegroundColor Green
    & "$PSScriptRoot\scripts\start-services.ps1"
}
# scripts/stop-services.ps1
$utilsPath = Join-Path $PSScriptRoot "utils.ps1"
. $utilsPath

Show-Header "Stopping Services"

$stopped = $false

# Stop background jobs (if any)
$jobs = Get-Job -ErrorAction SilentlyContinue
if ($jobs) {
    $jobs | Stop-Job | Remove-Job -ErrorAction SilentlyContinue
    Write-Host "Stopped PowerShell background jobs" -ForegroundColor Red
}

# Stop services by port
if (Stop-ServiceByPort -Port "4000" -ServiceName "Server") {
    $stopped = $true
}

if (Stop-ServiceByPort -Port "5173" -ServiceName "Client") {
    $stopped = $true
}

# Clean up process info file
if (Test-Path "system-pids.json") {
    Remove-Item "system-pids.json" -Force
    Write-Host "Cleaned up process info file" -ForegroundColor Gray
}

if ($stopped) {
    Write-Host ""
    Write-Host "System stopped successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "No running services found to stop" -ForegroundColor Yellow
}


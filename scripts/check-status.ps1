# scripts/check-status.ps1
. "$PSScriptRoot\utils.ps1"

Show-Header "System Status"

$status = Get-SystemStatus

if (-not $status.ServerRunning -and -not $status.ClientRunning) {
    Write-Host "System is NOT running" -ForegroundColor Red
    Write-Host "Use 'manage-system.ps1 start' to start the system" -ForegroundColor Cyan
    exit
}

Write-Host ""
Write-Host "=== SERVICE STATUS ===" -ForegroundColor Cyan
Test-ServiceHealth -Url "http://localhost:4000/events" -ServiceName "Server (port 4000)"
Test-ServiceHealth -Url "http://localhost:5173" -ServiceName "Client (port 5173)"

Write-Host ""
Write-Host "=== PROCESS INFORMATION ===" -ForegroundColor Cyan

$serverProcess = Get-ProcessByPort "4000"
if ($serverProcess) {
    Write-Host "Server Process: PID $($serverProcess.Id), Started: $($serverProcess.StartTime), CPU: $([math]::Round($serverProcess.CPU, 2))s" -ForegroundColor Gray
}

$clientProcess = Get-ProcessByPort "5173"
if ($clientProcess) {
    Write-Host "Client Process: PID $($clientProcess.Id), Started: $($clientProcess.StartTime), CPU: $([math]::Round($clientProcess.CPU, 2))s" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== RECENT LOGS ===" -ForegroundColor Cyan

# Server logs
Write-Host "--- Server Logs (last 10 lines) ---" -ForegroundColor Yellow
if (Test-Path "logs/server.log") {
    Get-Content "logs/server.log" -Tail 10
} else {
    Write-Host "No server log file found" -ForegroundColor Gray
}

Write-Host ""

# Client logs
Write-Host "--- Client Logs (last 10 lines) ---" -ForegroundColor Yellow
if (Test-Path "logs/client.log") {
    Get-Content "logs/client.log" -Tail 10
} else {
    Write-Host "No client log file found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "URLs:" -ForegroundColor Cyan
Write-Host "  Client: http://localhost:5173" -ForegroundColor Gray
Write-Host "  Server: http://localhost:4000" -ForegroundColor Gray

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
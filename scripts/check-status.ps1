# scripts/check-status.ps1
$utilsPath = Join-Path $PSScriptRoot "utils.ps1"
. $utilsPath

Show-Header "System Status"

$status = Get-SystemStatusAdvanced

if (-not $status.ServerRunning -and -not $status.ClientRunning) {
    Write-Host "System is NOT running" -ForegroundColor Red
    Write-Host "Use 'manage-system.ps1 start' to start the system" -ForegroundColor Cyan
    exit
}

Write-Host ""
Write-Host "=== SERVICE STATUS ===" -ForegroundColor Cyan

# Test server
Test-ServiceHealth -Url "http://localhost:4000/events" -ServiceName "Server (port 4000)"

# Test client on actual port
$clientUrl = "http://localhost:$($status.ActualClientPort)"
Test-ServiceHealth -Url $clientUrl -ServiceName "Client (port $($status.ActualClientPort))"

Write-Host ""
Write-Host "=== PROCESS INFORMATION ===" -ForegroundColor Cyan

$serverProcess = Get-ProcessByPort "4000"
if ($serverProcess) {
    $cpuTime = if ($serverProcess.CPU) { [math]::Round($serverProcess.CPU, 2) } else { "N/A" }
    Write-Host "Server Process: PID $($serverProcess.Id), Started: $($serverProcess.StartTime), CPU: ${cpuTime}s" -ForegroundColor Gray
} else {
    Write-Host "Server process information not available" -ForegroundColor Gray
}

$clientProcess = Get-ProcessByPort $status.ActualClientPort
if ($clientProcess) {
    $cpuTime = if ($clientProcess.CPU) { [math]::Round($clientProcess.CPU, 2) } else { "N/A" }
    Write-Host "Client Process: PID $($clientProcess.Id), Started: $($clientProcess.StartTime), CPU: ${cpuTime}s" -ForegroundColor Gray
} else {
    Write-Host "Client process information not available" -ForegroundColor Gray
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
Write-Host "=== URLS ===" -ForegroundColor Cyan
Write-Host "  Server: http://localhost:4000" -ForegroundColor Gray
Write-Host "  Client: http://localhost:$($status.ActualClientPort)" -ForegroundColor Gray

if ($status.ActualClientPort -ne "5173") {
    Write-Host ""
    Write-Host "Note: Client is running on port $($status.ActualClientPort) instead of 5173" -ForegroundColor Yellow
    Write-Host "This is normal if port 5173 was already in use" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
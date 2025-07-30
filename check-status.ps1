Write-Host "System Status Check" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# Check if running
$port4000 = netstat -ano | findstr ":4000"
$port5173 = netstat -ano | findstr ":5173"

if (-not $port4000 -and -not $port5173) {
    Write-Host "System is NOT running" -ForegroundColor Red
    exit
}

# Status checks
try {
    Invoke-WebRequest -Uri "http://localhost:4000/events" -Method GET -TimeoutSec 3 -ErrorAction Stop | Out-Null
    Write-Host "Server: RUNNING" -ForegroundColor Green
} catch {
    Write-Host "Server: NOT RESPONDING" -ForegroundColor Red
}

try {
    Invoke-WebRequest -Uri "http://localhost:5173" -Method GET -TimeoutSec 3 -ErrorAction Stop | Out-Null
    Write-Host "Client: RUNNING" -ForegroundColor Green
} catch {
    Write-Host "Client: NOT RESPONDING" -ForegroundColor Red
}

# Show recent logs
Write-Host ""
Write-Host "Recent Server Logs:" -ForegroundColor Yellow
if (Test-Path "logs/server.log") {
    Get-Content "logs/server.log" -Tail 5
} else {
    Write-Host "No server logs found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Recent Client Logs:" -ForegroundColor Yellow  
if (Test-Path "logs/client.log") {
    Get-Content "logs/client.log" -Tail 5
} else {
    Write-Host "No client logs found" -ForegroundColor Gray
}
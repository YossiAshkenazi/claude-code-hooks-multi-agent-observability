# scripts/start-services.ps1
. "$PSScriptRoot\utils.ps1"

Show-Header "Starting Services"

# Install dependencies first
& "$PSScriptRoot\install-deps.ps1"

# Ensure logs directory exists
Ensure-LogsDirectory

# Start services as independent processes
Write-Host "Starting server..." -ForegroundColor Yellow
$serverProcess = Start-Process -FilePath "bun" -ArgumentList "run", "dev" -WorkingDirectory "apps/server" -PassThru -WindowStyle Hidden -RedirectStandardOutput "logs/server.log" -RedirectStandardError "logs/server-error.log"

Start-Sleep 5

Write-Host "Starting client..." -ForegroundColor Yellow  
$clientProcess = Start-Process -FilePath "bun" -ArgumentList "run", "dev" -WorkingDirectory "apps/client" -PassThru -WindowStyle Hidden -RedirectStandardOutput "logs/client.log" -RedirectStandardError "logs/client-error.log"

Start-Sleep 8

# Save process information
Save-ProcessInfo -ServerPID $serverProcess.Id -ClientPID $clientProcess.Id

Write-Host ""
Write-Host "System Started Successfully!" -ForegroundColor Green
Write-Host "Client: http://localhost:5173" -ForegroundColor Cyan
Write-Host "Server: http://localhost:4000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Process IDs - Server: $($serverProcess.Id), Client: $($clientProcess.Id)" -ForegroundColor Gray
Write-Host "Logs saved to: logs/server.log and logs/client.log" -ForegroundColor Gray
Write-Host ""
Write-Host "Processes will continue running after this terminal closes!" -ForegroundColor Green

# Test services
Write-Host "Testing services..." -ForegroundColor Yellow
Start-Sleep 3

Test-ServiceHealth -Url "http://localhost:4000/events" -ServiceName "Server"
Test-ServiceHealth -Url "http://localhost:5173" -ServiceName "Client"

Start-Process "http://localhost:5173"

Write-Host ""
Write-Host "Use 'manage-system.ps1' to check status or restart" -ForegroundColor Cyan
Write-Host "Terminal closing in 5 seconds..." -ForegroundColor Yellow
Start-Sleep 5
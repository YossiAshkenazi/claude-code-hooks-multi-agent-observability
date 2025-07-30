# start-system.ps1
Write-Host "Multi-Agent Observability System Manager" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Check if processes are already running
$serverRunning = $false
$clientRunning = $false

# Check ports 4000 and 5173
$port4000 = netstat -ano | findstr ":4000"
$port5173 = netstat -ano | findstr ":5173"

if ($port4000) {
    Write-Host "Server appears to be running on port 4000" -ForegroundColor Yellow
    $serverRunning = $true
}

if ($port5173) {
    Write-Host "Client appears to be running on port 5173" -ForegroundColor Yellow  
    $clientRunning = $true
}

# If either is running, ask user what to do
if ($serverRunning -or $clientRunning) {
    Write-Host ""
    Write-Host "System appears to be already running!" -ForegroundColor Yellow
    Write-Host "What would you like to do?"
    Write-Host "1. Restart (stop existing and start new)"
    Write-Host "2. Check status and logs"
    Write-Host "3. Cancel and exit"
    Write-Host "4. Force start anyway (may cause conflicts)"
    
    $choice = Read-Host "Enter choice (1-4)"
    
    switch ($choice) {
        "1" {
            Write-Host "Stopping existing processes..." -ForegroundColor Red
            
            # Stop background jobs
            Get-Job | Stop-Job | Remove-Job -ErrorAction SilentlyContinue
            
            # Kill processes on ports 4000 and 5173
            if ($port4000) {
                $pid4000 = ($port4000 -split '\s+')[-1]
                Stop-Process -Id $pid4000 -Force -ErrorAction SilentlyContinue
                Write-Host "Stopped process on port 4000" -ForegroundColor Red
            }
            
            if ($port5173) {
                $pid5173 = ($port5173 -split '\s+')[-1] 
                Stop-Process -Id $pid5173 -Force -ErrorAction SilentlyContinue
                Write-Host "Stopped process on port 5173" -ForegroundColor Red
            }
            
            # Wait a moment
            Start-Sleep 2
            Write-Host "Proceeding with fresh start..." -ForegroundColor Green
        }
        "2" {
            Write-Host ""
            Write-Host "=== SYSTEM STATUS ===" -ForegroundColor Cyan
            
            # Check server status
            try {
                $serverResponse = Invoke-WebRequest -Uri "http://localhost:4000/events" -Method GET -TimeoutSec 3 -ErrorAction Stop
                Write-Host "Server (port 4000): RUNNING - OK" -ForegroundColor Green
            } catch {
                Write-Host "Server (port 4000): NOT RESPONDING" -ForegroundColor Red
            }
            
            # Check client status  
            try {
                $clientResponse = Invoke-WebRequest -Uri "http://localhost:5173" -Method GET -TimeoutSec 3 -ErrorAction Stop
                Write-Host "Client (port 5173): RUNNING - OK" -ForegroundColor Green
            } catch {
                Write-Host "Client (port 5173): NOT RESPONDING" -ForegroundColor Red
            }
            
            Write-Host ""
            Write-Host "=== RECENT LOGS ===" -ForegroundColor Cyan
            
            # Show recent server logs (if log file exists)
            if (Test-Path "logs/server.log") {
                Write-Host "--- Server Logs (last 10 lines) ---" -ForegroundColor Yellow
                Get-Content "logs/server.log" -Tail 10
            } else {
                Write-Host "No server log file found at logs/server.log" -ForegroundColor Gray
            }
            
            Write-Host ""
            
            # Show recent client logs (if log file exists)
            if (Test-Path "logs/client.log") {
                Write-Host "--- Client Logs (last 10 lines) ---" -ForegroundColor Yellow
                Get-Content "logs/client.log" -Tail 10
            } else {
                Write-Host "No client log file found at logs/client.log" -ForegroundColor Gray
            }
            
            Write-Host ""
            Write-Host "=== PROCESS INFORMATION ===" -ForegroundColor Cyan
            
            # Show process information
            if ($port4000) {
                $serverPid = ($port4000 -split '\s+')[-1]
                $serverProcess = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
                if ($serverProcess) {
                    Write-Host "Server Process: PID $serverPid, Started: $($serverProcess.StartTime), CPU: $($serverProcess.CPU)s" -ForegroundColor Gray
                }
            }
            
            if ($port5173) {
                $clientPid = ($port5173 -split '\s+')[-1]
                $clientProcess = Get-Process -Id $clientPid -ErrorAction SilentlyContinue
                if ($clientProcess) {
                    Write-Host "Client Process: PID $clientPid, Started: $($clientProcess.StartTime), CPU: $($clientProcess.CPU)s" -ForegroundColor Gray
                }
            }
            
            Write-Host ""
            Read-Host "Press Enter to continue"
            exit
        }
        "3" {
            Write-Host "Cancelled. Exiting..." -ForegroundColor Yellow
            exit
        }
        "4" {
            Write-Host "Proceeding anyway..." -ForegroundColor Yellow
        }
        default {
            Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
            exit
        }
    }
}

# Create logs directory if it doesn't exist
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

# Install dependencies
Write-Host ""
Write-Host "Installing dependencies..." -ForegroundColor Yellow
Set-Location "apps/server"
bun install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Server dependency installation failed!" -ForegroundColor Red
    exit 1
}

Set-Location "../client"
bun install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Client dependency installation failed!" -ForegroundColor Red
    exit 1
}

Set-Location "../.."

# Start services as independent processes (NOT jobs)
Write-Host "Starting server..." -ForegroundColor Yellow
$serverProcess = Start-Process -FilePath "bun" -ArgumentList "run", "dev" -WorkingDirectory "apps/server" -PassThru -WindowStyle Hidden -RedirectStandardOutput "logs/server.log" -RedirectStandardError "logs/server-error.log"

Start-Sleep 5

Write-Host "Starting client..." -ForegroundColor Yellow  
$clientProcess = Start-Process -FilePath "bun" -ArgumentList "run", "dev" -WorkingDirectory "apps/client" -PassThru -WindowStyle Hidden -RedirectStandardOutput "logs/client.log" -RedirectStandardError "logs/client-error.log"

Start-Sleep 8

# Save process IDs for later management
$processInfo = @{
    ServerPID = $serverProcess.Id
    ClientPID = $clientProcess.Id
    StartTime = Get-Date
}
$processInfo | ConvertTo-Json | Out-File "system-pids.json"

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

try {
    $serverTest = Invoke-WebRequest -Uri "http://localhost:4000/events" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "Server: OK" -ForegroundColor Green
} catch {
    Write-Host "Server: Not responding yet (may still be starting)" -ForegroundColor Yellow
}

try {
    $clientTest = Invoke-WebRequest -Uri "http://localhost:5173" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "Client: OK" -ForegroundColor Green
} catch {
    Write-Host "Client: Not responding yet (may still be starting)" -ForegroundColor Yellow
}

Start-Process "http://localhost:5173"

Write-Host ""
Write-Host "Use 'start-system.ps1' again to check status or restart" -ForegroundColor Cyan
Write-Host "Terminal closing in 5 seconds..." -ForegroundColor Yellow
Start-Sleep 5
exit
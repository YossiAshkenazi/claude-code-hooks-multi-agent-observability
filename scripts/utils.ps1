# scripts/utils.ps1
function Show-Header {
    param([string]$Title)
    Write-Host $Title -ForegroundColor Green
    Write-Host ("=" * $Title.Length) -ForegroundColor Green
}

function Get-SystemStatus {
    $port4000 = netstat -ano | findstr ":4000"
    $port5173 = netstat -ano | findstr ":5173"
    
    return @{
        ServerRunning = $null -ne $port4000
        ClientRunning = $null -ne $port5173
        ServerPort = $port4000
        ClientPort = $port5173
    }
}

function Test-ServiceHealth {
    param([string]$Url, [string]$ServiceName)
    
    try {
        Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 3 -ErrorAction Stop | Out-Null
        Write-Host "${ServiceName}: RUNNING - OK" -ForegroundColor Green
    } catch {
        Write-Host "${ServiceName}: NOT RESPONDING" -ForegroundColor Red
    }
}

function Get-ProcessByPort {
    param([string]$Port)
    
    $netstatOutput = netstat -ano | findstr ":$Port "
    if ($netstatOutput) {
        # Handle multiple lines - get the first one that's LISTENING
        $lines = $netstatOutput -split "`n"
        foreach ($line in $lines) {
            if ($line -match "LISTENING") {
                $processId = ($line -split '\s+')[-1]
                return Get-Process -Id $processId -ErrorAction SilentlyContinue
            }
        }
        # Fallback - just get the first PID
        $processId = ($netstatOutput -split '\s+')[-1] -split "`n" | Select-Object -First 1
        return Get-Process -Id $processId -ErrorAction SilentlyContinue
    }
    return $null
}

function Stop-ServiceByPort {
    param([string]$Port, [string]$ServiceName)
    
    $process = Get-ProcessByPort $Port
    if ($process) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped ${ServiceName} (PID: $($process.Id))" -ForegroundColor Red
        return $true
    }
    return $false
}

function Ensure-LogsDirectory {
    if (-not (Test-Path "logs")) {
        New-Item -ItemType Directory -Path "logs" -Force | Out-Null
        Write-Host "Created logs directory" -ForegroundColor Gray
    }
}

function Save-ProcessInfo {
    param([int]$ServerPID, [int]$ClientPID)
    
    $processInfo = @{
        ServerPID = $ServerPID
        ClientPID = $ClientPID
        StartTime = Get-Date
    }
    $processInfo | ConvertTo-Json | Out-File "system-pids.json"
}

function Get-ActualClientPort {
    # Check common Vite ports in order
    $ports = @("5173", "5174", "5175", "5176", "5177")
    
    foreach ($port in $ports) {
        $netstatOutput = netstat -ano | findstr ":$port "
        if ($netstatOutput -and $netstatOutput -match "LISTENING") {
            # Test if it responds like a Vite server
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:$port" -Method GET -TimeoutSec 2 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    return $port
                }
            } catch {
                # Continue checking other ports
            }
        }
    }
    
    return "5173"  # Default fallback
}

function Get-SystemStatusAdvanced {
    $serverPort = netstat -ano | findstr ":4000 " | Where-Object { $_ -match "LISTENING" }
    $clientPort = Get-ActualClientPort
    $clientPortCheck = netstat -ano | findstr ":$clientPort " | Where-Object { $_ -match "LISTENING" }
    
    return @{
        ServerRunning = $null -ne $serverPort
        ClientRunning = $null -ne $clientPortCheck
        ServerPort = $serverPort
        ClientPort = $clientPortCheck
        ActualClientPort = $clientPort
    }
}
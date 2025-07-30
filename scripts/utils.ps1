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
        Write-Host "$ServiceName: RUNNING - OK" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "$ServiceName: NOT RESPONDING" -ForegroundColor Red
        return $false
    }
}

function Get-ProcessByPort {
    param([string]$Port)
    
    $netstatOutput = netstat -ano | findstr ":$Port"
    if ($netstatOutput) {
        $pid = ($netstatOutput -split '\s+')[-1]
        return Get-Process -Id $pid -ErrorAction SilentlyContinue
    }
    return $null
}

function Stop-ServiceByPort {
    param([string]$Port, [string]$ServiceName)
    
    $process = Get-ProcessByPort $Port
    if ($process) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped $ServiceName (PID: $($process.Id))" -ForegroundColor Red
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
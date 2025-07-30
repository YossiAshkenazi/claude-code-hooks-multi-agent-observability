# scripts/install-deps.ps1
$utilsPath = Join-Path $PSScriptRoot "utils.ps1"
. $utilsPath

Show-Header "Installing Dependencies"

Write-Host "Installing server dependencies..." -ForegroundColor Yellow
Set-Location "apps/server"
bun install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Server dependency installation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Installing client dependencies..." -ForegroundColor Yellow
Set-Location "../client"
bun install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Client dependency installation failed!" -ForegroundColor Red
    exit 1
}

Set-Location "../.."
Write-Host "Dependencies installed successfully!" -ForegroundColor Green
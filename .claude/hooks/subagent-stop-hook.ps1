#!/usr/bin/env pwsh
# Subagent Stop Hook for Agents Observability
# Reads JSON from stdin and sends to observability server

try {
    # Read JSON input from stdin
    $inputData = $input | Out-String
    if (-not $inputData.Trim()) {
        exit 0
    }
    
    $data = $inputData | ConvertFrom-Json
    
    # Extract project name from cwd or use default
    $projectName = if ($data.cwd) {
        Split-Path -Leaf $data.cwd
    } else {
        "unknown-project"
    }
    
    # Create event payload
    $event = @{
        source_app = $projectName
        session_id = $data.session_id
        hook_event_type = "SubagentStop"
        payload = @{
            stop_hook_active = $data.stop_hook_active
            timestamp = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
            cwd = $data.cwd
            transcript_path = $data.transcript_path
        }
    } | ConvertTo-Json -Depth 10
    
    # Send to observability server
    $job = Start-Job -ScriptBlock {
        param($url, $body)
        try {
            Invoke-RestMethod -Uri "$url/events" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 2
        } catch {
            # Silently fail
        }
    } -ArgumentList "http://localhost:4000", $event
    
    Wait-Job -Job $job -Timeout 2 | Out-Null
    Remove-Job -Job $job -Force | Out-Null
} catch {
    # Always fail silently
}

exit 0
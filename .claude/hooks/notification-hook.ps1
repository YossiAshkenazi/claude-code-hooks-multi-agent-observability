#!/usr/bin/env pwsh
# Notification Hook for Agents Observability
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
    
    # Check if this is an "agent needs input" notification
    $isAgentNeedsInput = $false
    $notificationType = "info"
    $notificationLevel = "normal"
    
    if ($data.message -match "needs your permission|waiting for your input|needs your input") {
        $isAgentNeedsInput = $true
        $notificationType = "warning"
        $notificationLevel = "high"
    }
    
    # Create event payload with additional debugging info
    $event = @{
        source_app = $projectName
        session_id = $data.session_id
        hook_event_type = "Notification"
        payload = @{
            message = $data.message
            timestamp = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
            cwd = $data.cwd
            transcript_path = $data.transcript_path
            notification_type = $notificationType
            notification_level = $notificationLevel
            is_agent_needs_input = $isAgentNeedsInput
            # Capture all available data for analysis
            raw_notification_data = $data
            # Check for YOLO mode indicators
            claude_args = $env:CLAUDE_ARGS
            claude_flags = $env:CLAUDE_FLAGS
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
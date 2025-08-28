#!/usr/bin/env pwsh
# Stop Hook for Agents Observability
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
    
    # Try to extract the last assistant message from the transcript
    $assistantMessage = $null
    
    # Use LiteralPath to handle special characters in file paths (e.g., Hebrew usernames)
    if ($data.transcript_path -and (Test-Path -LiteralPath $data.transcript_path -ErrorAction SilentlyContinue)) {
        try {
            # Read the last few lines of the transcript (JSONL format) with UTF-8 encoding
            $lines = Get-Content -LiteralPath $data.transcript_path -Tail 50 -Encoding UTF8
            
            # Look for the most recent assistant message (reverse order)
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $line = $lines[$i]
                if ($line.Trim()) {
                    try {
                        $entry = $line | ConvertFrom-Json
                        # Check for assistant message in JSONL format
                        if ($entry.message -and $entry.message.role -eq "assistant") {
                            # Extract text content from the message
                            if ($entry.message.content) {
                                # Handle both array and string content
                                if ($entry.message.content -is [array]) {
                                    foreach ($contentItem in $entry.message.content) {
                                        if ($contentItem.type -eq "text" -and $contentItem.text) {
                                            $assistantMessage = $contentItem.text
                                            break
                                        }
                                    }
                                } elseif ($entry.message.content -is [string]) {
                                    $assistantMessage = $entry.message.content
                                }
                            }
                            if ($assistantMessage) { break }
                        }
                    } catch {
                        # Skip lines that can't be parsed as JSON
                        continue
                    }
                }
            }
        } catch {
            # Silently continue if parsing fails
        }
    }
    
    # Create event payload for Stop event
    $stopEvent = @{
        source_app = $projectName
        session_id = $data.session_id
        hook_event_type = "Stop"
        payload = @{
            stop_hook_active = $data.stop_hook_active
            timestamp = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
            cwd = $data.cwd
            transcript_path = $data.transcript_path
        }
    } | ConvertTo-Json -Depth 10
    
    # If we found an assistant message, also send it as assistant-message event
    $assistantEvent = if ($assistantMessage) {
        @{
            source_app = $projectName
            session_id = $data.session_id
            hook_event_type = "assistant-message"
            payload = @{
                message = $assistantMessage
                timestamp = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                cwd = $data.cwd
                transcript_path = $data.transcript_path
            }
        } | ConvertTo-Json -Depth 10
    } else { $null }
    
    # Send all events to observability server
    $jobs = @()
    
    # Send Stop event
    $jobs += Start-Job -ScriptBlock {
        param($url, $body)
        try {
            Invoke-RestMethod -Uri "$url/events" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 2
        } catch {
            # Silently fail
        }
    } -ArgumentList "http://localhost:4000", $stopEvent
    
    # Send AssistantMessage event with summarization if we have one
    if ($assistantEvent) {
        $jobs += Start-Job -ScriptBlock {
            param($url, $body)
            try {
                # Request summarization for assistant messages
                Invoke-RestMethod -Uri "$url/events?summarize=true" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 2
            } catch {
                # Silently fail
            }
        } -ArgumentList "http://localhost:4000", $assistantEvent
    }
    
    # Wait for all jobs
    foreach ($job in $jobs) {
        Wait-Job -Job $job -Timeout 2 | Out-Null
        Remove-Job -Job $job -Force | Out-Null
    }
} catch {
    # Always fail silently
}

exit 0
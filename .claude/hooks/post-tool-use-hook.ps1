#!/usr/bin/env pwsh
# Post-Tool-Use Hook for Agents Observability

$ServerUrl = "http://localhost:4000"

# Auto-detect project name and branch
function Get-ProjectName {
    try {
        # Try to get project name from git remote origin URL
        $originUrl = git config --get remote.origin.url 2>$null
        if ($originUrl) {
            # Extract repo name from URL (handle both HTTPS and SSH formats)
            if ($originUrl -match '([^/]+)\.git$') {
                return $matches[1]
            } elseif ($originUrl -match '/([^/]+)/?$') {
                return $matches[1]
            }
        }
    } catch { }
    
    # Fallback to current folder name
    try {
        return (Get-Item $PWD).Name
    } catch {
        return "unknown-project"
    }
}

function Get-GitBranch {
    try {
        $branch = git branch --show-current 2>$null
        if ($branch) {
            return $branch.Trim()
        }
    } catch { }
    return "unknown"
}

# Extract execution metrics from tool response
function Get-ExecutionMetrics {
    param($toolResponse)
    
    $metrics = @{
        success = $false
        error_message = ""
        files_affected = @()
        bytes_processed = 0
    }
    
    try {
        # Check if response indicates success
        if ($toolResponse.success -eq $true -or $toolResponse.PSObject.Properties.Name -contains "success" -and $toolResponse.success) {
            $metrics.success = $true
        } elseif ($toolResponse.error) {
            $metrics.error_message = $toolResponse.error
        }
        
        # Extract file information
        if ($toolResponse.filePath) {
            $metrics.files_affected += $toolResponse.filePath
        }
        if ($toolResponse.file_path) {
            $metrics.files_affected += $toolResponse.file_path
        }
        
        # Calculate bytes processed (approximate)
        if ($toolResponse.content) {
            $metrics.bytes_processed = [System.Text.Encoding]::UTF8.GetByteCount($toolResponse.content)
        }
        
    } catch {
        # If we can't parse the response, assume success unless there's an obvious error
        $metrics.success = $true
    }
    
    return $metrics
}

try {
    # Read JSON input from stdin
    $inputJson = [Console]::In.ReadToEnd()
    if (-not $inputJson) {
        exit 0
    }
    
    $hookInput = $inputJson | ConvertFrom-Json
    
    $ProjectName = Get-ProjectName
    $GitBranch = Get-GitBranch
    $endTime = Get-Date
    
    # Extract tool information
    $toolName = $hookInput.tool_name
    $toolInput = $hookInput.tool_input
    $toolResponse = $hookInput.tool_response
    $sessionId = $hookInput.session_id
    $cwdPath = $hookInput.cwd
    
    # Calculate execution metrics
    $metrics = Get-ExecutionMetrics -toolResponse $toolResponse
    
    # Create event payload
    $event = @{
        source_app = $ProjectName
        session_id = if ($sessionId) { $sessionId } else { "$env:USERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
        hook_event_type = "PostToolUse"
        payload = @{
            tool_name = $toolName
            tool_input = $toolInput
            tool_response = $toolResponse
            cwd = $cwdPath
            execution_metrics = $metrics
            git_branch = $GitBranch
            timestamp = $endTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
            user = $env:USERNAME
            hostname = $env:COMPUTERNAME
        }
    } | ConvertTo-Json -Depth 10
    
    # Send event to observability server (non-blocking)
    try {
        $job = Start-Job -ScriptBlock {
            param($url, $body)
            try {
                Invoke-RestMethod -Uri "$url/events" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 2
            } catch { }
        } -ArgumentList $ServerUrl, $event
        
        Wait-Job -Job $job -Timeout 2 | Out-Null
        Remove-Job -Job $job -Force | Out-Null
    } catch { }
    
    # For failed operations, could provide feedback to Claude
    # Example feedback response:
    # if (-not $metrics.success -and $metrics.error_message) {
    #     $response = @{
    #         decision = "block"
    #         reason = "Tool execution failed: $($metrics.error_message). Please review and retry."
    #     } | ConvertTo-Json
    #     Write-Output $response
    #     exit 0
    # }
    
} catch {
    # Silent failure - don't interfere with normal operation
}

exit 0
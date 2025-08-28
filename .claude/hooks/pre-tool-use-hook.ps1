#!/usr/bin/env pwsh
# Pre-Tool-Use Hook for Agents Observability

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

# Validation function for potentially dangerous operations
function Test-DangerousOperation {
    param($toolName, $toolInput)
    
    # Define dangerous patterns
    $dangerousPatterns = @{
        "Bash" = @(
            @{ pattern = "rm\s+-rf\s+/"; message = "Recursive deletion of root directory detected" },
            @{ pattern = ">\s*/dev/sd[a-z]"; message = "Direct disk write operation detected" },
            @{ pattern = "dd\s+.*of=/dev/"; message = "Direct disk device operation detected" },
            @{ pattern = "format\s+[a-z]:"; message = "Disk format operation detected" },
            @{ pattern = "del\s+/s\s+/q\s+c:\\"; message = "Recursive deletion of system drive detected" }
        )
        "Write" = @(
            @{ pattern = "\.exe$|\.bat$|\.cmd$|\.ps1$"; message = "Writing executable file detected" }
        )
    }
    
    if ($dangerousPatterns.ContainsKey($toolName)) {
        foreach ($rule in $dangerousPatterns[$toolName]) {
            $content = if ($toolName -eq "Bash") { $toolInput.command } else { $toolInput.file_path + " " + $toolInput.content }
            if ($content -match $rule.pattern) {
                return @{ isDangerous = $true; reason = $rule.message }
            }
        }
    }
    
    return @{ isDangerous = $false; reason = "" }
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
    $startTime = Get-Date
    
    # Extract tool information
    $toolName = $hookInput.tool_name
    $toolInput = $hookInput.tool_input
    $sessionId = $hookInput.session_id
    $cwdPath = $hookInput.cwd
    
    # We can't reliably predict if Claude Code will ask for permission since it depends on user settings
    # Instead, we'll capture the tool info and let the server/client filter intelligently
    # The server can track patterns of when tools actually get blocked vs executed
    $needsPermission = $false
    $permissionMessage = ""
    
    # Perform validation
    $validation = Test-DangerousOperation -toolName $toolName -toolInput $toolInput
    
    # Create event payload
    $event = @{
        source_app = $ProjectName
        session_id = if ($sessionId) { $sessionId } else { "$env:USERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
        hook_event_type = "PreToolUse"
        payload = @{
            tool_name = $toolName
            tool_input = $toolInput
            cwd = $cwdPath
            validation_result = @{
                is_dangerous = $validation.isDangerous
                reason = $validation.reason
            }
            # Note: We don't predict permission needs here since that depends on user settings
            # The notification-hook will fire if Claude Code actually asks for permission
            needs_permission = $false
            permission_message = ""
            permission_request = $false
            is_agent_needs_input = $false
            git_branch = $GitBranch
            timestamp = $startTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
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
    
    # Don't send duplicate notification - Claude Code will send its own notification
    # when it actually shows the permission dialog to the user
    
    # For now, always approve (no blocking)
    # In the future, this could return JSON with "decision": "block" for dangerous operations
    # Example blocking response:
    # if ($validation.isDangerous) {
    #     $response = @{
    #         decision = "block"
    #         reason = "Security policy violation: $($validation.reason). Please review the operation before proceeding."
    #     } | ConvertTo-Json
    #     Write-Output $response
    #     exit 0
    # }
    
} catch {
    # Silent failure - don't block operations due to hook errors
}

exit 0
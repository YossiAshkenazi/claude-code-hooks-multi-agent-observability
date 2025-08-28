#!/bin/bash
# Pre-Tool-Use Hook for Agents Observability

SERVER_URL="http://localhost:4000"

# Auto-detect project name and branch
get_project_name() {
    # Try to get project name from git remote origin URL
    local origin_url
    origin_url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ -n "$origin_url" ]]; then
        # Extract repo name from URL (handle both HTTPS and SSH formats)
        if [[ "$origin_url" =~ ([^/]+)\.git$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        elif [[ "$origin_url" =~ /([^/]+)/?$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
    fi
    
    # Fallback to current folder name
    basename "$(pwd)" 2>/dev/null || echo "unknown-project"
}

get_git_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# Validation function for potentially dangerous operations
test_dangerous_operation() {
    local tool_name="$1"
    local tool_input="$2"
    
    case "$tool_name" in
        "Bash")
            # Extract command from tool input JSON
            local command=$(echo "$tool_input" | jq -r '.command // ""' 2>/dev/null)
            
            # Check for dangerous patterns
            if [[ "$command" =~ rm[[:space:]]+-rf[[:space:]]+/ ]]; then
                echo '{"isDangerous": true, "reason": "Recursive deletion of root directory detected"}'
                return
            elif [[ "$command" =~ \>[[:space:]]*/dev/sd[a-z] ]]; then
                echo '{"isDangerous": true, "reason": "Direct disk write operation detected"}'
                return
            elif [[ "$command" =~ dd[[:space:]].*of=/dev/ ]]; then
                echo '{"isDangerous": true, "reason": "Direct disk device operation detected"}'
                return
            fi
            ;;
        "Write")
            # Extract file path from tool input JSON
            local file_path=$(echo "$tool_input" | jq -r '.file_path // ""' 2>/dev/null)
            
            if [[ "$file_path" =~ \.(exe|bat|cmd|ps1)$ ]]; then
                echo '{"isDangerous": true, "reason": "Writing executable file detected"}'
                return
            fi
            ;;
    esac
    
    echo '{"isDangerous": false, "reason": ""}'
}

# Read JSON input from stdin
input_json=$(cat)
if [[ -z "$input_json" ]]; then
    exit 0
fi

# Extract values using jq (with fallbacks if jq is not available)
if command -v jq >/dev/null 2>&1; then
    tool_name=$(echo "$input_json" | jq -r '.tool_name // ""')
    tool_input=$(echo "$input_json" | jq -c '.tool_input // {}')
    session_id=$(echo "$input_json" | jq -r '.session_id // ""')
    cwd_path=$(echo "$input_json" | jq -r '.cwd // ""')
else
    # Fallback parsing without jq (basic extraction)
    tool_name=$(echo "$input_json" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    session_id=$(echo "$input_json" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    cwd_path=$(echo "$input_json" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    tool_input="{}"
fi

project_name=$(get_project_name)
git_branch=$(get_git_branch)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
user="${USER:-unknown}"
hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo unknown)}"

# IMPORTANT: As of v3.1.0, we don't try to predict permissions
# We can't reliably predict which tools will ask for permission
# This was causing false positives and TTS spam
# Instead, we let the server/client filter based on actual behavior
# All permission detection now happens via notification-hook
needs_permission="false"
permission_message=""
permission_request="false"
is_agent_needs_input="false"

# Perform validation
validation=$(test_dangerous_operation "$tool_name" "$tool_input")

# Create event payload
event_payload=$(cat <<EOF
{
    "source_app": "$project_name",
    "session_id": "${session_id:-$user-$(date +%Y%m%d-%H%M%S)}",
    "hook_event_type": "PreToolUse",
    "payload": {
        "tool_name": "$tool_name",
        "tool_input": $tool_input,
        "cwd": "$cwd_path",
        "validation_result": $validation,
        "needs_permission": $needs_permission,
        "permission_message": "$permission_message",
        "permission_request": $permission_request,
        "is_agent_needs_input": $is_agent_needs_input,
        "git_branch": "$git_branch",
        "timestamp": "$timestamp",
        "user": "$user",
        "hostname": "$hostname"
    }
}
EOF
)

# Send event to observability server (non-blocking)
(
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$event_payload" \
        --connect-timeout 2 \
        --max-time 2 \
        "$SERVER_URL/events" >/dev/null 2>&1 &
) 2>/dev/null

# For now, always approve (no blocking)
# In the future, this could return JSON with "decision": "block" for dangerous operations
# Example blocking response:
# if echo "$validation" | grep -q '"isDangerous": true'; then
#     reason=$(echo "$validation" | jq -r '.reason // "Potentially dangerous operation"')
#     echo "{\"decision\": \"block\", \"reason\": \"Security policy violation: $reason. Please review the operation before proceeding.\"}"
#     exit 0
# fi

exit 0